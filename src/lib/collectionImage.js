import {categoryImageUrl,imageUrl} from './supabase';

const editorialImages=['/assets/bella-beauty-editorial.png','/assets/bella-lip-oil.png','/assets/bella-tint.png','/assets/bella-balm.png'];

export function collectionImage(category,productImage,index=0){
  if(category?.image_path)return categoryImageUrl(category.image_path);
  if(productImage?.path)return imageUrl(productImage.path);
  return editorialImages[Math.abs(index)%editorialImages.length];
}

export function collectionImageAlt(category,productImage){
  return category?.image_path?category.image_alt||category.name:productImage?.alt||`${category?.name||'Collection'} beauty edit`;
}