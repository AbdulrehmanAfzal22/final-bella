import {useEffect,useRef,useState} from 'react';
import {Sparkles} from 'lucide-react';
import {useReducedMotion} from 'framer-motion';
import {startFairyMagic} from '../lib/fairyMagic';

export default function FairyScrollMagic(){
  const canvas=useRef(null);
  const reduced=useReducedMotion();
  const [enabled,setEnabled]=useState(()=>{
    try{return localStorage.getItem('bella-fairy-magic')!=='off';}catch{return true;}
  });
  useEffect(()=>{
    document.documentElement.dataset.bellaMagic=enabled&&!reduced?'on':'off';
    return ()=>{delete document.documentElement.dataset.bellaMagic;};
  },[enabled,reduced]);
  useEffect(()=>{
    if(!enabled||reduced||!canvas.current)return;
    return startFairyMagic(canvas.current);
  },[enabled,reduced]);
  function toggle(){
    setEnabled(value=>{
      try{localStorage.setItem('bella-fairy-magic',value?'off':'on');}catch{}
      return !value;
    });
  }
  if(reduced)return null;
  return <>
    {enabled&&<canvas ref={canvas} className="fairy-scroll-magic" aria-hidden="true"/>}
    <button className="fairy-magic-toggle" type="button" onClick={toggle} aria-pressed={enabled}
      aria-label={enabled?'Turn off decorative animations':'Turn on decorative animations'} title={enabled?'Turn off decorative animations':'Turn on decorative animations'}>
      <Sparkles size={15}/><span>{enabled?'Magic on':'Magic off'}</span>
    </button>
  </>;
}
