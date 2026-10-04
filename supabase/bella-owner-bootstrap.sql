-- The owner selected this email for the separate Bella store.
-- No clothing-store accounts, passwords or memberships are transferred.
CREATE FUNCTION private.assign_bella_owner()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF lower(NEW.email)='abdulrehmanafzal60@gmail.com'
    AND NEW.email_confirmed_at IS NOT NULL AND NEW.deleted_at IS NULL THEN
  INSERT INTO private.admin_members(user_id) VALUES(NEW.id) ON CONFLICT DO NOTHING;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.assign_bella_owner() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER assign_bella_owner_on_verified_email
AFTER INSERT OR UPDATE OF email,email_confirmed_at,deleted_at ON auth.users
FOR EACH ROW EXECUTE FUNCTION private.assign_bella_owner();
