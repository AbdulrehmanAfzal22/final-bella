import { createClient } from '@supabase/supabase-js';
import {demoImageUrl} from './demoImages';
export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL || 'https://bpedttjsbmuvtyqehvnx.supabase.co',
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_Ir8Xg9bHikRel8GMsvpxKw_-xHved62',
  {auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true,storageKey:'bella-by-rt-auth'}}
);
export const imageUrl = path => path ? demoImageUrl(path)||supabase.storage.from('product-images').getPublicUrl(path).data.publicUrl : null;
export const categoryImageUrl = path => path ? supabase.storage.from('category-images').getPublicUrl(path).data.publicUrl : null;
export function unwrap({data,error}) { if(error) throw error; return data; }
export const money = cents => new Intl.NumberFormat('en-US',{style:'currency',currency:'USD'}).format((cents||0)/100);
