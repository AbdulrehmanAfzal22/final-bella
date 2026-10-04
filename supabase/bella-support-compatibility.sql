-- Preserve the existing request/reply tables and subject grouping.
-- Supply the RPC parameters and presentation fields expected by the ZIP.
ALTER TABLE public.support_requests
 ADD COLUMN customer_read_at timestamptz NOT NULL DEFAULT '-infinity',
 ADD COLUMN admin_read_at timestamptz NOT NULL DEFAULT '-infinity';

CREATE FUNCTION private.mark_support_conversation_read(p_conversation_id uuid,p_admin boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE anchor public.support_requests%ROWTYPE; uid uuid:=auth.uid();
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 SELECT * INTO anchor FROM public.support_requests WHERE id=p_conversation_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Support conversation not found' USING ERRCODE='42501'; END IF;
 IF p_admin THEN
  IF NOT private.is_admin() THEN RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501'; END IF;
  UPDATE public.support_requests r SET admin_read_at=clock_timestamp(),status=CASE WHEN status='new' THEN 'in_progress' ELSE status END
  WHERE r.user_id IS NOT DISTINCT FROM anchor.user_id AND lower(btrim(r.subject))=lower(btrim(anchor.subject))
   AND (anchor.user_id IS NOT NULL OR r.customer_email=anchor.customer_email);
 ELSE
  IF anchor.user_id IS DISTINCT FROM uid THEN RAISE EXCEPTION 'Support conversation not found' USING ERRCODE='42501'; END IF;
  UPDATE public.support_requests r SET customer_read_at=clock_timestamp()
  WHERE r.user_id=uid AND lower(btrim(r.subject))=lower(btrim(anchor.subject));
 END IF;
END $$;
REVOKE ALL ON FUNCTION private.mark_support_conversation_read(uuid,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION private.mark_support_conversation_read(uuid,boolean) TO authenticated;
CREATE FUNCTION public.mark_support_conversation_read(p_conversation_id uuid,p_admin boolean DEFAULT false)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$SELECT private.mark_support_conversation_read(p_conversation_id,p_admin)$$;
REVOKE ALL ON FUNCTION public.mark_support_conversation_read(uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.mark_support_conversation_read(uuid,boolean) TO authenticated;

-- New reply is attached to the selected subject, with the existing ownership checks.
CREATE FUNCTION public.send_customer_support_message(p_conversation_id uuid,p_message text)
RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE c record; sender record; request_id uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 IF p_conversation_id IS NULL THEN RETURN public.send_customer_support_message(p_message); END IF;
 SELECT * INTO c FROM public.get_my_support_conversations() WHERE id=p_conversation_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Support conversation not found' USING ERRCODE='42501'; END IF;
 SELECT * INTO sender FROM private.get_customer_support_sender();
 request_id:=public.submit_support_request(sender.customer_email,sender.customer_name,sender.customer_phone,p_message,c.subject);
 RETURN c.id;
END $$;
REVOKE ALL ON FUNCTION public.send_customer_support_message(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.send_customer_support_message(uuid,text) TO authenticated;

-- Public list wrappers keep the existing legacy fields and add chat-preview fields.
DROP FUNCTION public.get_my_support_conversations();
CREATE FUNCTION private.get_my_support_chat()
RETURNS TABLE(id uuid,subject text,status text,message text,admin_reply text,created_at timestamptz,updated_at timestamptz,message_count bigint,messages jsonb,latest_message text,latest_sender_type text,latest_message_created_at timestamptz,unread_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 RETURN QUERY
 SELECT c.id,c.subject,c.status,c.message,c.admin_reply,c.created_at,c.updated_at,c.message_count,c.messages,
  latest.value->>'message',latest.value->>'sender_type',(latest.value->>'created_at')::timestamptz,
  (SELECT count(*) FROM jsonb_array_elements(c.messages) e WHERE e->>'sender_type'='admin' AND (e->>'created_at')::timestamptz>(SELECT max(r.customer_read_at) FROM public.support_requests r WHERE r.user_id=auth.uid() AND lower(btrim(r.subject))=lower(btrim(c.subject))))
 FROM private.get_my_support_conversations() c
 LEFT JOIN LATERAL (SELECT e.value FROM jsonb_array_elements(c.messages) WITH ORDINALITY e(value,n) ORDER BY n DESC LIMIT 1) latest ON true;
END $$;

REVOKE ALL ON FUNCTION private.get_my_support_chat() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION private.get_my_support_chat() TO authenticated;
CREATE FUNCTION public.get_my_support_conversations()
RETURNS TABLE(id uuid,subject text,status text,message text,admin_reply text,created_at timestamptz,updated_at timestamptz,message_count bigint,messages jsonb,latest_message text,latest_sender_type text,latest_message_created_at timestamptz,unread_count bigint)
LANGUAGE sql SECURITY INVOKER STABLE SET search_path='' AS $$SELECT * FROM private.get_my_support_chat()$$;
REVOKE ALL ON FUNCTION public.get_my_support_conversations() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_support_conversations() TO authenticated;

DROP FUNCTION public.admin_get_support_inbox();
CREATE FUNCTION private.get_admin_support_chat()
RETURNS TABLE(id uuid,user_id uuid,customer_name text,customer_email text,customer_phone text,subject text,status text,message text,admin_reply text,admin_note text,created_at timestamptz,updated_at timestamptz,conversation_id uuid,support_request_id uuid,conversation_count bigint,message_count bigint,conversations jsonb,latest_message text,latest_sender_type text,latest_message_created_at timestamptz,unread_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT private.is_admin() THEN RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501'; END IF;
 RETURN QUERY
 SELECT c.*,latest.message,latest.sender_type,latest.created_at,
 (SELECT count(*) FROM public.admin_get_support_messages(p_conversation_id=>c.id) m WHERE m.sender_type='customer' AND m.created_at>(SELECT max(r.admin_read_at) FROM public.support_requests r WHERE r.user_id IS NOT DISTINCT FROM c.user_id AND lower(btrim(r.subject))=lower(btrim(c.subject)) AND (c.user_id IS NOT NULL OR r.customer_email=c.customer_email)))
 FROM private.admin_get_support_inbox() c
 LEFT JOIN LATERAL (SELECT m.message,m.sender_type,m.created_at FROM public.admin_get_support_messages(p_conversation_id=>c.id) m ORDER BY m.created_at DESC,m.id DESC LIMIT 1) latest ON true;
END $$;
REVOKE ALL ON FUNCTION private.get_admin_support_chat() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION private.get_admin_support_chat() TO authenticated;
CREATE FUNCTION public.admin_get_support_inbox()
RETURNS TABLE(id uuid,user_id uuid,customer_name text,customer_email text,customer_phone text,subject text,status text,message text,admin_reply text,admin_note text,created_at timestamptz,updated_at timestamptz,conversation_id uuid,support_request_id uuid,conversation_count bigint,message_count bigint,conversations jsonb,latest_message text,latest_sender_type text,latest_message_created_at timestamptz,unread_count bigint)
LANGUAGE sql SECURITY INVOKER STABLE SET search_path='' AS $$SELECT * FROM private.get_admin_support_chat()$$;
REVOKE ALL ON FUNCTION public.admin_get_support_inbox() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_get_support_inbox() TO authenticated;
NOTIFY pgrst,'reload schema';
