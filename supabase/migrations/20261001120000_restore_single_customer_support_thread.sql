BEGIN;

CREATE TEMP TABLE support_conversation_merge ON COMMIT DROP AS
SELECT
  id,
  first_value(id) OVER (
    PARTITION BY customer_id
    ORDER BY created_at, id
  ) AS canonical_id,
  row_number() OVER (
    PARTITION BY customer_id
    ORDER BY created_at, id
  ) AS conversation_rank
FROM public.support_conversations;

UPDATE public.support_messages AS m
SET conversation_id = merge_map.canonical_id
FROM support_conversation_merge AS merge_map
WHERE m.conversation_id = merge_map.id
  AND merge_map.conversation_rank > 1;

DELETE FROM public.support_conversations AS c
USING support_conversation_merge AS merge_map
WHERE c.id = merge_map.id
  AND merge_map.conversation_rank > 1;

CREATE UNIQUE INDEX IF NOT EXISTS support_conversations_customer_id_uidx
  ON public.support_conversations(customer_id);

DROP FUNCTION IF EXISTS public.create_customer_support_conversation(text, text);

CREATE OR REPLACE FUNCTION public.start_customer_support_conversation(p_message text)
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

  INSERT INTO public.support_conversations(customer_id, subject)
  VALUES (current_user_id, 'Customer Support')
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
REVOKE ALL ON FUNCTION public.start_customer_support_conversation(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_customer_support_conversation(text) TO authenticated;

COMMIT;