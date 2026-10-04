import {useEffect,useMemo,useRef,useState} from 'react';
import {ArrowUpRight,ChevronLeft,ChevronRight,Eye,Heart} from 'lucide-react';
import {Link,useNavigate} from 'react-router-dom';
import {toast} from 'sonner';
import {useAuth} from '../hooks/useAuth';
import {useWishlist} from '../hooks/useWishlist';
import {Empty,ErrorState,Loading} from './Feedback';
import {LuxuryQuickView} from './LuxuryProductCard';
import {imageUrl,money} from '../lib/supabase';

const AUTO_PLAY_MS = 3000;
const TRANSITION_MS = 860;

export default function ProductShowcase({products=[],loading=false,error,retry,className=''}){
  const {user}=useAuth();
  const wishlist=useWishlist(user?.id,{enabled:false});
  const navigate=useNavigate();
  const trackRef = useRef(null);
  const [quickView,setQuickView]=useState(null);
  const [saving,setSaving]=useState(null);
  const [isPaused,setIsPaused]=useState(false);
  const [activeIndex,setActiveIndex]=useState(0);
  const [dragStart,setDragStart]=useState(null);
  const [dragOffset,setDragOffset]=useState(0);
  const [cardWidth,setCardWidth]=useState(340);
  const reducedMotionRef = useRef(false);

  const slides=useMemo(()=>products.length?[...products,...products]:[],[products]);

  useEffect(()=>{
    if(typeof window === 'undefined') return;
    const media=window.matchMedia('(prefers-reduced-motion: reduce)');
    const sync=()=>{reducedMotionRef.current=media.matches;};
    sync();
    media.addEventListener?.('change',sync);
    return ()=>media.removeEventListener?.('change',sync);
  },[]);

  useEffect(()=>{
    if(!products.length || reducedMotionRef.current || isPaused || slides.length < 2) return;
    const timeout=window.setTimeout(()=>{
      setActiveIndex(prev => (prev + 1) % products.length);
    },AUTO_PLAY_MS);
    return ()=>window.clearTimeout(timeout);
  },[activeIndex,products.length,isPaused,slides.length]);

  useEffect(()=>{
    if(!trackRef.current) return;
    const track=trackRef.current;
    const firstCard=track.querySelector('.new-arrivals__card');
    if(!firstCard) return;
    const styles=window.getComputedStyle(track);
    const gap=parseFloat(styles.columnGap || styles.gap || '24');
    setCardWidth(firstCard.getBoundingClientRect().width + gap);

    const onResize=()=>{
      const card=track.querySelector('.new-arrivals__card');
      if(!card) return;
      const nextGap=parseFloat(window.getComputedStyle(track).columnGap || window.getComputedStyle(track).gap || '24');
      setCardWidth(card.getBoundingClientRect().width + nextGap);
    };

    window.addEventListener('resize',onResize);
    return ()=>window.removeEventListener('resize',onResize);
  },[products.length]);

  async function saveToWishlist(product){
    if(!user){navigate(`/login?returnTo=${encodeURIComponent(`/product/${product.id}`)}`);return;}
    setSaving(product.id);
    try{await wishlist.add(product.id);toast.success('Saved to your wishlist.');}
    catch(saveError){toast.error(saveError.message);}
    finally{setSaving(null);}
  }

  function pauseAutoplay(){
    if(reducedMotionRef.current) return;
    setIsPaused(true);
  }

  function resumeAutoplay(){
    if(reducedMotionRef.current) return;
    setIsPaused(false);
  }

  function moveTo(direction){
    if(!products.length) return;
    setIsPaused(true);
    setActiveIndex(prev => (prev + direction + products.length) % products.length);
    window.setTimeout(() => {
      if(!reducedMotionRef.current) setIsPaused(false);
    },AUTO_PLAY_MS);
  }

  function handlePointerDown(event){
    if(reducedMotionRef.current) return;
    setDragStart(event.clientX);
    setDragOffset(0);
    setIsPaused(true);
  }

  function handlePointerMove(event){
    if(dragStart===null) return;
    setDragOffset(event.clientX - dragStart);
  }

  function handlePointerEnd(){
    if(dragStart===null) return;
    const threshold=Math.min(cardWidth * 0.22, 100);
    if(dragOffset < -threshold){
      setActiveIndex(prev => (prev + 1) % products.length);
    } else if(dragOffset > threshold){
      setActiveIndex(prev => (prev - 1 + products.length) % products.length);
    }
    setDragStart(null);
    setDragOffset(0);
    window.setTimeout(()=>{
      if(!reducedMotionRef.current) setIsPaused(false);
    },AUTO_PLAY_MS);
  }

  const translateX = -((products.length + activeIndex) * cardWidth) + dragOffset;

  if(loading){
    return <section className={`luxury-products home-new-arrivals ${className}`.trim()} id="new-arrivals" aria-labelledby="new-arrivals-title"><Loading label="Curating the latest pieces…"/></section>;
  }

  if(error){
    return <section className={`luxury-products home-new-arrivals ${className}`.trim()} id="new-arrivals" aria-labelledby="new-arrivals-title"><ErrorState error={error} retry={retry}/></section>;
  }

  if(!products.length){
    return <section className={`luxury-products home-new-arrivals ${className}`.trim()} id="new-arrivals" aria-labelledby="new-arrivals-title"><Empty title="A new collection is on its way." text="Published pieces will appear here. Explore Bella by RT in the meantime." action={null}/></section>;
  }

  return <section className={`luxury-products home-new-arrivals ${className}`.trim()} id="new-arrivals" aria-labelledby="new-arrivals-title">
    <div className="luxury-products__heading">
      <div>
        <p className="eyebrow">The latest chapter <span>—</span> 01 / 06</p>
        <h2 id="new-arrivals-title">New arrivals</h2>
      </div>
      <div className="new-arrivals__controls" aria-label="New arrivals controls">
        <button type="button" className="new-arrivals__arrow" onClick={()=>moveTo(-1)} aria-label="Previous new arrivals"><ChevronLeft size={16}/></button>
        <button type="button" className="new-arrivals__arrow" onClick={()=>moveTo(1)} aria-label="Next new arrivals"><ChevronRight size={16}/></button>
      </div>
      <Link className="luxury-text-link" to="/shop">View the collection <ArrowUpRight size={17}/></Link>
    </div>

    <div className="new-arrivals__viewport" onMouseEnter={pauseAutoplay} onMouseLeave={resumeAutoplay} onPointerDown={handlePointerDown} onPointerMove={handlePointerMove} onPointerUp={handlePointerEnd} onPointerLeave={handlePointerEnd} onPointerCancel={handlePointerEnd}>
      <div ref={trackRef} className="new-arrivals__track" style={{transform:`translate3d(${translateX}px,0,0)`, transition: reducedMotionRef.current ? 'none' : `transform ${TRANSITION_MS}ms cubic-bezier(0.22, 1, 0.36, 1)`}}>
        {slides.map((product,index)=>{
          const images=[...(product.product_images||[])].sort((a,b)=>a.position-b.position);
          const primaryImage=images[0];
          const secondaryImage=images[1];
          const categoryName=product.categories?.name || 'The collection';
          return <article key={`${product.id}-${index}`} className="new-arrivals__card" aria-label={product.name}>
            <div className="new-arrivals__card-shell">
              <Link to={`/product/${product.id}`} className="new-arrivals__image-link" aria-label={`View ${product.name}`}>
                <div className="new-arrivals__image-wrap">
                  {primaryImage?<img className="new-arrivals__image" src={imageUrl(primaryImage.path)} alt={primaryImage.alt || product.name} loading="lazy" decoding="async"/>:<span className="image-empty">Image unavailable</span>}
                  {secondaryImage&&<img className="new-arrivals__image new-arrivals__image--secondary" src={imageUrl(secondaryImage.path)} alt={secondaryImage.alt || `${product.name} alternate view`} loading="lazy" decoding="async"/>}
                </div>
                <div className="new-arrivals__card-overlay" aria-hidden="true" />
                <div className="new-arrivals__card-copy">
                  <span className="new-arrivals__category">{categoryName}</span>
                  <h3>{product.name}</h3>
                  <span className="new-arrivals__explore">Explore <ArrowUpRight size={15}/></span>
                </div>
              </Link>
              <div className="new-arrivals__actions" aria-label={`${product.name} quick actions`}>
                <button type="button" onClick={()=>saveToWishlist(product)} aria-label={`Add ${product.name} to wishlist`} disabled={saving===product.id}><Heart size={16}/><span>{saving===product.id?'Saving…':'Save'}</span></button>
                <button type="button" onClick={()=>setQuickView(product)} aria-label={`Quick view ${product.name}`}><Eye size={16}/><span>Quick view</span></button>
              </div>
            </div>
            <div className="new-arrivals__price-row"><span>{money(product.price_cents)}</span></div>
          </article>;
        })}
      </div>
    </div>

    <LuxuryQuickView product={quickView} onClose={setQuickView}/>
  </section>;
}
