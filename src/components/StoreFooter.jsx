import {useState} from 'react';
import {ArrowUpRight,Facebook,Instagram} from 'lucide-react';
import {Link} from 'react-router-dom';
import {toast} from 'sonner';
import {customerNavigation,exploreNavigation} from '../config/navigation';
import {useAuth} from '../hooks/useAuth';
import BrandLogo from './BrandLogo';

export default function StoreFooter(){
  const {admin}=useAuth();
  const [email,setEmail]=useState('');
  const socialLinks=[{label:'Instagram',href:import.meta.env.VITE_INSTAGRAM_URL||'https://www.instagram.com/bellabyrt/',envName:'VITE_INSTAGRAM_URL',Icon:Instagram},{label:'Facebook',href:import.meta.env.VITE_FACEBOOK_URL,envName:'VITE_FACEBOOK_URL',Icon:Facebook}];

  function subscribe(event){event.preventDefault();toast.info('Journal sign-up is not connected yet.');}

  return <footer className="luxury-footer">
    <div className="luxury-footer__journal"><div><p className="eyebrow">Notes from the studio</p><h2>Join the Bella by RT journal</h2><p>Occasional letters on shades, beauty favourites and everyday rituals.</p></div><form className="luxury-footer__signup" onSubmit={subscribe}><label className="visually-hidden" htmlFor="journal-email">Email address</label><input id="journal-email" type="email" autoComplete="email" placeholder="Your email address" required value={email} onChange={event=>setEmail(event.target.value)}/><button type="submit" aria-label="Subscribe to the Bella by RT journal">Subscribe <ArrowUpRight size={16}/></button></form></div>
    <div className="luxury-footer__columns">
      <div className="luxury-footer__brand"><Link className="luxury-wordmark" to="/" aria-label="Bella by RT home"><BrandLogo className="luxury-wordmark__image" alt=""/></Link><p>A little colour.<br/>A little more you.</p></div>
      <div><h3>Explore</h3>{exploreNavigation.map(item=><Link to={item.to} key={item.to}>{item.label}</Link>)}</div>
      <div><h3>Your beauty collection</h3>{customerNavigation.map(item=><Link to={item.to} key={item.to}>{item.label}</Link>)}</div>
      <div><h3>The studio</h3><Link to="/contact-support">Contact us <ArrowUpRight size={14}/></Link><Link to="/admin">{admin?'Open administration':'Studio access'} <ArrowUpRight size={14}/></Link><p>USD · Bella by RT</p><div className="luxury-footer__socials">{socialLinks.map(({label,href,envName,Icon})=>href?<a href={href} key={label} aria-label={label} target="_blank" rel="noreferrer"><Icon size={17}/></a>:<span key={label} title={`Configure ${envName} to link this profile`} aria-label={`${label} profile link not configured`}><Icon size={17}/></span>)}</div></div>
    </div>
    <div className="luxury-footer__legal"><small>© {new Date().getFullYear()} Bella by RT</small><small>Considered, always.</small></div>
  </footer>;
}