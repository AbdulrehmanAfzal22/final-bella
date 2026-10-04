import {createClient} from '@supabase/supabase-js';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {createInterface} from 'node:readline';

let input = '';
for await (const line of createInterface({input:process.stdin})) { input=line; break; }
if (!input) throw new Error('Provide existing QA credentials as one JSON line on stdin. See START_HERE.md.');
const fixture=JSON.parse(input);
if (!fixture.admin || !fixture.customer || !fixture.password) throw new Error('admin, customer and password are required.');
const url='https://bpedttjsbmuvtyqehvnx.supabase.co',key='sb_publishable_Ir8Xg9bHikRel8GMsvpxKw_-xHved62';
const make=()=>createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
const admin=make(),customer=make(),anon=make();
const requireData=({data,error})=>{if(error)throw error;return data;};
const id=crypto.randomUUID(),path=id+'/'+crypto.randomUUID()+'.png';
let uploaded=false,created=false;
try {
  for(const [client,qaId] of [[admin,fixture.admin],[customer,fixture.customer]]) {
    requireData(await client.auth.signInWithPassword({email:'qa-'+qaId+'@example.invalid',password:fixture.password}));
  }
  assert.equal(requireData(await admin.rpc('is_admin')),true);
  assert.equal(requireData(await customer.rpc('is_admin')),false);
  const image=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jZekAAAAASUVORK5CYII=','base64');
  assert.ok((await customer.storage.from('product-images').upload(path,image,{contentType:'image/png'})).error,'Customer upload must be rejected');
  requireData(await admin.storage.from('product-images').upload(path,image,{contentType:'image/png'})); uploaded=true;
  const payload={id,name:'TEMPORARY QA — NOT FOR SALE',description:'Disposable integration fixture',price_cents:12500,status:'published',featured:false,variants:[{id:crypto.randomUUID(),color:'Ink',color_hex:'#222222',size:'M',stock:2}],images:[{path,position:0,alt:'QA fixture'}]};
  assert.ok((await customer.rpc('save_product',{payload})).error,'Customer product creation must fail');
  // Attempt cleanup by this unique ID even if the save response is ambiguous.
  created=true; requireData(await admin.rpc('save_product',{payload}));
  const read=requireData(await anon.from('products').select('*,product_images(*),product_variants(*)').eq('id',id).single());
  assert.equal(read.product_variants[0].stock,2);assert.equal(read.product_images[0].path,path);assert.equal(read.price_cents,12500);
  const fresh=make();
  assert.equal(requireData(await fresh.from('products').select('id').eq('id',id).single()).id,id);
  const attack=await customer.from('products').update({price_cents:1}).eq('id',id).select();
  assert.equal(attack.data?.length||0,0);
  assert.equal(requireData(await anon.from('products').select('price_cents').eq('id',id).single()).price_cents,12500);
  assert.equal((await fetch(url+'/storage/v1/object/public/product-images/'+path)).status,200);
  payload.status='draft';requireData(await admin.rpc('save_product',{payload}));
  assert.equal(requireData(await fresh.from('products').select('id').eq('id',id)).length,0);
  const categorySpecs=[['Lip Gloss','lip-gloss',false,'bella-beauty-editorial.png'],['Lip Oils','lip-oils',false,'bella-lip-oil.png'],['Lip & Cheek Tints','lip-cheek-tints',false,'bella-tint.png'],['Lip Balms','lip-balms',false,'bella-balm.png'],['Beauty Essentials','beauty-essentials',true,'bella-balm.png']];
  if(fixture.seedCategories){
    for(const [name,slug,is_accessory,asset] of categorySpecs){
      const category=requireData(await admin.from('categories').upsert({name,slug,is_accessory,is_active:true,display_order:categorySpecs.findIndex(c=>c[1]===slug)},{onConflict:'slug'}).select('id').single());
      const imagePath=category.id+'/'+asset;
      const denied=await customer.storage.from('category-images').upload(imagePath,readFileSync('public/assets/'+asset),{contentType:'image/png',upsert:true});
      assert.ok(denied.error);
      requireData(await admin.storage.from('category-images').upload(imagePath,readFileSync('public/assets/'+asset),{contentType:'image/png',upsert:true}));
      requireData(await admin.from('categories').update({image_path:imagePath,image_alt:name+' — decorative beauty imagery'}).eq('id',category.id));
      assert.equal((await fetch(url+'/storage/v1/object/public/category-images/'+imagePath)).status,200);
    }
  }
  console.log(JSON.stringify({pass:true,checks:['QA admin and customer password login','role separation','customer upload and save denied','admin upload and save','public product/variant/image read','fresh-client persistence','price tampering denied','public image retrieval','draft hidden','admin permanent deletion and storage cleanup','category upload roles and category image persistence']}));
} finally {
  const cleanup=[];
  if(created) {
    const result=await admin.rpc('admin_delete_product',{p_product_id:id,p_cleanup_only:false});
    if(result.error) cleanup.push('Product '+id+': '+result.error.message);
  }
  if(uploaded && !cleanup.length) {
    const result=await admin.storage.from('product-images').remove([path]);
    if(result.error)cleanup.push('Image '+path+': '+result.error.message);
  }
  await admin.auth.signOut();await customer.auth.signOut();
  if(cleanup.length) throw new Error('QA cleanup needs attention: '+cleanup.join('; '));
}

process.stdin.unref?.();
