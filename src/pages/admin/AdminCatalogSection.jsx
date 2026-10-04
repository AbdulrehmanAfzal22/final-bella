import {Link,useSearchParams} from 'react-router-dom';
import {Plus} from 'lucide-react';
import Categories from '../../admin/Categories';
import Products from './Products';

export default function AdminCatalogSection({isAccessory}){
  const [params]=useSearchParams();
  const section=isAccessory?'accessories':'collections';
  const label=isAccessory?'Accessories':'Collections';
  const tab=params.get('tab')==='products'?'products':'categories';

  return <div className="admin-catalog-section" key={section}>
    <div className="section-heading admin-page-heading"><div><p className="eyebrow">CATALOG MANAGEMENT</p><h1>{label}</h1><p className="admin-page-intro">Manage {label.toLowerCase()} categories and the products assigned to them.</p></div>{tab==='products'&&<Link to={`/admin/products/create?group=${section}`} className="button"><Plus size={15}/> Add product</Link>}</div>
    <nav className="admin-catalog-tabs" aria-label={`${label} management`}>
      <Link to={`/admin/${section}?tab=categories`} className={tab==='categories'?'is-active':''} aria-current={tab==='categories'?'page':undefined}>Categories</Link>
      <Link to={`/admin/${section}?tab=products`} className={tab==='products'?'is-active':''} aria-current={tab==='products'?'page':undefined}>Products</Link>
    </nav>
    <div className="admin-catalog-section__content" key={`${section}:${tab}`}>
      {tab==='categories'?<Categories key={section} isAccessory={isAccessory} showHeading={false}/>:<Products isAccessory={isAccessory} showHeading={false}/>}
    </div>
  </div>;
}
