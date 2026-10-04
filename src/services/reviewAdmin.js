import { supabase, unwrap } from '../lib/supabase';
export const getAdminReviews = async () => unwrap(await supabase.from('reviews').select('*,products(name)').order('created_at', { ascending: false }));
export const approveReview = async (id, approved) => unwrap(await supabase.from('reviews').update({ approved }).eq('id', id).select('id').single());
export const deleteReview = async id => unwrap(await supabase.from('reviews').delete().eq('id', id));
