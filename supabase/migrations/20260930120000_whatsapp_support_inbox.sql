ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text;

UPDATE public.profiles AS p
SET email = lower(btrim(u.email))
FROM auth.users AS u
WHERE u.id = p.id AND p.email IS DISTINCT FROM lower(btrim(u.email));

CREATE INDEX IF NOT EXISTS profiles_email_lower_idx ON public.profiles(lower(email));

CREATE OR REPLACE FUNCTION private.sync_profile_from_auth()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles(id, email, full_name)
  VALUES (
    NEW.id,
    lower(btrim(coalesce(NEW.email, ''))),
    left(btrim(coalesce(NEW.raw_user_meta_data ->> 'full_name', '')), 150)
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      full_name = CASE
        WHEN btrim(public.profiles.full_name) = '' THEN EXCLUDED.full_name
        ELSE public.profiles.full_name
      END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_profile_from_auth ON auth.users;
CREATE TRIGGER sync_profile_from_auth
AFTER INSERT OR UPDATE ON auth.users
FOR EACH ROW EXECUTE FUNCTION private.sync_profile_from_auth();

CREATE TABLE public.support_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  customer_read_at timestamptz NOT NULL DEFAULT now(),
  admin_read_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX support_conversations_updated_idx ON public.support_conversations(updated_at DESC);

CREATE OR REPLACE FUNCTION private.create_support_conversation_for_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.support_conversations(customer_id)
  VALUES (NEW.id)
  ON CONFLICT (customer_id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER create_support_conversation_for_profile
AFTER INSERT ON public.profiles
FOR EACH ROW EXECUTE FUNCTION private.create_support_conversation_for_profile();

INSERT INTO public.support_conversations(customer_id)
SELECT p.id FROM public.profiles AS p
ON CONFLICT (customer_id) DO NOTHING;

ALTER TABLE public.support_messages RENAME TO support_request_messages_legacy;
ALTER TABLE public.support_request_messages_legacy
  RENAME CONSTRAINT support_messages_pkey TO support_request_messages_legacy_pkey;
CREATE TABLE public.support_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.support_conversations(id) ON DELETE CASCADE,
  sender_type text NOT NULL CHECK (sender_type IN ('customer', 'admin')),
  message text NOT NULL CHECK (length(btrim(message)) BETWEEN 1 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX support_messages_conversation_created_idx
  ON public.support_messages(conversation_id, created_at, id);

INSERT INTO public.support_messages(conversation_id, sender_type, message, created_at)
SELECT c.id, m.sender_type, m.message, m.created_at
FROM public.support_request_messages_legacy AS m
JOIN public.support_requests AS r ON r.id = m.support_request_id
JOIN public.support_conversations AS c ON c.customer_id = r.user_id
WHERE btrim(m.message) <> '';

ALTER TABLE public.support_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.support_conversations FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.support_messages FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.support_request_messages_legacy FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.support_conversations, public.support_messages TO authenticated;

DROP POLICY IF EXISTS support_conversations_read ON public.support_conversations;
CREATE POLICY support_conversations_read ON public.support_conversations
FOR SELECT TO authenticated
USING (customer_id = (SELECT auth.uid()) OR (SELECT private.is_admin()));

DROP POLICY IF EXISTS support_messages_read ON public.support_messages;
CREATE POLICY support_messages_read ON public.support_messages
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.support_conversations AS c
    WHERE c.id = support_messages.conversation_id
      AND (c.customer_id = (SELECT auth.uid()) OR (SELECT private.is_admin()))
  )
);

DROP FUNCTION IF EXISTS public.submit_support_request(text, text, text, text, text);
DROP FUNCTION IF EXISTS public.get_my_support_conversations();
DROP FUNCTION IF EXISTS public.get_my_support_messages(uuid);
DROP FUNCTION IF EXISTS public.admin_get_support_messages(uuid);
DROP FUNCTION IF EXISTS public.admin_get_support_requests();
DROP FUNCTION IF EXISTS public.admin_update_support_request(uuid, text, text, text);

CREATE OR REPLACE FUNCTION public.ensure_customer_profile()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  current_user_id uuid := auth.uid();
  auth_user auth.users%ROWTYPE;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  SELECT u.* INTO auth_user FROM auth.users AS u WHERE u.id = current_user_id;
  IF NOT FOUND OR coalesce(auth_user.email, '') = '' THEN
    RAISE EXCEPTION 'An email-authenticated account is required' USING ERRCODE = '28000';
  END IF;

  INSERT INTO public.profiles(id, email, full_name)
  VALUES (
    current_user_id,
    lower(btrim(auth_user.email)),
    left(btrim(coalesce(auth_user.raw_user_meta_data ->> 'full_name', '')), 150)
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      full_name = CASE
        WHEN btrim(public.profiles.full_name) = '' THEN EXCLUDED.full_name
        ELSE public.profiles.full_name
      END;

  RETURN current_user_id;
END;
$$;
REVOKE ALL ON FUNCTION public.ensure_customer_profile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ensure_customer_profile() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_support_conversations()
RETURNS TABLE(
  id uuid,
  customer_id uuid,
  customer_name text,
  customer_email text,
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
  SELECT c.id, c.customer_id, p.full_name, p.email, c.updated_at,
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
  WHERE auth.uid() IS NOT NULL AND c.customer_id = auth.uid()
  ORDER BY coalesce(latest.created_at, c.updated_at) DESC, c.id
$$;
REVOKE ALL ON FUNCTION public.get_my_support_conversations() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_support_conversations() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_get_support_inbox()
RETURNS TABLE(
  id uuid,
  customer_id uuid,
  customer_name text,
  customer_email text,
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
  SELECT c.id, p.id, p.full_name, p.email, c.updated_at,
         latest.message, latest.sender_type, latest.created_at,
         (SELECT count(*) FROM public.support_messages AS unread
          WHERE unread.conversation_id = c.id
            AND unread.sender_type = 'customer'
            AND unread.created_at > c.admin_read_at) AS unread_count
  FROM public.profiles AS p
  JOIN public.support_conversations AS c ON c.customer_id = p.id
  LEFT JOIN LATERAL (
    SELECT m.message, m.sender_type, m.created_at
    FROM public.support_messages AS m
    WHERE m.conversation_id = c.id
    ORDER BY m.created_at DESC, m.id DESC
    LIMIT 1
  ) AS latest ON true
  WHERE private.is_admin()
  ORDER BY coalesce(latest.created_at, c.updated_at) DESC, p.full_name, p.id
$$;
REVOKE ALL ON FUNCTION public.admin_get_support_inbox() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_support_inbox() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_support_messages(p_conversation_id uuid)
RETURNS TABLE(id uuid, conversation_id uuid, sender_type text, message text, created_at timestamptz)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.support_conversations AS c
    WHERE c.id = p_conversation_id AND c.customer_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Support conversation not found' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
    SELECT m.id, m.conversation_id, m.sender_type, m.message, m.created_at
    FROM public.support_messages AS m
    WHERE m.conversation_id = p_conversation_id
    ORDER BY m.created_at, m.id;
END;
$$;
REVOKE ALL ON FUNCTION public.get_my_support_messages(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_support_messages(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_get_support_messages(p_conversation_id uuid)
RETURNS TABLE(id uuid, conversation_id uuid, sender_type text, message text, created_at timestamptz)
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
    SELECT m.id, m.conversation_id, m.sender_type, m.message, m.created_at
    FROM public.support_messages AS m
    WHERE m.conversation_id = p_conversation_id
    ORDER BY m.created_at, m.id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_get_support_messages(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_support_messages(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.send_customer_support_message(p_message text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  current_user_id uuid := public.ensure_customer_profile();
  conversation_id uuid;
  clean_message text := btrim(coalesce(p_message, ''));
BEGIN
  IF length(clean_message) NOT BETWEEN 1 AND 4000 THEN
    RAISE EXCEPTION 'Message must contain between 1 and 4000 characters' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.support_conversations(customer_id)
  VALUES (current_user_id)
  ON CONFLICT (customer_id) DO NOTHING;

  SELECT c.id INTO conversation_id
  FROM public.support_conversations AS c
  WHERE c.customer_id = current_user_id;

  INSERT INTO public.support_messages(conversation_id, sender_type, message)
  VALUES (conversation_id, 'customer', clean_message);

  UPDATE public.support_conversations AS c
  SET updated_at = now(), customer_read_at = now()
  WHERE c.id = conversation_id;

  RETURN conversation_id;
END;
$$;
REVOKE ALL ON FUNCTION public.send_customer_support_message(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_customer_support_message(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_send_support_message(p_conversation_id uuid, p_message text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  clean_message text := btrim(coalesce(p_message, ''));
BEGIN
  IF NOT private.is_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE = '42501';
  END IF;
  IF length(clean_message) NOT BETWEEN 1 AND 4000 THEN
    RAISE EXCEPTION 'Message must contain between 1 and 4000 characters' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.support_conversations AS c WHERE c.id = p_conversation_id) THEN
    RAISE EXCEPTION 'Support conversation not found' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.support_messages(conversation_id, sender_type, message)
  VALUES (p_conversation_id, 'admin', clean_message);

  UPDATE public.support_conversations AS c
  SET updated_at = now(), admin_read_at = now()
  WHERE c.id = p_conversation_id;

  RETURN p_conversation_id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_send_support_message(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_send_support_message(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_support_conversation_read(p_conversation_id uuid, p_admin boolean DEFAULT false)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF p_admin THEN
    IF NOT private.is_admin() THEN
      RAISE EXCEPTION 'Admin access required' USING ERRCODE = '42501';
    END IF;
    UPDATE public.support_conversations
    SET admin_read_at = now()
    WHERE id = p_conversation_id;
  ELSE
    UPDATE public.support_conversations
    SET customer_read_at = now()
    WHERE id = p_conversation_id AND customer_id = auth.uid();
  END IF;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Support conversation not found' USING ERRCODE = '42501';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.mark_support_conversation_read(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_support_conversation_read(uuid, boolean) TO authenticated;