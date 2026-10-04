import {Link} from 'react-router-dom';
import {X} from 'lucide-react';
import {money,imageUrl} from '../../lib/supabase';
import {galleryImages} from '../../lib/productOptions';
import QuantityEditor from '../QuantityEditor';

export default function LuxuryCartItem({item,onQuantityChange,onRemove}){
  const variant=item.product_variants;
  const product=variant?.products;
  const image=galleryImages(product?.product_images,variant?.color)[0];
  const unavailable=!product||!variant?.active||variant.stock<item.quantity;

  return <article className="luxury-cart-item">
    <Link className="luxury-cart-item__image" to={product?`/product/${product.id}`:'/shop'} aria-label={`View ${product?.name||'available collection'}`}>
      {image?<img src={imageUrl(image.path)} alt={image.alt||product?.name||'Product image'} width="132" loading="lazy" decoding="async"/>:<span className="image-empty">Image unavailable</span>}
    </Link>
    <div className="luxury-cart-item__details">
      <div className="luxury-cart-item__heading"><div><p className="commerce-eyebrow">{product?.categories?.name||'Bella by RT'}</p><h2>{product?<Link to={`/product/${product.id}`}>{product.name}</Link>:'This piece is no longer available'}</h2></div><button className="luxury-cart-item__remove" type="button" onClick={()=>onRemove(item.variant_id)} aria-label={`Remove ${product?.name||'unavailable piece'} from your collection`}><X size={17}/><span>Remove</span></button></div>
      <p className="luxury-cart-item__variant">{variant?.color||'Colour unavailable'} <span aria-hidden="true">·</span> Size {variant?.size||'—'}</p>
      {variant&&variant.stock<item.quantity&&<p className="luxury-cart-item__stock" role="status">Only {variant.stock} available. Update the quantity to continue.</p>}
      {!variant?.active&&<p className="luxury-cart-item__stock" role="status">This piece is no longer available.</p>}
      <div className="luxury-cart-item__footer"><QuantityEditor value={item.quantity} min={1} max={Math.min(99,variant?.stock||1)} label={`Quantity for ${product?.name||'unavailable piece'}`} onSave={quantity=>onQuantityChange(item.variant_id,quantity)} disabled={!product||!variant?.active||!variant?.stock}/>{product&&<p className="luxury-cart-item__price">{money(product.price_cents)} <span>each</span></p>}</div>
    </div>
  </article>;
}