-- ============================================================
-- Lets an Admin or the MD set a new password for a staff member
-- (used by the "Reset password" button on the HR and staff page).
-- Run once in Supabase Dashboard > SQL Editor.
-- Safe to re-run.
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_set_password(p_user uuid, p_password text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  caller_role text;
  target_role text;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
  IF caller_role IS NULL OR caller_role NOT IN ('admin', 'md') THEN
    RAISE EXCEPTION 'Only an Admin or the MD can reset passwords.';
  END IF;

  SELECT role INTO target_role FROM public.profiles WHERE id = p_user;
  IF target_role IS NULL THEN
    RAISE EXCEPTION 'Staff member not found.';
  END IF;

  -- Only the MD may reset the MD's password
  IF target_role = 'md' AND caller_role <> 'md' THEN
    RAISE EXCEPTION 'Only the MD can reset the MD password.';
  END IF;

  IF p_password IS NULL OR length(p_password) < 8 THEN
    RAISE EXCEPTION 'Password must be at least 8 characters.';
  END IF;

  UPDATE auth.users
     SET encrypted_password = crypt(p_password, gen_salt('bf')),
         updated_at = now()
   WHERE id = p_user;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_password(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_password(uuid, text) TO authenticated;
