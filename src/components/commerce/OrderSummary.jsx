import {LockKeyhole,ShieldCheck} from 'lucide-react';
import {Link} from 'react-router-dom';
import {money,imageUrl} from '../../lib/supabase';
import {galleryImages} from '../../lib/productOptions';

export default function OrderSummary({items=[],subtotal,shipping=0,unavailable=false,busy=false,formId}){
  return <aside className="commerce-summary checkout-order-summary" id="order-summary" aria-labelledby="checkout-summary-title">
    <div className="checkout-order-summary__top"><p className="commerce-eyebrow">The final edit</p><h2 id="checkout-summary-title">Your order</h2><span>{items.length} {items.length===1?'piece':'pieces'}</span></div>
    <div className="checkout-order-summary__items">{items.map(item=>{
      const variant=item.product_variants;
      const product=variant?.products;
      const image=galleryImages(product?.product_images,variant?.color)[0];
      const lineTotal=(product?.price_cents||0)*item.quantity;
      return <article className="checkout-order-item" key={item.variant_id}>{image&&<img src={imageUrl(image.path)} alt={image.alt||product?.name||'Product image'} width="56" loading="lazy"/>}<div><strong>{product?.name||'Unavailable piece'}</strong><span>{variant?.color} · {variant?.size} · Qty {item.quantity}</span></div><b>{money(lineTotal)}</b></article>;
    })}</div>
    <dl className="commerce-summary__rows"><div><dt>Subtotal</dt><dd>{money(subtotal)}</dd></div><div><dt>Shipping</dt><dd className="commerce-summary__free">{shipping===0?'Complimentary':money(shipping)}</dd></div></dl>
    <div className="commerce-summary__total"><span>Total due on delivery</span><strong>{money(subtotal+shipping)}</strong></div>
    <div className="checkout-payment-note" id="delivery"><ShieldCheck size={18}/><div><strong>Complimentary home delivery</strong><span>Cash on delivery · Pay when your order arrives</span></div></div>
    {unavailable?<p className="commerce-summary__notice" role="alert">Some pieces are unavailable. <Link to="/cart">Update your collection</Link> before placing the order.</p>:<button className="commerce-primary-button" type="submit" form={formId} disabled={busy}>{busy?'Confirming your order…':`Place order · ${money(subtotal+shipping)}`}</button>}
    <p className="commerce-secure-note"><LockKeyhole size={14}/> Your information is protected</p>
  </aside>;
}