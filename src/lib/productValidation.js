export function validateProductForSave({categoryId,description,status,images=[],files=[],variants=[]}){
  if(!categoryId)throw new Error('Choose a category before saving this product.');
  if(status==='published'){
    if(!description?.trim())throw new Error('Add a product description before publishing.');
    if(!variants.some(variant=>variant.color?.trim()&&variant.size?.trim()))throw new Error('Add at least one complete colour and size variant before publishing.');
    if(images.length+files.length===0)throw new Error('Add at least one product image before publishing.');
  }
}