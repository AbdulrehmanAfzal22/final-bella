import {Check,PackageCheck} from 'lucide-react';
import {Link} from 'react-router-dom';
import {money,imageUrl} from '../../lib/supabase';

export default function OrderConfirmation({order}){
  return <div className="commerce-confirmation">
    <header className="commerce-confirmation__header"><span className="commerce-confirmation__mark"><Check size={25}/></span><p className="commerce-eyebrow">Bella by RT · Order received</p><h1>Order confirmed</h1><p>Your collection is being prepared with care.</p><div className="commerce-confirmation__number"><span>Order number</span><strong>#{order.order_number}</strong></div></header>
    <section className="commerce-confirmation__body" aria-label="Order details">
      <div className="commerce-confirmation__items"><div className="commerce-confirmation__section-title"><PackageCheck size={18}/><h2>Order summary</h2></div>{order.order_items?.map(item=><article className="checkout-order-item" key={item.id}>{item.image_path&&<img src={imageUrl(item.image_path)} alt={item.product_name} width="64" loading="lazy"/>}<div><strong>{item.product_name}</strong><span>{item.color} · {item.size} · Qty {item.quantity}</span></div><b>{money(item.unit_price_cents*item.quantity)}</b></article>)}</div>
      <aside className="commerce-confirmation__totals"><p className="commerce-eyebrow">A few details</p><p className="commerce-confirmation__status">Status <strong>{order.status}</strong></p><p className="commerce-confirmation__status">Payment <strong>{order.payment_status} · Cash on delivery</strong></p><dl className="commerce-summary__rows"><div><dt>Subtotal</dt><dd>{money(order.subtotal_cents)}</dd></div><div><dt>Shipping</dt><dd>{money(order.shipping_cents)}</dd></div></dl><div className="commerce-summary__total"><span>Total</span><strong>{money(order.total_cents)}</strong></div></aside>
    </section>
    <nav className="commerce-confirmation__actions" aria-label="After your order"><Link className="commerce-primary-button" to="/shop">Continue shopping</Link><Link to="/orders">View all orders</Link><Link to="/contact-support">Get help with this order</Link></nav>
    <section className="commerce-confirmation__updates"><p className="commerce-eyebrow">Order updates</p><ol className="order-history">{[...(order.order_status_history||[])].sort((a,b)=>new Date(a.created_at)-new Date(b.created_at)).map(entry=><li key={entry.id}><strong>{entry.status}</strong><time dateTime={entry.created_at}>{new Date(entry.created_at).toLocaleString()}</time></li>)}</ol></section>
  </div>;
}