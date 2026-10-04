import { supabase } from "../lib/supabase";
import { recordedRevenue } from '../lib/orderStatus';

export async function getDashboardMetrics() {
  const [products, customers, orders, variants, revenue] = await Promise.all([
    supabase.from("products").select("id", { count: "exact", head: true }),
    supabase.from("profiles").select("id", { count: "exact", head: true }),
    supabase.from("orders").select("id", { count: "exact", head: true }),
    supabase.from("product_variants").select("stock").eq('active',true),
    supabase.from("orders").select("total_cents,payment_status"),
  ]);

  for (const result of [products, customers, orders, variants, revenue]) {
    if (result.error) throw result.error;
  }

  const inventory = (variants.data || []).reduce((sum, v) => sum + (v.stock || 0), 0);
  const revenueCents = recordedRevenue(revenue.data);

  return {
    products: products.count || 0,
    customers: customers.count || 0,
    orders: orders.count || 0,
    inventory,
    revenueCents,
  };
}
