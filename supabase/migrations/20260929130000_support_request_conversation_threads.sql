ALTER TABLE public.support_messages RENAME TO support_ticket_messages;

CREATE TABLE public.support_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  support_request_id uuid NOT NULL REFERENCES public.support_requests(id) ON DELETE CASCADE,
  sender_type text NOT NULL CHECK (sender_type IN ('customer', 'admin')),
  message text NOT NULL CHECK (length(btrim(message)) BETWEEN 1 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX support_messages_request_created_idx
  ON public.support_messages(support_request_id, created_at DESC, id DESC);

ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.support_messages FROM PUBLIC, anon, authenticated;

REVOKE INSERT ON TABLE public.support_requests FROM PUBLIC, anon, authenticated;
DROP POLICY IF EXISTS support_requests_public_insert ON public.support_requests;

INSERT INTO public.support_messages(support_request_id, sender_type, message, created_at)
SELECT r.id, 'customer', btrim(r.message), r.created_at
FROM public.support_requests AS r
WHERE btrim(coalesce(r.message, '')) <> '';

INSERT INTO public.support_messages(support_request_id, sender_type, message, created_at)
SELECT r.id, 'admin', btrim(r.admin_reply), r.created_at + interval '1 microsecond'
FROM public.support_requests AS r
WHERE btrim(coalesce(r.admin_reply, '')) <> '';

CREATE OR REPLACE FUNCTION public.submit_support_request(
  p_customer_name text,
  p_customer_email text,
  p_customer_phone text,
  p_subject text,
  p_message text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  current_user_id uuid := auth.uid();
  normalized_email text := lower(btrim(coalesce(p_customer_email, '')));
  normalized_subject text := lower(btrim(coalesce(p_subject, '')));
  verified_auth_email text := lower(btrim(coalesce(auth.jwt() ->> 'email', '')));
  email_subject_lock bigint;
  user_subject_lock bigint;
  support_request_id uuid;
BEGIN
  IF btrim(coalesce(p_customer_name, '')) = ''
    OR normalized_email = ''
    OR btrim(coalesce(p_customer_phone, '')) = ''
    OR normalized_subject = ''
    OR btrim(coalesce(p_message, '')) = '' THEN
    RAISE EXCEPTION 'All support request fields are required' USING ERRCODE = '22023';
  END IF;
  IF length(btrim(p_customer_name)) > 150
    OR length(normalized_email) > 254
    OR length(btrim(p_customer_phone)) > 40
    OR length(btrim(p_subject)) > 200
    OR length(btrim(p_message)) > 4000 THEN
    RAISE EXCEPTION 'Support request fields exceed the allowed length' USING ERRCODE = '22023';
  END IF;

  email_subject_lock := pg_catalog.hashtextextended('email:' || normalized_email || ':' || normalized_subject, 0);
  IF current_user_id IS NULL THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(email_subject_lock);
  ELSE
    user_subject_lock := pg_catalog.hashtextextended('user:' || current_user_id::text || ':' || normalized_subject, 0);
    PERFORM pg_catalog.pg_advisory_xact_lock(LEAST(email_subject_lock, user_subject_lock));
    IF email_subject_lock <> user_subject_lock THEN
      PERFORM pg_catalog.pg_advisory_xact_lock(GREATEST(email_subject_lock, user_subject_lock));
    END IF;
  END IF;

  SELECT r.id
  INTO support_request_id
  FROM public.support_requests AS r
  WHERE lower(btrim(r.subject)) = normalized_subject
    AND (
      (current_user_id IS NOT NULL AND r.user_id = current_user_id)
      OR (
        (current_user_id IS NULL OR normalized_email = verified_auth_email)
        AND r.user_id IS NULL
        AND lower(btrim(r.customer_email)) = normalized_email
      )
    )
  ORDER BY r.created_at DESC, r.id DESC
  LIMIT 1
  FOR UPDATE;

  IF support_request_id IS NULL THEN
    INSERT INTO public.support_requests(
      user_id, customer_name, customer_email, customer_phone,
      subject, message, status
    )
    VALUES(
      current_user_id, btrim(p_customer_name), btrim(p_customer_email),
      btrim(p_customer_phone), btrim(p_subject), btrim(p_message), 'new'
    )
    RETURNING id INTO support_request_id;
  ELSIF current_user_id IS NOT NULL THEN
    UPDATE public.support_requests AS r
    SET user_id = current_user_id
    WHERE r.id = support_request_id AND r.user_id IS NULL;
  END IF;

  INSERT INTO public.support_messages(support_request_id, sender_type, message)
  VALUES(support_request_id, 'customer', btrim(p_message));

  RETURN support_request_id;
END;
$$;
REVOKE ALL ON FUNCTION public.submit_support_request(text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_support_request(text, text, text, text, text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_my_support_conversations()
RETURNS TABLE(
  id uuid,
  customer_name text,
  customer_email text,
  customer_phone text,
  subject text,
  message text,
  status text,
  admin_reply text,
  created_at timestamptz,
  latest_message text,
  latest_sender_type text,
  latest_message_created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT r.id, r.customer_name, r.customer_email, r.customer_phone,
         r.subject, r.message, r.status, r.admin_reply, r.created_at,
         latest.message, latest.sender_type, latest.created_at
  FROM public.support_requests AS r
  LEFT JOIN LATERAL (
    SELECT m.message, m.sender_type, m.created_at
    FROM public.support_messages AS m
    WHERE m.support_request_id = r.id
    ORDER BY m.created_at DESC, m.id DESC
    LIMIT 1
  ) AS latest ON true
  WHERE auth.uid() IS NOT NULL
    AND r.user_id = auth.uid()
  ORDER BY coalesce(latest.created_at, r.created_at) DESC, r.id DESC
$$;
REVOKE ALL ON FUNCTION public.get_my_support_conversations() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_support_conversations() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_support_messages(p_support_request_id uuid)
RETURNS TABLE(id uuid, support_request_id uuid, sender_type text, message text, created_at timestamptz)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.support_requests AS r
    WHERE r.id = p_support_request_id AND r.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Support request not found' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
    SELECT m.id, m.support_request_id, m.sender_type, m.message, m.created_at
    FROM public.support_messages AS m
    WHERE m.support_request_id = p_support_request_id
    ORDER BY m.created_at DESC, m.id DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.get_my_support_messages(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_support_messages(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_get_support_messages(p_support_request_id uuid)
RETURNS TABLE(id uuid, support_request_id uuid, sender_type text, message text, created_at timestamptz)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT private.is_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
    SELECT m.id, m.support_request_id, m.sender_type, m.message, m.created_at
    FROM public.support_messages AS m
    WHERE m.support_request_id = p_support_request_id
    ORDER BY m.created_at, m.id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_get_support_messages(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_support_messages(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_update_support_request(
  p_id uuid,
  p_status text,
  p_admin_note text,
  p_admin_reply text
)
RETURNS SETOF public.support_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  updated_request public.support_requests%ROWTYPE;
  previous_admin_reply text;
BEGIN
  IF NOT private.is_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE = '42501';
  END IF;
  IF p_status IS NULL OR p_status NOT IN ('new', 'in_progress', 'resolved', 'closed') THEN
    RAISE EXCEPTION 'Invalid support request status';
  END IF;

  SELECT r.admin_reply INTO previous_admin_reply
  FROM public.support_requests AS r
  WHERE r.id = p_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Support request not found';
  END IF;

  UPDATE public.support_requests AS r
  SET status = p_status,
      admin_note = p_admin_note,
      admin_reply = nullif(btrim(coalesce(p_admin_reply, '')), '')
  WHERE r.id = p_id
  RETURNING r.* INTO updated_request;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Support request not found';
  END IF;

  IF nullif(btrim(coalesce(p_admin_reply, '')), '') IS NOT NULL
    AND nullif(btrim(coalesce(previous_admin_reply, '')), '')
      IS DISTINCT FROM nullif(btrim(coalesce(p_admin_reply, '')), '') THEN
    INSERT INTO public.support_messages(support_request_id, sender_type, message)
    VALUES(p_id, 'admin', btrim(p_admin_reply));
  END IF;

  RETURN NEXT updated_request;
  RETURN;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_update_support_request(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_support_request(uuid, text, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION private.create_ticket(p_subject text, p_body text, p_order_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  uid uuid := auth.uid();
  ticket_id uuid;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF p_order_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.orders AS o WHERE o.id = p_order_id AND o.user_id = uid
  ) THEN
    RAISE EXCEPTION 'Order not found' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.support_tickets(user_id, order_id, subject)
  VALUES(uid, p_order_id, btrim(p_subject))
  RETURNING id INTO ticket_id;
  INSERT INTO public.support_ticket_messages(ticket_id, sender_role, sender_id, body)
  VALUES(ticket_id, 'customer', uid, btrim(p_body));
  RETURN ticket_id;
END;
$$;

CREATE OR REPLACE FUNCTION private.reply_to_ticket(p_ticket_id uuid, p_body text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  uid uuid := auth.uid();
  is_admin boolean := private.is_admin();
  ticket public.support_tickets%ROWTYPE;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  SELECT t.* INTO ticket FROM public.support_tickets AS t WHERE t.id = p_ticket_id FOR UPDATE;
  IF NOT FOUND OR (ticket.user_id <> uid AND NOT is_admin) THEN
    RAISE EXCEPTION 'Ticket not found' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.support_ticket_messages(ticket_id, sender_role, sender_id, body)
  VALUES(p_ticket_id, CASE WHEN is_admin THEN 'admin' ELSE 'customer' END, uid, btrim(p_body));
  UPDATE public.support_tickets
  SET status = CASE WHEN is_admin AND status = 'open' THEN 'in_progress'
                    WHEN NOT is_admin AND status IN ('resolved', 'closed') THEN 'open'
                    ELSE status END,
      updated_at = now()
  WHERE id = p_ticket_id;
END;
$$;

NOTIFY pgrst, 'reload schema';