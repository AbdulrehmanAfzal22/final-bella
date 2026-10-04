import { supabase } from "../lib/supabase";
import { recordedRevenue } from '../lib/orderStatus';

export async function getAnalytics() {
  const { data: orders, error } = await supabase
    .from("orders")
    .select("id,total_cents,status,payment_status,created_at");

  if (error) throw error;

  const totalOrders = orders.length;

  const revenueCents = recordedRevenue(orders);

  const completedOrders = orders.filter(
    (order) => order.status === "delivered"
  ).length;

  return {
    totalOrders,
    revenueCents,
    completedOrders
  };
}
