import {Facebook,Instagram,Music2,Pin} from 'lucide-react';
import {Link} from 'react-router-dom';
import BrandLogo from './BrandLogo';

export default function LuxuryFooter(){
  const socialLinks=[{label:'Instagram',href:import.meta.env.VITE_INSTAGRAM_URL||'https://www.instagram.com/bellabyrt/',envName:'VITE_INSTAGRAM_URL',Icon:Instagram},{label:'TikTok',href:import.meta.env.VITE_TIKTOK_URL,envName:'VITE_TIKTOK_URL',Icon:Music2},{label:'Pinterest',href:import.meta.env.VITE_PINTEREST_URL,envName:'VITE_PINTEREST_URL',Icon:Pin}];
  return <footer className="home-footer">
    <div className="home-footer__inner">
      <div className="home-footer__brand"><Link className="luxury-wordmark" to="/" aria-label="Bella by RT home"><BrandLogo className="luxury-wordmark__image" alt=""/></Link><p>A little gloss. A little colour.<br/>A little more you.</p></div>
      <nav aria-label="Explore"><h2>Explore</h2><Link to="/collections">Collections</Link><Link to="/accessories">Accessories</Link><Link to="/shop?sort=newest">New arrivals</Link><Link to="/shop">Shop</Link></nav>
      <nav aria-label="Customer Care"><h2>Customer Care</h2><Link to="/contact-support">Contact us</Link><Link to="/about">Shipping</Link><Link to="/contact-support">Returns</Link><Link to="/orders">Order history</Link></nav>
      <nav aria-label="Follow"><h2>Follow</h2><div className="home-footer__socials">{socialLinks.map(({label,href,envName,Icon})=>href?<a href={href} key={label} target="_blank" rel="noreferrer" aria-label={label}><Icon size={15}/><small>{label}</small></a>:<span key={label} title={`Configure ${envName} to link this profile`} aria-label={`${label} profile link not configured`}><Icon size={15}/><small>{label}</small></span>)}</div></nav>
      <div className="home-footer__legal"><small>© {new Date().getFullYear()} Bella by RT</small><small>Considered, always.</small></div>
    </div>
  </footer>;
}