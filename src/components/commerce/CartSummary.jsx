import {LockKeyhole,ArrowRight} from 'lucide-react';
import {Link} from 'react-router-dom';
import {money} from '../../lib/supabase';

export default function CartSummary({subtotal,unavailable}){
  return <aside className="commerce-summary cart-order-summary" aria-labelledby="cart-summary-title">
    <p className="commerce-eyebrow">A considered choice</p>
    <h2 id="cart-summary-title">Order summary</h2>
    <dl className="commerce-summary__rows"><div><dt>Subtotal</dt><dd>{money(subtotal)}</dd></div><div><dt>Shipping</dt><dd className="commerce-summary__free">Complimentary</dd></div><div><dt>Discount</dt><dd>—</dd></div></dl>
    <div className="commerce-summary__total"><span>Total</span><strong>{money(subtotal)}</strong></div>
    {unavailable?<p className="commerce-summary__notice" role="alert">Update unavailable pieces before continuing to checkout.</p>:<Link className="commerce-primary-button" to="/checkout">Proceed to checkout <ArrowRight size={17}/></Link>}
    <p className="commerce-secure-note"><LockKeyhole size={14}/> Secure checkout · Your details are protected</p>
    <p className="commerce-summary__shipping-note">Complimentary shipping on every order.</p>
  </aside>;
}