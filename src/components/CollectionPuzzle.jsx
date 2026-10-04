import {useEffect,useMemo,useRef,useState} from 'react';
import {AnimatePresence,motion,useMotionValue,useReducedMotion,useSpring} from 'framer-motion';
import {ArrowUpRight} from 'lucide-react';
import {Link} from 'react-router-dom';
import {ease} from '../lib/motion';

const MotionLink=motion.create(Link);

function layoutMode(width){
  if(width<768)return 'mobile';
  if(width<=1023)return 'tablet';
  return 'desktop';
}

function masonryColumnCount(width){
  if(width<300)return 1;
  if(width<680)return 2;
  if(width<1100)return 3;
  if(width<1500)return 4;
  return 5;
}

function imageShape(ratio){
  if(ratio<.75)return 'portrait';
  if(ratio<=1.15)return 'square';
  if(ratio<=1.8)return 'landscape';
  return 'wide';
}

function buildMasonryLayout(items,containerWidth,minimumCount=items.length){
  if(!items.length||containerWidth<=0)return {tiles:[],height:0};

  const gap=containerWidth<680?12:16;
  const columns=masonryColumnCount(containerWidth);
  const cardWidth=(containerWidth-gap*(columns-1))/columns;
  const columnHeights=Array(columns).fill(0);
  const maximumCount=Math.min(items.length,Math.max(minimumCount,columns*3));
  const tiles=[];

  for(const item of items.slice(0,maximumCount)){
    const column=columnHeights.indexOf(Math.min(...columnHeights));
    const ratio=item.ratio>0?item.ratio:1;
    const height=cardWidth/ratio;
    const tile={
      ...item,
      left:column*(cardWidth+gap),
      top:columnHeights[column],
      width:cardWidth,
      height,
    };
    columnHeights[column]+=height+gap;
    tiles.push(tile);

    if(tiles.length>=minimumCount){
      const filledHeights=columnHeights.filter(value=>value>0).map(value=>value-gap);
      const heightSpread=Math.max(...filledHeights)-Math.min(...filledHeights);
      const tallestColumn=Math.max(...filledHeights);
      if(heightSpread<=cardWidth*.7||tallestColumn>=cardWidth*4)break;
    }
  }

  return {tiles,height:Math.max(0,Math.max(...columnHeights)-gap)};
}

function CollectionPuzzleCard({collection,index,ratio,left,top,width,height,entered,reducedMotion}){
  const pointerX=useMotionValue(0);
  const pointerY=useSpring(useMotionValue(0),{stiffness:180,damping:24,mass:.35});
  const cardRef=useRef(null);
  const style={
    left:`${left}px`,
    top:`${top}px`,
    width:`${width}px`,
    height:`${height}px`,
    '--reveal-delay':`${Math.min(index,8)*85}ms`,
  };

  function movePointer(event){
    if(reducedMotion||event.pointerType!=='mouse'||!cardRef.current)return;
    const bounds=cardRef.current.getBoundingClientRect();
    pointerX.set(((event.clientX-bounds.left)/bounds.width-.5)*7);
    pointerY.set(((event.clientY-bounds.top)/bounds.height-.5)*7);
  }

  function resetPointer(){
    pointerX.set(0);
    pointerY.set(0);
  }

  return <motion.article
    ref={cardRef}
    className={`collection-puzzle__item collection-puzzle__item--${imageShape(ratio)}${entered?' is-entered':''}`}
    style={{...style,x:reducedMotion?0:pointerX,y:reducedMotion?0:pointerY}}
    data-image-shape={imageShape(ratio)}
    layout={!reducedMotion}
    layoutId={`featured-collection-${collection.slug}`}
    initial={reducedMotion?false:{opacity:0,y:18,scale:.985}}
    animate={entered||reducedMotion?{opacity:1,y:0,scale:1}:{opacity:0,y:18,scale:.985}}
    exit={reducedMotion?{opacity:0,transition:{duration:0}}:{opacity:0,y:-10,scale:.985,transition:{duration:.48,ease}}}
    transition={{layout:{type:'spring',stiffness:170,damping:25,mass:.85},opacity:{duration:.62,delay:reducedMotion?0:Math.min(index,8)*.075,ease},y:{duration:.62,delay:reducedMotion?0:Math.min(index,8)*.075,ease},scale:{duration:.62,delay:reducedMotion?0:Math.min(index,8)*.075,ease}}}
    onPointerMove={movePointer}
    onPointerLeave={resetPointer}
    onBlur={resetPointer}
  >
    <MotionLink
      className="collection-puzzle__card"
      to={`/collections/${encodeURIComponent(collection.slug)}`}
      aria-label={`Explore ${collection.name}`}
      whileHover={reducedMotion?undefined:{y:-4}}
      whileFocus={reducedMotion?undefined:{y:-4}}
      transition={{duration:.48,ease}}
    >
      <span className="collection-puzzle__media">
        {collection.image&&<img className="collection-puzzle__image" src={collection.image} alt={collection.alt||collection.name} loading="eager" decoding="async"/>}
        <span className="collection-puzzle__shade" aria-hidden="true"/>
      </span>
      <span className="collection-puzzle__copy">
        <span className="collection-puzzle__eyebrow">The collection</span>
        <span className="collection-puzzle__title">{collection.name}</span>
        <span className="collection-puzzle__explore">Explore collection <ArrowUpRight size={16} aria-hidden="true"/></span>
      </span>
    </MotionLink>
  </motion.article>;
}

