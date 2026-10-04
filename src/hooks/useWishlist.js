import {addToWishlist,getWishlist,removeFromWishlist} from '../services/wishlist';
import {useQuery} from './useQuery';

export function useWishlist(userId,{enabled=true}={}){
  const query=useQuery(()=>enabled&&userId?getWishlist(userId):[],[userId,enabled]);
  return {
    ...query,
    items:query.data||[],
    add:async productId=>{if(!userId)throw new Error('Sign in to save pieces.');await addToWishlist(userId,productId);if(enabled)await query.refresh();},
    remove:async productId=>{if(!userId)throw new Error('Sign in to manage your wishlist.');await removeFromWishlist(userId,productId);await query.refresh();},
  };
}