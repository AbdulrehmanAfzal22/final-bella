import {useEffect,useRef,useState} from 'react';

export default function RevealAnimation({as:Element='div',className='',children,delay=0}){
  const ref=useRef(null);
  const [visible,setVisible]=useState(false);

  useEffect(()=>{
    const node=ref.current;
    if(!node)return;
    if(!('IntersectionObserver' in window)){
      setVisible(true);
      return;
    }
    const observer=new IntersectionObserver(([entry])=>{
      if(entry.isIntersecting){
        setVisible(true);
        observer.disconnect();
      }
    },{threshold:.12,rootMargin:'0px 0px -40px 0px'});
    observer.observe(node);
    return()=>observer.disconnect();
  },[]);

  return <Element ref={ref} className={`reveal ${visible?'is-visible':''} ${className}`} style={{'--reveal-delay':`${delay}ms`}}>{children}</Element>;
}