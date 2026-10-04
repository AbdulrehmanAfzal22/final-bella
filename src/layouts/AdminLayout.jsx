import {useEffect,useState} from 'react';
import {Outlet,useLocation} from 'react-router-dom';
import {useAuth} from '../hooks/useAuth';
import {usePageMetadata} from '../hooks/usePageMetadata';
import {supabase} from '../lib/supabase';
import AdminSidebar from '../components/admin/AdminSidebar';
import AdminHeader from '../components/admin/AdminHeader';
import './AdminLayout.css';
import '../components/admin/admin-experience.css';

const adminTitles={'/admin':'Dashboard','/admin/products':'All Products','/admin/products/create':'Create product','/admin/categories':'Collections','/admin/collections':'Collections','/admin/accessories':'Accessories','/admin/orders':'Orders','/admin/customers':'Customers','/admin/inventory':'Inventory','/admin/analytics':'Analytics','/admin/reviews':'Reviews Management','/admin/support':'Support Inbox'};

export default function AdminLayout(){
  const {user}=useAuth();
  const location=useLocation();
  const title=location.pathname.includes('/edit')?'Edit product':adminTitles[location.pathname]||'Administration';
  const [collapsed,setCollapsed]=useState(()=>window.innerWidth<=1100);
  const [mobileOpen,setMobileOpen]=useState(false);
  useEffect(()=>{if(!mobileOpen)return;const closeOnEscape=event=>{if(event.key==='Escape')setMobileOpen(false);};window.addEventListener('keydown',closeOnEscape);return()=>window.removeEventListener('keydown',closeOnEscape);},[mobileOpen]);
  usePageMetadata({title:`${title} · Studio`,description:'Bella by RT store administration.',noindex:true});

  return <div className={`admin-layout admin-layout--premium ${collapsed?'is-collapsed':''}`}>
    <AdminSidebar user={user} collapsed={collapsed} mobileOpen={mobileOpen} onToggle={()=>setCollapsed(value=>!value)} onClose={()=>setMobileOpen(false)} onSignOut={()=>supabase.auth.signOut()}/>
    <div className="admin-main"><AdminHeader pathname={location.pathname} user={user} collapsed={collapsed} mobileOpen={mobileOpen} onToggle={()=>setCollapsed(value=>!value)} onMenu={()=>setMobileOpen(true)}/><main className="admin-content"><Outlet/></main></div>
  </div>;
}
