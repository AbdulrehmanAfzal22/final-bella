import {useEffect,useMemo,useRef,useState} from 'react';
import {useReducedMotion} from 'framer-motion';
import {ArrowDown,ArrowLeft,ArrowRight,ArrowUpRight,Heart,Images,Instagram,MessageCircle,ShoppingBag} from 'lucide-react';
import {Link} from 'react-router-dom';
import {useQuery} from '../hooks/useQuery';
import {getInstagramFeed,getMoreInstagramReels} from '../services/instagramReels';

const ACCOUNT_URL='https://www.instagram.com/bellabyrt/';

function visibleCount(width,settings){
  if(width<600)return Number(settings?.mobile_cards)||1.2;
  if(width<800)return 2;
  if(width<1100)return 3;
  if(width<1280)return 4;
  return Number(settings?.desktop_cards)||5;
}

function shopDestination(reel){
  return reel.shop_url|| (reel.product_id?`/product/${reel.product_id}`:null);
}

function ReelCard({reel}){
  const destination=shopDestination(reel);
  const external=/^https?:\/\//i.test(destination);
  const isReel=reel.media_type==='VIDEO';
  const thumbnailUrl=reel.thumbnail_url||reel.media_url;
  const videoRef=useRef(null);
  const [isVisible,setIsVisible]=useState(false);

  useEffect(()=>{
    const video=videoRef.current;
    if(!isReel||!video)return undefined;
    const observer=new IntersectionObserver(entries=>{
      for(const entry of entries){
        const visible=entry.isIntersecting&&entry.intersectionRatio>0;
        setIsVisible(visible);
        if(visible)video.play().catch(()=>{});
        else video.pause();
      }
    },{threshold:0});
    observer.observe(video);
    return()=>observer.disconnect();
  },[isReel]);

  return <article className="reels-showcase__card">
    <a className="reels-showcase__preview" href={reel.instagram_url} target="_blank" rel="noreferrer" aria-label={isReel?`Watch ${reel.category||'Instagram Reel'} on Instagram`:'View Instagram post on Instagram'}>
      {isReel&&reel.media_url?<video ref={videoRef} className="reels-showcase__thumbnail" src={reel.media_url} poster={reel.thumbnail_url||undefined} autoPlay={isVisible} muted loop playsInline preload="metadata" aria-label="Instagram Reel"/>:thumbnailUrl&&<img className="reels-showcase__thumbnail" src={thumbnailUrl} alt={reel.category?`${reel.category} Instagram preview`:'Instagram post preview'} loading="lazy" decoding="async"/>}
      <span className="reels-showcase__wash" aria-hidden="true"/>
      <span className="reels-showcase__profile">
        {reel.profile_image?<img src={reel.profile_image} alt="" loading="lazy" decoding="async"/>:<span className="reels-showcase__profile-monogram" aria-hidden="true"><Instagram size={15}/></span>}
        <span><strong>@{reel.username||'bellabyrt'}</strong>{(reel.category||reel.caption)&&<small>{reel.category||reel.caption}</small>}</span>
      </span>
      {reel.media_type==='CAROUSEL_ALBUM'&&<span className="reels-showcase__carousel" aria-label="Carousel post"><Images size={17}/></span>}
      {reel.view_count!==null&&reel.view_count!==undefined&&<span className="reels-showcase__views">{Number(reel.view_count).toLocaleString()} views</span>}
      <span className="reels-showcase__open" aria-hidden="true"><Instagram size={17}/></span>
    </a>
    <div className="reels-showcase__actions">
      <span className="reels-showcase__social-icons" aria-label={[reel.like_count!==null&&reel.like_count!==undefined?`${Number(reel.like_count).toLocaleString()} likes`:null,reel.comment_count!==null&&reel.comment_count!==undefined?`${Number(reel.comment_count).toLocaleString()} comments`:null].filter(Boolean).join(', ')||'Instagram Reel'}>
        {reel.like_count!==null&&reel.like_count!==undefined&&<span><Heart size={15}/>{Number(reel.like_count).toLocaleString()}</span>}
        {reel.comment_count!==null&&reel.comment_count!==undefined&&<span><MessageCircle size={15}/>{Number(reel.comment_count).toLocaleString()}</span>}
        {reel.like_count==null&&reel.comment_count==null&&<Instagram size={17} aria-hidden="true"/>}
      </span>
      <a className="reels-showcase__view-reel" href={reel.instagram_url} target="_blank" rel="noreferrer">{isReel?'Watch Reel':'View Post'} <Instagram size={14}/></a>
      {destination&&(external?<a className="reels-showcase__shop" href={destination} target="_blank" rel="noreferrer">Shop now <ShoppingBag size={14}/></a>:<Link className="reels-showcase__shop" to={destination}>Shop now <ShoppingBag size={14}/></Link>)}
    </div>
  </article>;
}

