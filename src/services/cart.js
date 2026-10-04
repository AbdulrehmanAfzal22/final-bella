import { supabase, unwrap } from "../lib/supabase";

const cartSelect = "variant_id,quantity,product_variants(*,products(*,product_images(*)))";

export function notifyCartChanged(source){
  window.dispatchEvent(new CustomEvent('maison:cart-changed',{detail:{source}}));
}

export async function getCart(userId) {
  if (!userId) return [];
  const { data, error } = await supabase
    .from("cart_items")
    .select(cartSelect)
    .eq("user_id", userId);

  if (error) throw error;
  return data || [];
}

export async function addToCart(variantId, quantity = 1) {
  const result=unwrap(await supabase.rpc("add_to_cart", { p_variant_id: variantId, p_quantity: quantity }));
  notifyCartChanged();
  return result;
}

export async function updateCartItem(variantId, quantity, source) {
  const result=unwrap(await supabase.rpc("set_cart_quantity", { p_variant_id: variantId, p_quantity: quantity }));
  notifyCartChanged(source);
  return result;
}

export async function removeCartItem(variantId, source) {
  const result=unwrap(await supabase.rpc("remove_from_cart", { p_variant_id: variantId }));
  notifyCartChanged(source);
  return result;
}
