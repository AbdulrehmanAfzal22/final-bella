import { supabase } from "../lib/supabase";

export async function getProductVariants(productId) {
  const { data, error } = await supabase
    .from("product_variants")
    .select("*")
    .eq("product_id", productId)
    .order("color")
    .order("size");

  if (error) throw error;
  return data || [];
}

export async function createVariant(payload) {
  const { data, error } = await supabase
    .from("product_variants")
    .insert(payload)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function updateVariant(id, payload) {
  const { data, error } = await supabase
    .from("product_variants")
    .update(payload)
    .eq("id", id)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function deleteVariant(id) {
  const { error } = await supabase
    .from("product_variants")
    .delete()
    .eq("id", id);

  if (error) throw error;
}