export default function InstagramReelsShowcase(){
  const query=useQuery(getInstagramFeed,[]);
  const reducedMotion=useReducedMotion();
  const viewportRef=useRef(null);
  const trackRef=useRef(null);
  const pointerRef=useRef(null);
  const suppressClick=useRef(false);
  const [position,setPosition]=useState(0);
  const [stride,setStride]=useState(1);
  const [cardsVisible,setCardsVisible]=useState(()=>typeof window==='undefined'?5:visibleCount(window.innerWidth,null));
  const [dragOffset,setDragOffset]=useState(0);
  const [dragging,setDragging]=useState(false);
  const [snapReset,setSnapReset]=useState(false);
  const [paused,setPaused]=useState(false);
  const [loadingMore,setLoadingMore]=useState(false);
  const feed=query.data;
  const reels=(feed?.reels||[]).filter(reel=>reel.thumbnail_url&&/^https:\/\/(?:www\.)?instagram\.com\//i.test(reel.instagram_url||''));
  const reelCount=reels.length;
  const carouselReels=useMemo(()=>reelCount>cardsVisible?[...reels,...reels,...reels]:reels,[reels,reelCount,cardsVisible]);
  const canMove=reelCount>cardsVisible&&!reducedMotion&&feed?.settings?.autoplay_enabled!==false;

  useEffect(()=>{
    if(query.error)console.error('[Instagram Reels] Feed request failed:',query.error);
  },[query.error]);

  useEffect(()=>{
    setPosition(reelCount>cardsVisible?reelCount:0);
    setDragOffset(0);
  },[reelCount,cardsVisible]);

  useEffect(()=>{
    const viewport=viewportRef.current;
    const track=trackRef.current;
    if(!viewport||!track)return undefined;
    const measure=()=>{
      setCardsVisible(visibleCount(window.innerWidth,feed?.settings));
      viewport.style.setProperty('--reels-viewport-width',`${viewport.clientWidth}px`);
      const card=track.querySelector('.reels-showcase__card');
      const gap=parseFloat(getComputedStyle(track).columnGap)||0;
      if(card)setStride(card.getBoundingClientRect().width+gap);
    };
    measure();
    const observer=new ResizeObserver(measure);
    observer.observe(viewport);
    observer.observe(track);
    window.addEventListener('resize',measure);
    return()=>{observer.disconnect();window.removeEventListener('resize',measure);};
  },[reelCount,cardsVisible,feed?.settings?.desktop_cards,feed?.settings?.mobile_cards]);

  useEffect(()=>{
    if(!canMove||paused||dragging)return undefined;
    const interval=Math.max(3,Number(feed?.settings?.autoplay_interval_seconds)||3)*1000;
    const timer=window.setInterval(()=>setPosition(current=>current+1),interval);
    return()=>window.clearInterval(timer);
  },[canMove,paused,dragging,feed?.settings?.autoplay_interval_seconds]);

  function step(direction){
    if(!reelCount)return;
    setPosition(current=>{
      if(reelCount<=cardsVisible)return current;
      if(direction>0&&current>=reelCount*2-1)return reelCount*2;
      if(direction<0&&current<=reelCount)return current-1;
      return current+direction;
    });
  }

  function onTrackTransitionEnd(event){
    if(event.target!==trackRef.current||reelCount<=cardsVisible)return;
    const resetTo=position>=reelCount*2?reelCount:position<reelCount?reelCount*2-1:null;
    if(resetTo!==null){
      setSnapReset(true);
      setPosition(resetTo);
      requestAnimationFrame(()=>requestAnimationFrame(()=>setSnapReset(false)));
    }
  }

  function pointerDown(event){
    if(event.pointerType==='mouse'&&event.button!==0)return;
    pointerRef.current={id:event.pointerId,startX:event.clientX,moved:false,pointerType:event.pointerType};
    setDragging(true);
    setPaused(true);
    event.currentTarget.setPointerCapture(event.pointerId);
  }

  function pointerMove(event){
    const pointer=pointerRef.current;
    if(!pointer||pointer.id!==event.pointerId)return;
    const delta=event.clientX-pointer.startX;
    if(Math.abs(delta)>5)pointer.moved=true;
    setDragOffset(delta);
  }

  function pointerUp(event){
    const pointer=pointerRef.current;
    if(!pointer||pointer.id!==event.pointerId)return;
    const delta=event.clientX-pointer.startX;
    if(pointer.moved){
      suppressClick.current=true;
      window.setTimeout(()=>{suppressClick.current=false;},0);
      if(Math.abs(delta)>35)step(delta<0?1:-1);
    }
    pointerRef.current=null;
    setDragOffset(0);
    setDragging(false);
    setPaused(pointer.pointerType==='mouse');
  }

  function preventDraggedClick(event){
    if(!suppressClick.current)return;
    event.preventDefault();
    event.stopPropagation();
    suppressClick.current=false;
  }

  function onKeyDown(event){
    if(event.key==='ArrowLeft'||event.key==='ArrowRight'){
      event.preventDefault();
      step(event.key==='ArrowRight'?1:-1);
    }
  }

  async function loadOlder(){
    if(feed?.nextOffset===null||feed?.nextOffset===undefined||loadingMore)return;
    setLoadingMore(true);
    try{
      const page=await getMoreInstagramReels(feed.nextOffset);
      query.setData(current=>current?{...current,reels:[...current.reels,...page.reels],nextOffset:page.nextOffset}:current);
    }catch{
      setPaused(true);
    }finally{setLoadingMore(false);}
  }

  return <section className="reels-showcase" aria-labelledby="reels-showcase-title" onMouseEnter={()=>setPaused(true)} onMouseLeave={()=>setPaused(false)}>
    <div className="reels-showcase__inner">
      <header className="reels-showcase__heading">
        <div className="reels-showcase__heading-copy"><p className="eyebrow"><Instagram size={13}/> From the community</p><h2 id="reels-showcase-title">Worn &amp; Loved <span aria-hidden="true">♥</span></h2><p>Discover the latest looks, moments and styling inspiration from @bellabyrt.</p></div>
        <div className="reels-showcase__heading-actions"><a className="reels-showcase__instagram-link" href={feed?.settings?.profile_url||ACCOUNT_URL} target="_blank" rel="noreferrer">View Instagram <ArrowUpRight size={14}/></a>{reelCount>cardsVisible&&<div className="reels-showcase__controls"><button type="button" onClick={()=>step(-1)} aria-label="Previous Instagram posts"><ArrowLeft size={17}/></button><button type="button" onClick={()=>step(1)} aria-label="Next Instagram posts"><ArrowRight size={17}/></button></div>}</div>
      </header>
      {query.loading&&!feed?<div className="reels-showcase__loading" role="status" aria-label="Loading Instagram Reels"><span/><span/><span/><span/><span/></div>:query.error&&!reelCount?<div className="reels-showcase__error" role="alert"><strong>Instagram Reels are temporarily unavailable.</strong><a href={ACCOUNT_URL} target="_blank" rel="noreferrer">Visit Instagram</a></div>:!feed?.connected||!reelCount?<div className="reels-showcase__empty"><p className="eyebrow">From the community</p><h3>Discover more from @bellabyrt</h3><a href={feed?.settings?.profile_url||ACCOUNT_URL} target="_blank" rel="noreferrer">Visit Instagram <ArrowUpRight size={15}/></a></div>:<>
        <div className="reels-showcase__viewport" ref={viewportRef} style={{'--reels-visible':cardsVisible}} role="region" aria-label="Instagram Reels from bellabyrt" tabIndex={0} onKeyDown={onKeyDown} onFocus={()=>setPaused(true)} onBlur={event=>{if(!event.currentTarget.contains(event.relatedTarget))setPaused(false);}} onPointerDown={pointerDown} onPointerMove={pointerMove} onPointerUp={pointerUp} onPointerCancel={pointerUp} onClickCapture={preventDraggedClick}>
          <div ref={trackRef} className={`reels-showcase__track${dragging?' is-dragging':''}`} style={{transform:`translate3d(${-position*stride+dragOffset}px,0,0)`,transition:dragging||reducedMotion||snapReset?'none':undefined}} onTransitionEnd={onTrackTransitionEnd}>
            {carouselReels.map((reel,index)=>{
              const clone=index<reelCount||index>=reelCount*2;
              return <div className="reels-showcase__slide" key={`${reel.id}-${index}`} aria-hidden={clone||undefined} inert={clone||undefined}><ReelCard reel={reel}/></div>;
            })}
          </div>
        </div>
        {feed?.nextOffset!==null&&feed?.nextOffset!==undefined&&<div className="reels-showcase__older"><button type="button" onClick={loadOlder} disabled={loadingMore}>{loadingMore?'Loading…':'Load older Reels'} <ArrowDown size={14}/></button></div>}
      </>}
    </div>
  </section>;
}
