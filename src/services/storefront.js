import { supabase } from "../lib/supabase";

export async function getPublishedProducts(category = null) {
  let query = supabase
    .from("products")
    .select(`
      *,
      product_images(*),
      product_variants(*),
      categories(name, slug)
    `)
    .eq("status", "published")
    .order("created_at", { ascending: false });

  if (category) {
    query = query.eq("categories.slug", category);
  }

  const { data, error } = await query;

  if (error) throw error;

  return data || [];
}

export async function getProductById(id) {
  const { data, error } = await supabase
    .from("products")
    .select(`
      *,
      product_images(*),
      product_variants(*),
      categories(name, slug)
    `)
    .eq("id", id)
    .single();

  if (error) throw error;

  return data;
}
