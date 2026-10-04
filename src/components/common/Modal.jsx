import {useEffect,useRef} from 'react';

export default function Modal({open,onClose,labelledBy,describedBy,className='',closeOnBackdrop=true,children}){
  const ref=useRef(null);
  useEffect(()=>{
    const dialog=ref.current;
    if(!dialog)return;
    if(open&&!dialog.open)dialog.showModal();
    if(!open&&dialog.open)dialog.close();
  },[open]);
  useEffect(()=>{
    if(!open)return;
    const onKeyDown=event=>{if(event.key==='Escape'){event.preventDefault();onClose?.();}};
    window.addEventListener('keydown',onKeyDown);
    return()=>window.removeEventListener('keydown',onKeyDown);
  },[open,onClose]);
  return <dialog ref={ref} className={className||'me-modal'} aria-labelledby={labelledBy} aria-describedby={describedBy} onClose={onClose} onCancel={event=>{event.preventDefault();onClose?.();}} onClick={event=>{if(closeOnBackdrop&&event.target===event.currentTarget)event.currentTarget.close();}}>{children}</dialog>;
}