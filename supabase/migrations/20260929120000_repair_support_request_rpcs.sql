CREATE OR REPLACE FUNCTION public.admin_get_support_requests()
RETURNS SETOF public.support_requests
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
    SELECT r.*
    FROM public.support_requests AS r
    ORDER BY r.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_get_support_requests() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_support_requests() TO authenticated;

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
BEGIN
  IF NOT private.is_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE = '42501';
  END IF;
  IF p_status IS NULL OR p_status NOT IN ('new', 'in_progress', 'resolved', 'closed') THEN
    RAISE EXCEPTION 'Invalid support request status';
  END IF;

  UPDATE public.support_requests AS r
  SET status = p_status,
      admin_note = p_admin_note,
      admin_reply = p_admin_reply
  WHERE r.id = p_id
  RETURNING r.* INTO updated_request;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Support request not found';
  END IF;

  RETURN NEXT updated_request;
  RETURN;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_support_request(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_support_request(uuid, text, text, text) TO authenticated;