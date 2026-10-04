import {money,imageUrl} from '../../lib/supabase';
import {galleryImages} from '../../lib/productOptions';
import QuantityEditor from '../QuantityEditor';

export default function CartItem({item,onQuantityChange,onRemove}){
  const variant=item.product_variants;
  const product=variant?.products;
  const image=galleryImages(product?.product_images,variant?.color)[0];
  return <div className="cart-item">
    {image&&<img src={imageUrl(image.path)} alt={product.name} width="90"/>}
    <div>
      <h3>{product?.name||'This piece is no longer available'}</h3>
      <p className="muted">{variant?.color} · {variant?.size}</p>
      {product&&<p>{money(product.price_cents)}</p>}
      {variant&&variant.stock<item.quantity&&<p className="error">Only {variant.stock} available</p>}
    </div>
    <QuantityEditor value={item.quantity} min={1} max={Math.min(99,variant?.stock||1)} label={'Quantity for '+(product?.name||'unavailable piece')} disabled={!product||!variant?.stock} onSave={value=>onQuantityChange(item.variant_id,value)}/>
    <button className="text-button" type="button" onClick={()=>onRemove(item.variant_id)}>Remove</button>
  </div>;
}