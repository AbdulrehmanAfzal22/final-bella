import { supabase } from "../lib/supabase";

export async function getInventory() {
  const { data, error } = await supabase
    .from("product_variants")
    .select(`
      *,
      products(name)
    `)
    .order("stock", { ascending: true });

  if (error) throw error;

  return data || [];
}

export async function updateStock(variantId, stock, updatedAt) {
  const { data, error } = await supabase
    .from("product_variants")
    .update({ stock })
    .eq("id", variantId)
    .eq("updated_at", updatedAt)
    .select()
    .maybeSingle();

  if (error) throw error;

  if (!data) throw new Error('Stock changed since this page loaded. Refresh before saving again.');
  return data;
}

export function getLowStockItems(items, threshold = 5) {
  return items.filter((item) => item.stock <= threshold);
}
