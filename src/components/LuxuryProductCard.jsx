import {useState} from 'react';
import {ArrowUpRight,Eye,Heart,X} from 'lucide-react';
import {Link,useNavigate} from 'react-router-dom';
import {toast} from 'sonner';
import {useAuth} from '../hooks/useAuth';
import {useWishlist} from '../hooks/useWishlist';
import Modal from './common/Modal';
import {imageUrl,money} from '../lib/supabase';

export default function LuxuryProductCard({product,onQuickView,onWishlist,saving=false}){
  const images=[...(product.product_images||[])].sort((a,b)=>a.position-b.position);
  const image=images[0];
  const alternateImage=images[1];
  const colors=[...new Map((product.product_variants||[]).filter(variant=>variant.active).map(variant=>[variant.color,variant])).values()];
  return <article className="luxury-product-card">
    <div className="luxury-product-card__visual">
      <Link to={`/product/${product.id}`} className="luxury-product-card__image-link" aria-label={`View ${product.name}`}>
        {image?<><img className="luxury-product-card__image" src={imageUrl(image.path)} alt={image.alt||product.name} loading="lazy" decoding="async"/>{alternateImage&&<img className="luxury-product-card__image luxury-product-card__image--alternate" src={imageUrl(alternateImage.path)} alt={alternateImage.alt||`${product.name}, alternate view`} loading="lazy" decoding="async"/>}</>:<span className="image-empty">Image unavailable</span>}
      </Link>
      <div className="luxury-product-card__actions" aria-label={`${product.name} quick actions`}>
        <button type="button" onClick={()=>onWishlist(product)} aria-label={`Add ${product.name} to wishlist`} disabled={saving}><Heart size={17}/><span>{saving?'Saving…':'Save'}</span></button>
        <button type="button" onClick={()=>onQuickView(product)} aria-label={`Quick view ${product.name}`}><Eye size={17}/><span>Quick view</span></button>
      </div>
    </div>
    <div className="luxury-product-card__details">
      <div className="luxury-product-card__name"><Link to={`/product/${product.id}`}>{product.name}</Link><span>{money(product.price_cents)}</span></div>
      <p>{product.categories?.name||'The collection'}</p>
      {colors.length>0&&<div className="luxury-product-card__swatches" aria-label={`Available colours: ${colors.map(color=>color.color).join(', ')}`}>{colors.map(color=><span key={color.id||color.color} title={color.color} aria-label={color.color} style={{backgroundColor:color.color_hex||'#d8d2c9'}}/>)}</div>}
    </div>
  </article>;
}

export function LuxuryQuickView({product,onClose}){
  const navigate=useNavigate();
  const {user}=useAuth();
  const wishlist=useWishlist(user?.id,{enabled:false});
  const [saving,setSaving]=useState(false);
  const image=[...(product?.product_images||[])].sort((a,b)=>a.position-b.position)[0];

  async function saveToWishlist(){
    if(!user){navigate(`/login?returnTo=${encodeURIComponent(`/product/${product.id}`)}`);onClose();return;}
    setSaving(true);
    try{await wishlist.add(product.id);toast.success('Saved to your wishlist.');}
    catch(error){toast.error(error.message);}
    finally{setSaving(false);}
  }

  if(!product)return null;
  return <Modal open={Boolean(product)} onClose={()=>onClose(null)} className="quick-view" labelledBy="quick-view-title">
    <button className="quick-view__close" type="button" onClick={()=>onClose(null)} aria-label="Close quick view"><X size={20}/></button>
    <div className="quick-view__image">{image?<img src={imageUrl(image.path)} alt={image.alt||product.name}/>:<span className="image-empty">Image unavailable</span>}</div>
    <div className="quick-view__content"><p className="eyebrow">{product.categories?.name||'Bella by RT'}</p><h2 id="quick-view-title">{product.name}</h2><p className="quick-view__price">{money(product.price_cents)}</p><p>{product.description}</p><button type="button" className="luxury-outline-button luxury-outline-button--dark" onClick={saveToWishlist} disabled={saving}><Heart size={16}/>{saving?'Saving…':'Save to wishlist'}</button><Link className="luxury-text-link" to={`/product/${product.id}`} onClick={()=>onClose(null)}>Discover this piece <ArrowUpRight size={17}/></Link></div>
  </Modal>;
}