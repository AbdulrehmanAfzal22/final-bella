import {useState} from 'react';
import {useNavigate} from 'react-router-dom';
import {toast} from 'sonner';
import {useAuth} from '../../hooks/useAuth';
import {useWishlist} from '../../hooks/useWishlist';
import LuxuryProductCard,{LuxuryQuickView} from '../LuxuryProductCard';

export default function LuxuryProductGrid({products=[],loading=false,emptyTitle='No pieces found',emptyDescription='Try another selection.',onClear,hasMore=false,onLoadMore}){
  const {user}=useAuth();
  const wishlist=useWishlist(user?.id,{enabled:false});
  const navigate=useNavigate();
  const [quickView,setQuickView]=useState(null);
  const [saving,setSaving]=useState(null);

  async function saveToWishlist(product){
    if(!user){navigate(`/login?returnTo=${encodeURIComponent(`/product/${product.id}`)}`);return;}
    setSaving(product.id);
    try{await wishlist.add(product.id);toast.success('Saved to your wishlist.');}
    catch(error){toast.error(error.message);}
    finally{setSaving(null);}
  }

  if(loading)return <div className="shop-product-grid shop-product-grid--loading" role="status" aria-label="Loading collection" aria-busy="true">{Array.from({length:8},(_,index)=><div className="shop-skeleton-card" key={index} aria-hidden="true"><div className="shop-skeleton-card__image"/><div className="shop-skeleton-card__line shop-skeleton-card__line--name"/><div className="shop-skeleton-card__line shop-skeleton-card__line--meta"/></div>)}</div>;

  if(!products.length)return <div className="shop-empty" role="status"><p className="shop-eyebrow">Bella by RT · The collection</p><h2>{emptyTitle}</h2><p>{emptyDescription}</p>{onClear&&<button type="button" onClick={onClear}>Clear selection</button>}</div>;

  return <>
    <div className="shop-product-grid">{products.map((product,index)=><div key={product.id} className="shop-product-grid__item" style={{'--shop-item-index':index%8}}><LuxuryProductCard product={product} onWishlist={saveToWishlist} onQuickView={setQuickView} saving={saving===product.id}/></div>)}</div>
    {hasMore&&<div className="shop-load-more"><button type="button" onClick={onLoadMore}>Discover more pieces</button></div>}
    <LuxuryQuickView product={quickView} onClose={setQuickView}/>
  </>;
}