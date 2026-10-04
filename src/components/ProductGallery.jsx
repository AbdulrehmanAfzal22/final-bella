import { useState } from "react";
import {useEffect,useRef} from 'react';
import {ChevronLeft,ChevronRight,Expand,X} from 'lucide-react';
import { imageUrl } from "../lib/supabase";

export default function ProductGallery({ images = [] }) {
  const [active, setActive] = useState(images[0]);
  const [zoomed,setZoomed]=useState(false);
  const touchStart=useRef(null);
  const zoomClose=useRef(null);
  const zoomTrigger=useRef(null);
  const current = images.find((i) => i.path === active?.path) || images[0];

  useEffect(()=>{
    if(!zoomed)return;
    zoomClose.current?.focus();
    const handleDialogKeys=event=>{
      if(event.key==='Escape'){event.preventDefault();setZoomed(false);return;}
      if(event.key==='Tab'){event.preventDefault();zoomClose.current?.focus();}
    };
    window.addEventListener('keydown',handleDialogKeys);
    return()=>{window.removeEventListener('keydown',handleDialogKeys);zoomTrigger.current?.focus();};
  },[zoomed]);

  function move(direction){
    const currentIndex=Math.max(0,images.findIndex(image=>image.path===current?.path));
    setActive(images[(currentIndex+direction+images.length)%images.length]);
  }

  function handleTouchStart(event){touchStart.current=event.touches[0]?.clientX??null;}
  function handleTouchEnd(event){
    if(touchStart.current===null)return;
    const distance=event.changedTouches[0].clientX-touchStart.current;
    if(Math.abs(distance)>45)move(distance<0?1:-1);
    touchStart.current=null;
  }

  if (!images.length) {
    return <div className="product-gallery"><span className="image-empty">Image unavailable</span></div>;
  }

  return (
    <div className="product-gallery product-gallery--premium">
      <div className="product-gallery-main" onTouchStart={handleTouchStart} onTouchEnd={handleTouchEnd}>
        <img key={current.path} src={imageUrl(current.path)} alt={current.alt || "Product photo"} decoding="async" fetchPriority="high"/>
        {images.length>1&&<><button type="button" className="product-gallery__arrow product-gallery__arrow--previous" onClick={()=>move(-1)} aria-label="Previous product image"><ChevronLeft size={19}/></button><button type="button" className="product-gallery__arrow product-gallery__arrow--next" onClick={()=>move(1)} aria-label="Next product image"><ChevronRight size={19}/></button></>}
        <button ref={zoomTrigger} type="button" className="product-gallery__zoom" onClick={()=>setZoomed(true)} aria-label="Open image zoom"><Expand size={16}/><span>View detail</span></button>
      </div>
      {images.length > 1 && (
        <div className="product-gallery-thumbs" aria-label="Product images">
          {images.map((image) => (
            <button
              key={image.id || image.path}
              className={image.path === current.path ? "active" : ""}
              type="button"
              aria-pressed={image.path === current.path}
              onClick={() => setActive(image)}
              aria-label={`Show photo ${image.alt || "product image"}`}
            >
              <img src={imageUrl(image.path)} alt="" width="72" loading="lazy" decoding="async" />
            </button>
          ))}
        </div>
      )}
      {zoomed&&<div className="product-gallery-zoom" role="dialog" aria-modal="true" aria-label="Product image detail" onClick={()=>setZoomed(false)}><button ref={zoomClose} type="button" className="product-gallery-zoom__close" onClick={()=>setZoomed(false)} aria-label="Close image zoom"><X size={21}/></button><img src={imageUrl(current.path)} alt={current.alt||'Product photo'} onClick={event=>event.stopPropagation()}/></div>}
    </div>
  );
}
