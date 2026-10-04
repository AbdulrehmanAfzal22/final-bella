import {useEffect,useRef} from 'react';
import {NavLink,Link} from 'react-router-dom';
import {ArrowUpRight,Boxes,ChartNoAxesCombined,ChevronLeft,ChevronRight,Instagram,LayoutDashboard,LogOut,MessageSquare,Package,Settings,ShoppingBag,Star,Tags,Users,X} from 'lucide-react';
import {adminNavigation} from '../../config/navigation';
import BrandLogo from '../BrandLogo';

const icons={Overview:LayoutDashboard,'All Products':Package,Collections:Tags,Accessories:ShoppingBag,'Instagram Reels':Instagram,Inventory:Boxes,Orders:ShoppingBag,Customers:Users,Analytics:ChartNoAxesCombined,Reviews:Star,Support:MessageSquare,'Support Inbox':MessageSquare};

export default function AdminSidebar({user,collapsed=false,mobileOpen=false,onToggle,onClose,onSignOut}){
  const sidebarRef=useRef(null);
  const closeRef=useRef(null);
  useEffect(()=>{
    if(!mobileOpen)return;
    closeRef.current?.focus();
    function trapFocus(event){
      if(event.key!=='Tab')return;
      const focusable=[...sidebarRef.current.querySelectorAll('a[href],button:not(:disabled)')];
      if(!focusable.length)return;
      if(event.shiftKey&&document.activeElement===focusable[0]){event.preventDefault();focusable.at(-1).focus();}
      else if(!event.shiftKey&&document.activeElement===focusable.at(-1)){event.preventDefault();focusable[0].focus();}
    }
    window.addEventListener('keydown',trapFocus);
    return()=>window.removeEventListener('keydown',trapFocus);
  },[mobileOpen]);
  return <>
    {mobileOpen&&<button className="admin-drawer-backdrop" type="button" aria-label="Close navigation" onClick={onClose}/>}
    <aside id="admin-sidebar" ref={sidebarRef} className={`admin-sidebar admin-sidebar--premium ${collapsed?'is-collapsed':''} ${mobileOpen?'is-open':''}`} aria-label="Administration sidebar" role={mobileOpen?'dialog':undefined} aria-modal={mobileOpen||undefined} aria-labelledby="admin-sidebar-title">
      <div className="admin-sidebar__brand"><Link id="admin-sidebar-title" className="wordmark" to="/admin" aria-label="Bella by RT studio home"><BrandLogo className="admin-sidebar__brand-logo" alt=""/></Link><button ref={closeRef} type="button" className="admin-sidebar__mobile-close" onClick={onClose} aria-label="Close navigation"><X size={18}/></button></div>
      <p className="admin-sidebar__section-label">Workspace</p>
      <nav aria-label="Administration">{adminNavigation.map(({to,label,end})=>{const Icon=icons[label]||Package;const displayLabel=label==='Overview'?'Dashboard':label;return <NavLink end={end} key={to} to={to} title={collapsed?displayLabel:undefined} onClick={onClose}><Icon size={17}/><span>{displayLabel}</span></NavLink>;})}<span className="admin-sidebar__disabled" aria-label="Settings are not available" title="Settings are not available"><Settings size={17}/><span>Settings</span><small>Soon</small></span></nav>
      <div className="admin-sidebar__bottom"><Link to="/shop" onClick={onClose}><ArrowUpRight size={16}/><span>View storefront</span></Link><div className="admin-sidebar__account"><span className="admin-sidebar__avatar" aria-hidden="true">{(user?.email||'M').slice(0,1).toUpperCase()}</span><span className="admin-sidebar__email" title={user?.email}>{user?.email||'Studio account'}</span></div><button type="button" onClick={onSignOut}><LogOut size={16}/><span>Sign out</span></button><button type="button" className="admin-sidebar__collapse" onClick={onToggle} aria-label={collapsed?'Expand sidebar':'Collapse sidebar'} title={collapsed?'Expand sidebar':'Collapse sidebar'}>{collapsed?<ChevronRight size={17}/>:<ChevronLeft size={17}/>}<span>{collapsed?'Expand':'Collapse sidebar'}</span></button></div>
    </aside>
  </>;
}