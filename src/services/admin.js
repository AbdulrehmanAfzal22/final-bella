import { supabase } from "../lib/supabase";

export async function checkAdminAccess(userId) {
  if (!userId) return false;

  const { data, error } = await supabase
    .schema("private")
    .from("admin_members")
    .select("user_id")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) return false;

  return Boolean(data);
}
