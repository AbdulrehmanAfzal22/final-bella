import {createClient} from '@supabase/supabase-js';
import {createInterface} from 'node:readline';
const lines=createInterface({input:process.stdin});
let fixture;for await(const line of lines){fixture=JSON.parse(line);break;}
const client=createClient('https://bpedttjsbmuvtyqehvnx.supabase.co','sb_publishable_Ir8Xg9bHikRel8GMsvpxKw_-xHved62',{auth:{persistSession:false,autoRefreshToken:false}});
const ok=({data,error})=>{if(error)throw error;return data;};
ok(await client.auth.signInWithPassword({email:'qa-'+fixture.admin+'@example.invalid',password:fixture.password}));
const products=ok(await client.from('products').select('id').eq('name','TEMPORARY QA — NOT FOR SALE'));
for(const {id} of products){
 const result=ok(await client.rpc('admin_delete_product',{p_product_id:id,p_cleanup_only:false}));
 if(result.storage_paths?.length)ok(await client.storage.from('product-images').remove(result.storage_paths));
}
const {data,error}=await client.functions.invoke('instagram-feed',{body:{action:'status'}});
if(error)throw error;
if(data.connected===true)throw new Error('QA expects unconnected Instagram account.');
const anon=createClient(client.supabaseUrl,'sb_publishable_Ir8Xg9bHikRel8GMsvpxKw_-xHved62',{auth:{persistSession:false,autoRefreshToken:false}});
if(!(await anon.functions.invoke('instagram-feed',{body:{action:'status'}})).error)throw new Error('Guest admin action allowed.');
await client.auth.signOut();
console.log(JSON.stringify({pass:true,cleaned:products.length,checks:['stale synthetic products and photos removed','Instagram admin status accessible','Instagram guest admin action denied']}));

process.stdin.unref?.();
