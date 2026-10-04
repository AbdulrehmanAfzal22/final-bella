import { uuid } from '../lib/uuid';
import {supabase,unwrap} from '../lib/supabase';
import {demoImageUrl} from '../lib/demoImages';
export const productSelect='*,categories(id,name,slug,is_accessory,is_active),product_images(*),product_variants(*)';
const productSelectBySection='*,categories!inner(id,name,slug,is_accessory,is_active),product_images(*),product_variants(*)';
export async function getProducts(admin=false, categoryId=null, isAccessory=null) {
 let q=supabase.from('products').select(isAccessory===null?productSelect:productSelectBySection).order('created_at',{ascending:false});
 if(!admin) q=q.eq('status','published');
 if(categoryId) q=q.eq('category_id',categoryId);
 if(isAccessory!==null) q=q.eq('categories.is_accessory',isAccessory);
 return unwrap(await q);
}
export async function getProductsByCategory(categoryId) {
 if(!categoryId) return [];
 return getProducts(false,categoryId);
}
export const getProduct=async id=>unwrap(await supabase.from('products').select(productSelect).eq('id',id).maybeSingle());
export async function getCategories(isAccessory=null){
 let q=supabase.from('categories').select('*').order('name');
 if(isAccessory!==null)q=q.eq('is_accessory',isAccessory);
 return unwrap(await q);
}
export async function getActiveCategories(isAccessory=null){
 let q=supabase.from('categories').select('*').eq('is_active',true).order('display_order').order('name');
 if(isAccessory!==null)q=q.eq('is_accessory',isAccessory);
 return unwrap(await q);
}
export async function archiveProduct(productId){
 if(!productId)throw new Error('A product ID is required.');
 const {data,error}=await supabase.from('products').update({status:'archived',featured:false}).eq('id',productId).select('id').maybeSingle();
 if(error)throw error;
 if(!data)throw new Error('Product not found or you do not have permission to archive it.');
 return data.id;
}
export async function deleteProduct(productId){
 if(!productId)throw new Error('A product ID is required.');
 const result=unwrap(await supabase.rpc('delete_product',{p_product_id:productId}));
 const imagePaths=result?.image_paths||[];
 if(imagePaths.some(path=>typeof path!=='string'||!path.startsWith(`${productId}/`)))return {id:result.product_id,storageCleanupError:'Image cleanup was skipped because an image path was outside its product folder.'};
 const storage=supabase.storage.from('product-images');
 const paths=new Set(imagePaths);
 let offset=0;
 while(true){
  const {data:objects,error}=await storage.list(productId,{limit:1000,offset});
  if(error)return {id:result.product_id,storageCleanupError:error.message};
  for(const object of objects||[])if(object.id)paths.add(`${productId}/${object.name}`);
  if(!objects||objects.length<1000)break;
  offset+=objects.length;
 }
 const files=[...paths];
 for(let index=0;index<files.length;index+=1000){
  const {error}=await storage.remove(files.slice(index,index+1000));
  if(error)return {id:result.product_id,storageCleanupError:error.message};
 }
 return {id:result.product_id,storageCleanupError:null};
}
export async function saveProduct(payload,files,onProgress){
 const uploaded=[];
 try {
  for(let i=0;i<files.length;i++){
   const {file,color}=files[i];
   if(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>5*1024*1024)throw new Error('Images must be JPEG, PNG or WebP, up to 5 MB.');
   const ext={'image/jpeg':'jpg','image/png':'png','image/webp':'webp'}[file.type];
   const path=`${payload.id}/${uuid()}.${ext}`;
   unwrap(await supabase.storage.from('product-images').upload(path,file,{contentType:file.type,upsert:false}));
   uploaded.push(path);
   payload.images.push({path,color:color||null,alt:payload.name,position:payload.images.length});
   onProgress?.(Math.round((i+1)/files.length*100));
  }
  // First edit of an imported demo ingests its bundled art using the signed-in
  // admin's normal Storage policies. The original save RPC still verifies media.
  for(const image of payload.images){
   const asset=demoImageUrl(image.path);
   if(!asset)continue;
   const {data:objects,error:listError}=await supabase.storage.from('product-images').list(payload.id,{search:'demo-catalog.png'});
   if(listError)throw listError;
   if(objects?.some(object=>object.name==='demo-catalog.png'))continue;
   const response=await fetch(asset);
   if(!response.ok)throw new Error('Demo photograph could not be loaded. Please upload a replacement.');
   const photo=await response.blob();
   unwrap(await supabase.storage.from('product-images').upload(image.path,photo,{contentType:'image/png',upsert:false}));
   uploaded.push(image.path);
  }
  return unwrap(await supabase.rpc('save_product',{payload}));
 } catch(e){
  // Do not delete on an ambiguous network response: the transaction may have committed.
  if(uploaded.length && e.code && !String(e.code).startsWith('08')){
   const cleanup=await supabase.storage.from('product-images').remove(uploaded);
   if(cleanup.error) console.warn('Upload cleanup requires retry',cleanup.error.message);
  }
  throw e;
 }
}

export async function createCategory({ id, name, slug, description = '', image_path = null, image_alt = '', display_order = 0, is_active = true, is_accessory = false }) {
  const category = { name, slug, description, image_path, image_alt, display_order, is_active, is_accessory };
  if (id) category.id = id;
  return unwrap(await supabase.from('categories').insert(category).select().single());
}
export async function updateCategory(id, values) {
  const writable={};
  for(const key of ['name','slug','description','image_path','image_alt','display_order','is_active','is_accessory']){
    if(Object.hasOwn(values,key))writable[key]=values[key];
  }
  return unwrap(await supabase.from('categories').update(writable).eq('id',id).select().single());
}
export async function updateCategoryImage(id, image_path, image_alt = '') {
  return unwrap(await supabase.from('categories').update({ image_path, image_alt }).eq('id', id).select().single());
}
export async function deleteCategory(id) {
  return unwrap(await supabase.from('categories').delete().eq('id', id));
}
