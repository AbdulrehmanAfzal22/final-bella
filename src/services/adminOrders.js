import { supabase } from "../lib/supabase";

// orders.user_id references auth.users, not public.profiles, so PostgREST
// cannot embed profiles(*) directly on orders (no FK between the two
// tables). Fetch orders and profiles separately and merge in JS instead.
export async function getAdminOrders() {
  const { data: orders, error } = await supabase
    .from("orders")
    .select("*,order_items(*),order_status_history(*)")
    .order("created_at", { ascending: false });
  if (error) throw error;

  const userIds = [...new Set((orders || []).map((o) => o.user_id))];
  let profiles = [];
  if (userIds.length) {
    const { data, error: pErr } = await supabase
      .from("profiles")
      .select("id,full_name")
      .in("id", userIds);
    if (pErr) throw pErr;
    profiles = data || [];
  }
  const byId = Object.fromEntries(profiles.map((p) => [p.id, p]));
  return (orders || []).map((o) => ({ ...o, customer: byId[o.user_id] || null }));
}

export async function updateOrderStatus(orderId, status) {
  const { error } = await supabase.rpc("set_order_status", { p_order_id: orderId, p_status: status });
  if (error) throw error;
}

export async function updatePaymentStatus(orderId, status) {
  const { error } = await supabase.rpc('set_payment_status', { p_order_id: orderId, p_status: status });
  if (error) throw error;
}
