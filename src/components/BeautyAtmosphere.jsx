import {Heart,Sparkle} from 'lucide-react';
import {useEffect,useRef} from 'react';

// Native vector ornaments keep the hero crisp without extra image downloads.
export default function BeautyAtmosphere(){
  const ref=useRef(null);
  useEffect(()=>{
    const node=ref.current;
    let visible=true;
    const update=()=>{node.dataset.active=visible&&!document.hidden?'true':'false';};
    const observer='IntersectionObserver' in window?new IntersectionObserver(([entry])=>{visible=entry.isIntersecting;update();}):null;
    observer?.observe(node);document.addEventListener('visibilitychange',update);update();
    return ()=>{observer?.disconnect();document.removeEventListener('visibilitychange',update);};
  },[]);
  return <div ref={ref} className="beauty-atmosphere" aria-hidden="true">
    <span className="beauty-atmosphere__petals"><i/><i/><i/><i/></span>
    {[0,1,2,3,4,5].map(index=><span key={index} className={`beauty-atmosphere__charm beauty-atmosphere__charm--${index}`}>
      {index%3===0?<Heart/>:index%3===1?<Sparkle/>:<svg viewBox="0 0 48 48"><path d="M24 25C8 0-2 12 7 24c-11 9 4 20 17 3C37 44 52 33 41 24 50 12 40 0 24 25Z"/><path className="beauty-atmosphere__body" d="M24 19v13m0-13-4-5m4 5 4-5"/></svg>}
    </span>)}
    <span className="beauty-atmosphere__pearl beauty-atmosphere__pearl--one"/>
    <span className="beauty-atmosphere__pearl beauty-atmosphere__pearl--two"/>
  </div>;
}
