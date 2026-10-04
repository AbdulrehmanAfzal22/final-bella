import {uuid} from '../lib/uuid';
import {supabase,unwrap} from '../lib/supabase';

const allowedTypes={'image/jpeg':'jpg','image/png':'png','image/webp':'webp'};

export async function uploadCategoryImage(file,categoryId){
  if(!allowedTypes[file?.type]||file.size>5*1024*1024)throw new Error('Use a JPEG, PNG, or WebP image under 5 MB.');
  const path=`${categoryId}/${uuid()}.${allowedTypes[file.type]}`;
  unwrap(await supabase.storage.from('category-images').upload(path,file,{contentType:file.type,upsert:false}));
  return path;
}

export async function removeCategoryImage(path){
  if(!path)return;
  unwrap(await supabase.storage.from('category-images').remove([path]));
}