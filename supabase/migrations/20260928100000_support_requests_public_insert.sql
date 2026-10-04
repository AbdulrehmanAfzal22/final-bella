ALTER TABLE public.support_requests ENABLE ROW LEVEL SECURITY;

GRANT INSERT ON TABLE public.support_requests TO anon, authenticated;

DROP POLICY IF EXISTS support_requests_public_insert ON public.support_requests;
CREATE POLICY support_requests_public_insert
  ON public.support_requests
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    btrim(customer_name) <> ''
    AND btrim(customer_email) <> ''
    AND btrim(customer_phone) <> ''
    AND btrim(subject) <> ''
    AND btrim(message) <> ''
    AND status = 'new'
    AND coalesce(admin_note, '') = ''
  );