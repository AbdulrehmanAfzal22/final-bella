import {Link,useLocation} from 'react-router-dom';
import {storeNavigation} from '../config/navigation';

function isActive(item,location){
  const [path,query]=item.to.split('?');
  if(location.pathname!==path)return false;
  return query?location.search.includes(query):!location.search;
}

export default function DesktopNav(){
  const location=useLocation();
  return <nav className="luxury-header__desktop-nav" aria-label="Main navigation">
    {storeNavigation.map(item=><Link key={item.to} className={isActive(item,location)?'is-active':''} to={item.to} aria-current={isActive(item,location)?'page':undefined}>{item.label}</Link>)}
  </nav>;
}