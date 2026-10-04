import { supabase } from "../lib/supabase";

export async function getOrderConfirmation(orderId, userId) {
  const { data, error } = await supabase
    .from("orders")
    .select("*,order_items(*),order_status_history(*)")
    .eq("id", orderId)
    .eq("user_id", userId)
    .maybeSingle();

  if (error) throw error;
  return data;
}
