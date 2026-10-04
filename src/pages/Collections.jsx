import {ArrowUpRight} from 'lucide-react';
import {Link} from 'react-router-dom';
import {useQuery} from '../hooks/useQuery';
import {useProducts} from '../hooks/useProducts';
import {getActiveCategories} from '../services/catalog';
import {categoryImageUrl,imageUrl} from '../lib/supabase';
import {ErrorState,Loading} from '../components/Feedback';
import {usePageMetadata} from '../hooks/usePageMetadata';
import {categoriesForSection} from '../lib/categoryMatching';
import {collectionImage} from '../lib/collectionImage';
import CollectionPuzzle from '../components/CollectionPuzzle';

export default function Collections({isAccessory=false}){
  const categoriesQuery=useQuery(()=>getActiveCategories(isAccessory),[isAccessory]);
  const productsQuery=useProducts();
  const sectionName=isAccessory?'Accessories':'Collections';
  const categoryBase=isAccessory?'/accessories':'/collections';
  usePageMetadata({title:sectionName,description:`Explore every Bella by RT ${sectionName.toLowerCase()} category.`});

  if((categoriesQuery.loading&&!categoriesQuery.data)||(productsQuery.loading&&!productsQuery.data))return <Loading label="Opening collections…"/>;
  if(categoriesQuery.error)return <ErrorState error={categoriesQuery.error} retry={categoriesQuery.refresh}/>;
  if(productsQuery.error)return <ErrorState error={productsQuery.error} retry={productsQuery.refresh}/>;

  const categories=categoriesForSection(categoriesQuery.data,isAccessory);
  const productImagesByCategory=new Map();
  for(const product of productsQuery.data||[]){
    if(!product.category_id||productImagesByCategory.has(product.category_id))continue;
    const image=[...(product.product_images||[])].sort((left,right)=>left.position-right.position)[0];
    if(image)productImagesByCategory.set(product.category_id,image);
  }
  const collections=categories.map((category,index)=>{
    const image=productImagesByCategory.get(category.id);
    return {category,image:isAccessory?(category.image_path?categoryImageUrl(category.image_path):image?imageUrl(image.path):null):collectionImage(category,image,index),alt:category.image_path?category.image_alt||category.name:image?.alt||category.name};
  }).sort((left,right)=>(left.category.display_order||0)-(right.category.display_order||0));

  return <div className={`page collections-directory ${isAccessory?'collections-directory--accessories':''}`}>
    <header className="collections-directory__heading"><p className="eyebrow">The Bella by RT beauty collection</p><h1>{sectionName}</h1><p>Distinct expressions, considered together.</p></header>
    {collections.length?isAccessory?<div className="collections-directory__grid">{collections.map(({category,image,alt})=><Link className="collection-directory-card" key={category.id} to={`${categoryBase}/${encodeURIComponent(category.slug)}`} aria-label={`Explore ${category.name}`}>
      <span className="collection-directory-card__media">{image?<img src={image} alt={alt} loading="lazy" decoding="async"/>:<span className="collection-directory-card__placeholder" aria-hidden="true">{category.name.slice(0,1)}</span>}<span className="collection-directory-card__cta">Explore <ArrowUpRight size={15}/></span></span>
      <span className="collection-directory-card__name">{category.name}</span>
    </Link>)}</div>:<CollectionPuzzle collections={collections.map(({category,image,alt})=>({slug:category.slug,name:category.name,displayOrder:category.display_order||0,image,alt}))}/>:<div className="collections-directory__empty"><p className="eyebrow">A new edit is on its way</p><h2>Collections are taking shape.</h2></div>}
  </div>;
}