import { supabase } from "../lib/supabase";

export async function getProfile(userId) {
  const { data, error } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", userId)
    .single();

  if (error) throw error;
  return data;
}

export async function updateProfile(userId, payload) {
  const { data, error } = await supabase
    .from("profiles")
    .update(payload)
    .eq("id", userId)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function getAddresses(userId) {
  const { data, error } = await supabase
    .from("addresses")
    .select("*")
    .eq("user_id", userId);

  if (error) throw error;
  return data || [];
}

export async function addAddress(payload) {
  const { data, error } = await supabase
    .from("addresses")
    .insert(payload)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function removeAddress(id) {
  const { error } = await supabase.from("addresses").delete().eq("id", id);
  if (error) throw error;
}
