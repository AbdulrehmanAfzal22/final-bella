import {useEffect,useRef} from 'react';

export default function PackagingGlow(){
  const ref=useRef(null);
  useEffect(()=>{
    const sync=()=>{ref.current.dataset.paused=document.hidden?'true':'false';};
    document.addEventListener('visibilitychange',sync);sync();
    return ()=>document.removeEventListener('visibilitychange',sync);
  },[]);
  return <div ref={ref} className="packaging-glow" aria-hidden="true"><span/><span/></div>;
}
