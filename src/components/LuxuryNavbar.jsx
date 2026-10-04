import {useEffect,useState} from 'react';
import {Heart,Menu,Search,ShoppingBag,UserRound,X} from 'lucide-react';
import {Link,useLocation} from 'react-router-dom';
import {storeNavigation} from '../config/navigation';
import {useAuth} from '../hooks/useAuth';
import BrandLogo from './BrandLogo';

export default function LuxuryNavbar({home=false}){
  const [open,setOpen]=useState(false);
  const [scrolled,setScrolled]=useState(false);
  const location=useLocation();
  const {user}=useAuth();
  const accountPath=user?'/account':'/login';
  const close=()=>setOpen(false);

  useEffect(()=>{
    if(!home){setScrolled(false);return;}
    const update=()=>setScrolled(window.scrollY>36);
    update();
    window.addEventListener('scroll',update,{passive:true});
    return()=>window.removeEventListener('scroll',update);
  },[home]);

  useEffect(()=>{
    if(!open)return;
    const previousOverflow=document.body.style.overflow;
    const onKeyDown=event=>{if(event.key==='Escape')close();};
    document.body.style.overflow='hidden';
    window.addEventListener('keydown',onKeyDown);
    return()=>{document.body.style.overflow=previousOverflow;window.removeEventListener('keydown',onKeyDown);};
  },[open]);

  useEffect(()=>{setOpen(false);},[location.pathname]);

  const active=(path,query)=>location.pathname===path&&(!query||location.search.includes(query));
  const className=['luxury-nav',home?'is-home':'',scrolled?'is-scrolled':''].filter(Boolean).join(' ');
  return <header className={className}>
    <div className="luxury-nav__bar">
      <button className="luxury-nav__menu-toggle" type="button" aria-label={open?'Close navigation menu':'Open navigation menu'} aria-expanded={open} aria-controls="mobile-navigation" onClick={()=>setOpen(value=>!value)}>{open?<X size={22}/>:<Menu size={22}/>}</button>
      <Link className="luxury-wordmark" to="/" aria-label="Bella by RT home"><BrandLogo className="luxury-wordmark__image" alt=""/></Link>
      <nav className="luxury-nav__links" aria-label="Main navigation">
        {storeNavigation.map(item=><Link key={item.to} className={active(item.to.split('?')[0],item.to.includes('?')?item.to.split('?')[1]:null)&&(!item.to.includes('?')?!location.search:true)?'is-active':''} to={item.to}>{item.label}</Link>)}
      </nav>
      <div className="luxury-nav__tools" aria-label="Your beauty collection">
        <Link to="/shop" aria-label="Search collection"><Search size={19}/></Link>
        <Link to={accountPath} aria-label="My account"><UserRound size={19}/></Link>
        <Link to="/wishlist" aria-label="Wishlist"><Heart size={19}/></Link>
        <Link to="/cart" aria-label="Shopping bag"><ShoppingBag size={19}/></Link>
      </div>
    </div>
    <div id="mobile-navigation" className="luxury-nav__drawer" data-open={open} aria-hidden={!open} inert={!open}>
      <p className="eyebrow">A beauty collection with room for individuality</p>
      <nav aria-label="Mobile navigation">
        {storeNavigation.map(item=><Link key={item.to} to={item.to} onClick={close}>{item.label}</Link>)}
      </nav>
      <div className="luxury-nav__drawer-utility"><Link to="/shop" onClick={close}>Search</Link><Link to={accountPath} onClick={close}>Account</Link><Link to="/wishlist" onClick={close}>Wishlist</Link><Link to="/cart" onClick={close}>Shopping bag</Link></div>
      <span className="luxury-nav__drawer-signoff">Bella by RT · 2026</span>
    </div>
  </header>;
}