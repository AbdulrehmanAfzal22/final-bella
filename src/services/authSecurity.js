import { supabase } from "../lib/supabase";

export async function getCurrentSession() {
  const { data, error } = await supabase.auth.getSession();

  if (error) throw error;

  return data.session;
}

export async function signOutUser() {
  const { error } = await supabase.auth.signOut();

  if (error) throw error;
}

export async function requestPasswordReset(email) {
  const { error } = await supabase.auth.resetPasswordForEmail(email);

  if (error) throw error;
}

export async function updatePassword(password) {
  const { error } = await supabase.auth.updateUser({
    password
  });

  if (error) throw error;
}