export default function CollectionPuzzle({collections,limitRows=false}){
  const reducedMotion=useReducedMotion();
  const [systemReducedMotion,setSystemReducedMotion]=useState(()=>typeof window!=='undefined'&&window.matchMedia('(prefers-reduced-motion: reduce)').matches);
  const [entered,setEntered]=useState(false);
  const [mode,setMode]=useState('desktop');
  const [containerWidth,setContainerWidth]=useState(0);
  const [imageDimensions,setImageDimensions]=useState({});
  const sectionRef=useRef(null);
  const gridRef=useRef(null);
  const motionIsReduced=Boolean(reducedMotion||systemReducedMotion);

  useEffect(()=>{
    const query=window.matchMedia('(prefers-reduced-motion: reduce)');
    const update=()=>setSystemReducedMotion(query.matches);
    update();
    query.addEventListener('change',update);
    return()=>query.removeEventListener('change',update);
  },[]);

  useEffect(()=>{
    const grid=gridRef.current;
    if(!grid)return undefined;

    const updateWidth=()=>setContainerWidth(grid.clientWidth || sectionRef.current?.clientWidth || 0);
    updateWidth();
    const observer=new ResizeObserver(updateWidth);
    observer.observe(grid);
    return()=>observer.disconnect();
  },[]);

  useEffect(()=>{
    if(containerWidth>0)setMode(layoutMode(containerWidth));
  },[containerWidth]);

  useEffect(()=>{
    let active=true;
    const markLoaded=(slug,src,ratio)=>{
      if(!active)return;
      const measuredRatio=ratio>0?ratio:1;
      setImageDimensions(current=>{
        const existing=current[slug];
        if(existing?.loaded&&existing.src===src&&existing.ratio===measuredRatio)return current;
        return {...current,[slug]:{src,ratio:measuredRatio,loaded:true}};
      });
    };
    for(const collection of collections){
      const src=collection.image||'';
      if(!src){
        markLoaded(collection.slug,src,1);
        continue;
      }
      const image=new Image();
      image.onload=()=>markLoaded(collection.slug,src,image.naturalWidth/image.naturalHeight);
      image.onerror=()=>markLoaded(collection.slug,src,1);
      image.src=src;
      if(image.complete)markLoaded(collection.slug,src,image.naturalWidth?image.naturalWidth/image.naturalHeight:1);
    }
    return()=>{active=false;};
  },[collections]);

  useEffect(()=>{
    const section=sectionRef.current;
    if(!section)return undefined;
    if(!('IntersectionObserver' in window)){
      setEntered(true);
      return undefined;
    }
    const observer=new IntersectionObserver(entries=>{
      if(entries.some(entry=>entry.isIntersecting)){
        setEntered(true);
        observer.disconnect();
      }
    },{threshold:.08});
    observer.observe(section);
    return()=>observer.disconnect();
  },[]);

  const initialCount=mode==='mobile'?3:mode==='tablet'?4:6;
  const compositionItems=limitRows&&collections.length>initialCount?collections.slice(0,-1):collections;

  const imagesReady=compositionItems.every(collection=>{
    const dimensions=imageDimensions[collection.slug];
    return dimensions?.loaded&&dimensions.src===(collection.image||'');
  });
  const layout=useMemo(()=>{
    if(!imagesReady)return {tiles:[],height:0};
    const items=compositionItems.map((collection,index)=>({
      collection,
      index,
      ratio:imageDimensions[collection.slug]?.ratio||1,
    }));
    return buildMasonryLayout(items,containerWidth,limitRows?initialCount:items.length);
  },[containerWidth,mode,compositionItems,imageDimensions,imagesReady,limitRows,initialCount]);
  const hasMore=limitRows&&layout.tiles.length<collections.length;

  return <div
    ref={sectionRef}
    className="collection-puzzle"
  >
    <motion.div ref={gridRef} className={`collection-puzzle__grid collection-puzzle__grid--${mode}`} layout={!reducedMotion}>
      <div className="collection-puzzle__mosaic" style={{height:`${layout.height}px`}}>
        <AnimatePresence initial={false} mode="popLayout">
          {layout.tiles.map((tile,index)=><CollectionPuzzleCard key={tile.collection.slug} collection={tile.collection} index={index} ratio={tile.ratio} left={tile.left} top={tile.top} width={tile.width} height={tile.height} entered={entered} reducedMotion={motionIsReduced}/>) }
        </AnimatePresence>
      </div>
    </motion.div>
    {hasMore&&<Link className="collection-puzzle__toggle" to="/collections">View more collections <ArrowUpRight size={15} aria-hidden="true"/></Link>}
  </div>;
}
