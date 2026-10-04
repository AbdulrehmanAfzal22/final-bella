import {Heart,Search,ShoppingBag,UserRound} from 'lucide-react';
import {Link} from 'react-router-dom';
import {useAuth} from '../hooks/useAuth';
import {useCart} from '../hooks/useCart';

export default function HeaderActions(){
  const {user}=useAuth();
  const cart=useCart(user?.id);
  const itemCount=cart.items.reduce((total,item)=>total+(Number(item.quantity)||0),0);
  const bagLabel=itemCount?`Shopping bag, ${itemCount} ${itemCount===1?'item':'items'}`:'Shopping bag';

  return <nav className="luxury-header__actions" aria-label="Account and shopping tools">
    <Link className="luxury-header__action luxury-header__action--search" to="/search" aria-label="Search the collection" title="Search"><Search size={19} strokeWidth={1.55}/><span className="luxury-header__action-label">Search</span></Link>
    <Link className="luxury-header__action luxury-header__action--account" to={user?'/account':'/login'} aria-label={user?'My account':'Sign in'} title={user?'My account':'Sign in'}><UserRound size={19} strokeWidth={1.55}/><span className="luxury-header__action-label">Account</span></Link>
    <Link className="luxury-header__action luxury-header__action--wishlist" to="/wishlist" aria-label="Wishlist" title="Wishlist"><Heart size={19} strokeWidth={1.55}/><span className="luxury-header__action-label">Wishlist</span></Link>
    <Link className="luxury-header__action luxury-header__action--bag" to="/cart" aria-label={bagLabel} title={bagLabel}>
      <span className="luxury-header__bag-icon"><ShoppingBag size={19} strokeWidth={1.55}/>{itemCount>0&&<span className="luxury-header__bag-count" aria-hidden="true">{itemCount>99?'99+':itemCount}</span>}</span>
      <span className="luxury-header__action-label">Bag</span>
    </Link>
  </nav>;
}