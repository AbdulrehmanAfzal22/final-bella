import { supabase } from "../lib/supabase";

export async function uploadProductImage(file, productId) {
  const fileName = `${productId}/${Date.now()}-${file.name}`;

  const { error: uploadError } = await supabase.storage
    .from("product-images")
    .upload(fileName, file);

  if (uploadError) throw uploadError;

  const { data: publicUrl } = supabase.storage
    .from("product-images")
    .getPublicUrl(fileName);

  const { data, error } = await supabase
    .from("product_images")
    .insert({
      product_id: productId,
      path: fileName,
      alt: file.name,
    })
    .select()
    .single();

  if (error) throw error;

  return {
    ...data,
    url: publicUrl.publicUrl,
  };
}

export async function getProductImages(productId) {
  const { data, error } = await supabase
    .from("product_images")
    .select("*")
    .eq("product_id", productId)
    .order("position");

  if (error) throw error;

  return (data || []).map((image) => ({
    ...image,
    url: supabase.storage
      .from("product-images")
      .getPublicUrl(image.path).data.publicUrl,
  }));
}
