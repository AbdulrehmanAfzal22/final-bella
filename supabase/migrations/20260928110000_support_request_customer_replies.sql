ALTER TABLE public.support_requests
  ADD COLUMN IF NOT EXISTS admin_reply text,
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS support_requests_user_created_idx
  ON public.support_requests(user_id, created_at DESC)
  WHERE user_id IS NOT NULL;

ALTER TABLE public.support_requests ENABLE ROW LEVEL SECURITY;

GRANT INSERT ON TABLE public.support_requests TO anon, authenticated;
REVOKE SELECT, UPDATE ON TABLE public.support_requests FROM PUBLIC, anon, authenticated;

DROP POLICY IF EXISTS support_requests_public_insert ON public.support_requests;
CREATE POLICY support_requests_public_insert
  ON public.support_requests
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    (user_id IS NULL OR user_id = (SELECT auth.uid()))
    AND btrim(customer_name) <> ''
    AND btrim(customer_email) <> ''
    AND btrim(customer_phone) <> ''
    AND btrim(subject) <> ''
    AND btrim(message) <> ''
    AND status = 'new'
    AND coalesce(admin_note, '') = ''
    AND coalesce(admin_reply, '') = ''
  );

DROP POLICY IF EXISTS support_requests_customer_or_admin_read ON public.support_requests;
CREATE POLICY support_requests_customer_or_admin_read
  ON public.support_requests
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()) OR (SELECT private.is_admin()));

DROP POLICY IF EXISTS support_requests_admin_update ON public.support_requests;
CREATE POLICY support_requests_admin_update
  ON public.support_requests
  FOR UPDATE
  TO authenticated
  USING ((SELECT private.is_admin()))
  WITH CHECK ((SELECT private.is_admin()));

CREATE OR REPLACE FUNCTION public.get_my_support_replies()
RETURNS TABLE(id uuid, subject text, message text, status text, admin_reply text, created_at timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT r.id, r.subject, r.message, r.status, r.admin_reply, r.created_at
  FROM public.support_requests AS r
  WHERE auth.uid() IS NOT NULL
    AND r.user_id = auth.uid()
  ORDER BY r.created_at DESC
$$;
REVOKE ALL ON FUNCTION public.get_my_support_replies() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_support_replies() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_get_support_requests()
RETURNS public.support_requests
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  updated_request public.support_requests%ROWTYPE;
BEGIN
  IF NOT private.is_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
    SELECT r.* FROM public.support_requests AS r ORDER BY r.created_at DESC;
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
BEGIN
  IF NOT private.is_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE = '42501';
  END IF;
  IF p_status NOT IN ('new', 'in_progress', 'resolved', 'closed') THEN
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
  RETURN updated_request;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_update_support_request(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_support_request(uuid, text, text, text) TO authenticated;