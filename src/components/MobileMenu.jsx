import {ArrowUpRight,X} from 'lucide-react';
import {Link,useLocation} from 'react-router-dom';
import {useEffect,useLayoutEffect,useRef} from 'react';
import {storeNavigation} from '../config/navigation';
import {useAuth} from '../hooks/useAuth';
import BrandLogo from './BrandLogo';
import IconButton from './common/IconButton';

export default function MobileMenu({open,onClose}){
  const location=useLocation();
  const {user}=useAuth();
  const panelRef=useRef(null);
  const previousPath=useRef(location.pathname);
  const accountPath=user?'/account':'/login';

  useLayoutEffect(()=>{
    const dialog=panelRef.current;
    if(!dialog)return;
    if(open&&!dialog.open)dialog.showModal();
    if(!open&&dialog.open)dialog.close();
  },[open]);

  useLayoutEffect(()=>{
    if(!open)return;
    const previousOverflow=document.body.style.overflow;
    const onKeyDown=event=>{if(event.key==='Escape'){event.preventDefault();onClose();}};
    document.body.style.overflow='hidden';
    window.addEventListener('keydown',onKeyDown);
    return()=>{document.body.style.overflow=previousOverflow;window.removeEventListener('keydown',onKeyDown);};
  },[open,onClose]);

  useEffect(()=>{
    if(previousPath.current!==location.pathname){
      previousPath.current=location.pathname;
      if(open)onClose();
    }
  },[location.pathname,open,onClose]);

  return <dialog ref={panelRef} id="luxury-mobile-menu" className="luxury-header__drawer" data-open={open} aria-label="Bella by RT navigation" aria-hidden={!open} onCancel={event=>{event.preventDefault();onClose();}} onClick={event=>{if(event.target===event.currentTarget)onClose();}}>
    <IconButton className="luxury-header__drawer-close" type="button" label="Close navigation menu" onClick={onClose} icon={<X size={23} strokeWidth={1.5}/>} />
    <div className="luxury-header__drawer-inner">
      <BrandLogo className="luxury-header__drawer-eyebrow luxury-header__drawer-logo" alt=""/>
      <nav className="luxury-header__drawer-links" aria-label="Mobile main navigation">
        {storeNavigation.map((item,index)=><Link key={item.to} to={item.to} onClick={onClose} style={{'--menu-index':index}}>{item.label}<ArrowUpRight size={18} strokeWidth={1.5}/></Link>)}
      </nav>
      <nav className="luxury-header__drawer-utilities" aria-label="Account and shopping links">
        <Link to="/search" onClick={onClose}>Search collection</Link>
        <Link to={accountPath} onClick={onClose}>{user?'Account':'Sign in'}</Link>
        <Link to="/wishlist" onClick={onClose}>Wishlist</Link>
        <Link to="/cart" onClick={onClose}>Shopping bag</Link>
      </nav>
      <p className="luxury-header__drawer-signoff">Studio · Est. 2026</p>
    </div>
  </dialog>;
}