import {Link} from 'react-router-dom';
import {ArrowUpRight,Check,Truck} from 'lucide-react';
import {money} from '../../lib/supabase';

export default function ProductInfo({product,selectedVariant,children}){
  const category=product.categories;
  const available=Boolean(selectedVariant&&selectedVariant.stock>0);

  return <section className="product-info" aria-labelledby="product-title">
    <nav className="product-breadcrumbs" aria-label="Breadcrumb">
      <Link to="/">Home</Link><span aria-hidden="true">/</span><Link to={category?.slug?`${category.is_accessory?'/accessories':'/collections'}/${encodeURIComponent(category.slug)}`:'/shop'}>{category?.name||'Collection'}</Link><span aria-hidden="true">/</span><span aria-current="page">{product.name}</span>
    </nav>
    <p className="product-info__category">{category?.name||'Bella by RT · Collection'}</p>
    <h1 id="product-title">{product.name}</h1>
    <p className="product-info__price">{money(product.price_cents)}</p>
    <p className="product-info__description">{product.description}</p>
    <p className={`product-stock ${available?'product-stock--available':''}`} role="status">{available?<><Check size={15}/> In stock · Ready to ship</>:'Select a size to check availability'}</p>
    {children}
    <div className="product-shipping-note"><Truck size={17}/><p><strong>Complimentary shipping</strong><span>Complimentary delivery on all Bella by RT orders.</span></p><ArrowUpRight size={15}/></div>
  </section>;
}