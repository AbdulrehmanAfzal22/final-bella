import { supabase } from "../lib/supabase";

const orderSelect = "*,order_items(*),order_status_history(*)";

export async function getCustomerOrders(userId) {
  const { data, error } = await supabase
    .from("orders")
    .select(orderSelect)
    .eq("user_id", userId)
    .order("created_at", { ascending: false });

  if (error) throw error;
  return data || [];
}

export async function getOrderById(orderId, userId) {
  const { data, error } = await supabase
    .from("orders")
    .select(orderSelect)
    .eq("id", orderId)
    .eq("user_id", userId)
    .single();

  if (error) throw error;
  return data;
}
