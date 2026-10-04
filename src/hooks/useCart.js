import {useEffect,useRef} from 'react';
import {getCart,removeCartItem,updateCartItem} from '../services/cart';
import {useQuery} from './useQuery';

export function useCart(userId){
  const query=useQuery(()=>getCart(userId),[userId]);
  const source=useRef(Symbol('cart-hook')).current;
  useEffect(()=>{
    const refreshCart=event=>{if(event.detail?.source!==source)query.refresh();};
    window.addEventListener('maison:cart-changed',refreshCart);
    return()=>window.removeEventListener('maison:cart-changed',refreshCart);
  },[query.refresh,source]);
  return {
    ...query,
    items:query.data||[],
    setQuantity:async(variantId,quantity)=>{await updateCartItem(variantId,quantity,source);await query.refresh();},
    remove:async variantId=>{await removeCartItem(variantId,source);await query.refresh();},
  };
}