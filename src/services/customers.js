import { supabase } from "../lib/supabase";

// profiles and orders both reference auth.users but have no FK to each
// other, so PostgREST can't embed them together. Fetch separately and merge.
export async function getCustomers() {
  const { data: profiles, error } = await supabase
    .from("profiles")
    .select("*")
    .order("created_at", { ascending: false });
  if (error) throw error;

  const { data: orders, error: oErr } = await supabase
    .from("orders")
    .select("id,user_id,status,total_cents,created_at");
  if (oErr) throw oErr;

  const byUser = {};
  for (const o of orders || []) (byUser[o.user_id] ||= []).push(o);

  return (profiles || []).map((p) => ({ ...p, orders: byUser[p.id] || [] }));
}

export async function getCustomerById(userId) {
  const [{ data: profile, error }, { data: addresses, error: aErr }, { data: orders, error: oErr }] =
    await Promise.all([
      supabase.from("profiles").select("*").eq("id", userId).single(),
      supabase.from("addresses").select("*").eq("user_id", userId),
      supabase.from("orders").select("*,order_items(*)").eq("user_id", userId).order("created_at", { ascending: false }),
    ]);
  if (error) throw error;
  if (aErr) throw aErr;
  if (oErr) throw oErr;

  return { ...profile, addresses: addresses || [], orders: orders || [] };
}
