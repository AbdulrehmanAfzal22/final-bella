import { supabase } from "../lib/supabase";

export async function getRelatedProducts(categoryId, productId) {
  const { data, error } = await supabase
    .from("products")
    .select(`
      *,
      product_images(*)
    `)
    .eq("category_id", categoryId)
    .neq("id", productId)
    .eq("status", "published")
    .limit(4);

  if (error) throw error;

  return data || [];
}

export function saveRecentlyViewed(product) {
  const existing = JSON.parse(
    localStorage.getItem("recent_products") || "[]"
  );

  const updated = [
    product,
    ...existing.filter((item) => item.id !== product.id)
  ].slice(0, 8);

  localStorage.setItem(
    "recent_products",
    JSON.stringify(updated)
  );
}

export function getRecentlyViewed() {
  return JSON.parse(
    localStorage.getItem("recent_products") || "[]"
  );
}
