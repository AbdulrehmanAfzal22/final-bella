ALTER TABLE public.support_conversations
  ADD COLUMN subject text NOT NULL DEFAULT 'General enquiry';

ALTER TABLE public.support_conversations
  DROP CONSTRAINT IF EXISTS support_conversations_customer_id_key;

DELETE FROM public.support_conversations AS c
WHERE NOT EXISTS (
  SELECT 1 FROM public.support_messages AS m WHERE m.conversation_id = c.id
);

INSERT INTO public.support_conversations(customer_id)
SELECT p.id
FROM public.profiles AS p
WHERE NOT EXISTS (
  SELECT 1 FROM public.support_conversations AS c WHERE c.customer_id = p.id
);

DROP FUNCTION IF EXISTS public.get_my_support_conversations();
DROP FUNCTION IF EXISTS public.admin_get_support_inbox();

CREATE FUNCTION public.get_my_support_conversations()
RETURNS TABLE(
  id uuid,
  customer_id uuid,
  customer_name text,
  customer_email text,
  subject text,
  updated_at timestamptz,
  latest_message text,
  latest_sender_type text,
  latest_message_created_at timestamptz,
  unread_count bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT c.id, c.customer_id, p.full_name, p.email, c.subject, c.updated_at,
         latest.message, latest.sender_type, latest.created_at,
         (SELECT count(*) FROM public.support_messages AS unread
          WHERE unread.conversation_id = c.id
            AND unread.sender_type = 'admin'
            AND unread.created_at > c.customer_read_at) AS unread_count
  FROM public.support_conversations AS c
  JOIN public.profiles AS p ON p.id = c.customer_id
  LEFT JOIN LATERAL (
    SELECT m.message, m.sender_type, m.created_at
    FROM public.support_messages AS m
    WHERE m.conversation_id = c.id
    ORDER BY m.created_at DESC, m.id DESC
    LIMIT 1
  ) AS latest ON true
  WHERE auth.uid() IS NOT NULL
    AND c.customer_id = auth.uid()
    AND latest.message IS NOT NULL
  ORDER BY coalesce(latest.created_at, c.updated_at) DESC, c.id
$$;
REVOKE ALL ON FUNCTION public.get_my_support_conversations() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_support_conversations() TO authenticated;

CREATE FUNCTION public.admin_get_support_inbox()
RETURNS TABLE(
  id uuid,
  customer_id uuid,
  customer_name text,
  customer_email text,
  subject text,
  updated_at timestamptz,
  latest_message text,
  latest_sender_type text,
  latest_message_created_at timestamptz,
  unread_count bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT c.id, p.id, p.full_name, p.email, c.subject, c.updated_at,
         latest.message, latest.sender_type, latest.created_at,
         (SELECT count(*) FROM public.support_messages AS unread
          WHERE unread.conversation_id = c.id
            AND unread.sender_type = 'customer'
            AND unread.created_at > c.admin_read_at) AS unread_count
  FROM public.profiles AS p
  LEFT JOIN public.support_conversations AS c ON c.customer_id = p.id
  LEFT JOIN LATERAL (
    SELECT m.message, m.sender_type, m.created_at
    FROM public.support_messages AS m
    WHERE m.conversation_id = c.id
    ORDER BY m.created_at DESC, m.id DESC
    LIMIT 1
  ) AS latest ON true
  WHERE private.is_admin()
  ORDER BY coalesce(latest.created_at, c.updated_at, p.created_at) DESC, p.full_name, p.id
$$;
REVOKE ALL ON FUNCTION public.admin_get_support_inbox() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_support_inbox() TO authenticated;

CREATE FUNCTION public.create_customer_support_conversation(p_subject text, p_message text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  current_user_id uuid := public.ensure_customer_profile();
  clean_subject text := btrim(coalesce(p_subject, ''));
  clean_message text := btrim(coalesce(p_message, ''));
  conversation_id uuid;
BEGIN
  IF clean_subject NOT IN ('Product Inquiry', 'Order Support', 'Return & Exchange', 'Styling Advice', 'Other') THEN
    RAISE EXCEPTION 'Choose a valid conversation subject' USING ERRCODE = '22023';
  END IF;
  IF length(clean_message) NOT BETWEEN 1 AND 4000 THEN
    RAISE EXCEPTION 'Message must contain between 1 and 4000 characters' USING ERRCODE = '22023';
  END IF;

  DELETE FROM public.support_conversations AS c
  WHERE c.customer_id = current_user_id
    AND NOT EXISTS (
      SELECT 1 FROM public.support_messages AS m WHERE m.conversation_id = c.id
    );

  INSERT INTO public.support_conversations(customer_id, subject)
  VALUES (current_user_id, clean_subject)
  RETURNING id INTO conversation_id;

  INSERT INTO public.support_messages(conversation_id, sender_type, message)
  VALUES (conversation_id, 'customer', clean_message);

  UPDATE public.support_conversations AS c
  SET updated_at = now(), customer_read_at = now()
  WHERE c.id = conversation_id;

  RETURN conversation_id;
END;
$$;
REVOKE ALL ON FUNCTION public.create_customer_support_conversation(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_customer_support_conversation(text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.send_customer_support_message(text);

CREATE FUNCTION public.send_customer_support_message(p_conversation_id uuid, p_message text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  current_user_id uuid := public.ensure_customer_profile();
  clean_message text := btrim(coalesce(p_message, ''));
BEGIN
  IF length(clean_message) NOT BETWEEN 1 AND 4000 THEN
    RAISE EXCEPTION 'Message must contain between 1 and 4000 characters' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.support_conversations AS c
    WHERE c.id = p_conversation_id AND c.customer_id = current_user_id
  ) THEN
    RAISE EXCEPTION 'Support conversation not found' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.support_messages(conversation_id, sender_type, message)
  VALUES (p_conversation_id, 'customer', clean_message);

  UPDATE public.support_conversations AS c
  SET updated_at = now(), customer_read_at = now()
  WHERE c.id = p_conversation_id;

  RETURN p_conversation_id;
END;
$$;
REVOKE ALL ON FUNCTION public.send_customer_support_message(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_customer_support_message(uuid, text) TO authenticated;