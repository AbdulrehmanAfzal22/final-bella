import { supabase } from "../lib/supabase";

const select = "*,categories(name,slug),product_images(*),product_variants(*)";

export async function getFeaturedProducts() {
  const { data, error } = await supabase
    .from("products")
    .select(select)
    .eq("featured", true)
    .eq("status", "published");

  if (error) throw error;
  return data || [];
}

export async function getNewArrivals() {
  const { data, error } = await supabase
    .from("products")
    .select(select)
    .eq("status", "published")
    .order("created_at", { ascending: false })
    .limit(12);

  if (error) throw error;
  return data || [];
}
// Note: there is no "on_sale" or "price" column in the schema (products use
// price_cents and status/featured only), so a sale collection isn't
// representable yet -- add a boolean column + migration if this is needed.
