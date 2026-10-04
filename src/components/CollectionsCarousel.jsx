import {useCallback,useEffect,useRef,useState} from 'react';
import {animate,motion,useMotionValue,useMotionValueEvent,useSpring,useTransform,useVelocity} from 'framer-motion';
import CollectionCard from './CollectionCard';
import CarouselControls from './CarouselControls';
import {ease} from '../lib/motion';

const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));

export default function CollectionsCarousel({collections}){
  const viewportRef=useRef(null);
  const trackRef=useRef(null);
  const strideRef=useRef(1);
  const maxScrollRef=useRef(0);
  const suppressClick=useRef(false);
  const [current,setCurrent]=useState(1);
  const [atStart,setAtStart]=useState(true);
  const [atEnd,setAtEnd]=useState(false);
  const x=useMotionValue(0);
  const velocity=useVelocity(x);
  const trackVelocity=useSpring(useTransform(velocity,[-2500,0,2500],[5,0,-5]),{stiffness:300,damping:40});
  const progress=useTransform(x,value=>maxScrollRef.current?clamp(-value/maxScrollRef.current,0,1):0);
  const measure=useCallback(()=>{
    const viewport=viewportRef.current;
    const track=trackRef.current;
    if(!viewport||!track)return;
    const scrollDistance=Math.max(0,track.scrollWidth-viewport.clientWidth);
    const firstCard=track.querySelector('.home-collections__item');
    const gap=parseFloat(getComputedStyle(track).columnGap)||0;
    if(firstCard)strideRef.current=firstCard.getBoundingClientRect().width+gap;
    maxScrollRef.current=scrollDistance;
    const bounded=clamp(x.get(),-scrollDistance,0);
    if(bounded!==x.get())x.set(bounded);
    setAtStart(bounded>=-1);
    setAtEnd(bounded<=-scrollDistance+1);
  },[x]);

  useEffect(()=>{
    measure();
    const viewport=viewportRef.current;
    const track=trackRef.current;
    if(!viewport||!track)return undefined;
    const observer=new ResizeObserver(measure);
    observer.observe(viewport);
    observer.observe(track);
    return()=>observer.disconnect();
  },[measure,collections.length]);

  useMotionValueEvent(x,'change',value=>{
    const distance=maxScrollRef.current;
    const index=distance===0?1:clamp(Math.round(-value/strideRef.current)+1,1,collections.length);
    setCurrent(previous=>previous===index?previous:index);
    setAtStart(previous=>previous===(value>=-1)?previous:value>=-1);
    setAtEnd(previous=>previous===(value<=-distance+1)?previous:value<=-distance+1);
  });

  function step(direction){
    const target=clamp(x.get()+direction*strideRef.current,-maxScrollRef.current,0);
    animate(x,target,{duration:1,ease});
  }

  function finishDrag(){
    const bounded=clamp(x.get(),-maxScrollRef.current,0);
    if(bounded!==x.get())animate(x,bounded,{duration:.45,ease});
  }

  function preventDraggedClick(event){
    if(!suppressClick.current)return;
    event.preventDefault();
    event.stopPropagation();
    suppressClick.current=false;
  }

  return <>
    <CarouselControls current={current} total={collections.length} progress={progress} onPrevious={()=>step(1)} onNext={()=>step(-1)} atStart={atStart} atEnd={atEnd}/>
    <div
      className="home-collections__viewport"
      ref={viewportRef}
      onWheel={event=>{if(Math.abs(event.deltaX)>Math.abs(event.deltaY)){event.preventDefault();animate(x,clamp(x.get()-event.deltaX,-maxScrollRef.current,0),{duration:.7,ease});}}}
      onClickCapture={preventDraggedClick}
    >
      <motion.div
        className="home-collections__track"
        ref={trackRef}
        style={{x}}
        drag="x"
        dragConstraints={viewportRef}
        dragElastic={.08}
        dragTransition={{power:.3,timeConstant:300}}
        onDragStart={()=>{suppressClick.current=true;}}
        onDragEnd={()=>{finishDrag();window.setTimeout(()=>{suppressClick.current=false;},0);}}
      >
        {collections.map((collection,index)=><CollectionCard key={collection.slug} collection={collection} index={index} x={x} velocity={trackVelocity}/>) }
      </motion.div>
    </div>
  </>;
}