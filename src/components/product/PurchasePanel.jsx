import {useEffect,useState} from 'react';
import {Heart,Minus,Plus} from 'lucide-react';

export default function PurchasePanel({selectedVariant,onAddToCart,onWishlist,busy}){
  const [quantity,setQuantity]=useState(1);
  const maximum=Math.max(1,Math.min(selectedVariant?.stock||1,10));

  useEffect(()=>setQuantity(current=>Math.min(current,maximum)),[maximum]);

  function updateQuantity(next){setQuantity(Math.max(1,Math.min(maximum,next)));}

  return <div className="product-purchase">
    <div className="product-quantity" aria-label="Quantity">
      <button type="button" onClick={()=>updateQuantity(quantity-1)} disabled={quantity<=1} aria-label="Decrease quantity"><Minus size={15}/></button>
      <output aria-live="polite">{quantity}</output>
      <button type="button" onClick={()=>updateQuantity(quantity+1)} disabled={quantity>=maximum} aria-label="Increase quantity"><Plus size={15}/></button>
    </div>
    <button className="product-add-to-bag" type="button" onClick={()=>onAddToCart(quantity)} disabled={busy||!selectedVariant||selectedVariant.stock<1}>{busy?'Adding to bag':'Add to bag'}</button>
    <button className="product-save" type="button" onClick={onWishlist} aria-label="Add to wishlist"><Heart size={19}/></button>
  </div>;
}