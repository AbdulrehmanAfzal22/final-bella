import {Link,Navigate,useParams} from 'react-router-dom';
import {useQuery} from '../hooks/useQuery';
import {getActiveCategories,getProductsByCategory} from '../services/catalog';
import {ErrorState,Empty,Loading} from '../components/Feedback';
import ProductGrid from '../components/commerce/ProductGrid';
import {usePageMetadata} from '../hooks/usePageMetadata';
import {findCategoryByRoute} from '../lib/categoryMatching';

export default function CategoryProducts({section='collections'}){
  const isAccessoryRoute=section==='accessories';
  const {category:routeCategory=''}=useParams();
  const categoriesQuery=useQuery(getActiveCategories);
  const category=findCategoryByRoute(categoriesQuery.data||[],routeCategory);
  const productsQuery=useQuery(()=>category?getProductsByCategory(category.id):Promise.resolve([]),[category?.id]);
  const title=category?.name||routeCategory.replace(/-/g,' ');
  usePageMetadata({title:`${title} ${isAccessoryRoute?'accessories':'collection'}`,description:`Explore ${title} from Bella by RT.`,noindex:Boolean(categoriesQuery.data&&!category)});

  if(categoriesQuery.loading&&!categoriesQuery.data)return <Loading label="Opening this collection…"/>;
  if(categoriesQuery.error)return <ErrorState error={categoriesQuery.error} retry={categoriesQuery.refresh}/>;
  if(!category)return <Empty title="Collection not found" text="This collection may have moved. Browse all of Bella by RT instead." link={isAccessoryRoute?'/accessories':'/collections'} action={`Explore all ${isAccessoryRoute?'accessories':'collections'}`}/>;
  if(category.is_accessory!==isAccessoryRoute)return <Navigate to={`${category.is_accessory?'/accessories':'/collections'}/${encodeURIComponent(category.slug)}`} replace/>;
  if(productsQuery.loading&&!productsQuery.data)return <Loading label={`Discovering ${category.name}…`}/>;
  if(productsQuery.error)return <ErrorState error={productsQuery.error} retry={productsQuery.refresh}/>;

  const products=productsQuery.data||[];
  return <section className="page category-collection-page">
    <p className="eyebrow"><Link to={isAccessoryRoute?'/accessories':'/collections'}>{isAccessoryRoute?'Accessories':'Collections'}</Link> / {category.name}</p>
    <header className="category-collection-page__heading"><h1>{category.name}</h1><p>{products.length} {products.length===1?'piece':'pieces'}</p></header>
    {products.length?<ProductGrid products={products}/>:<Empty variant="premium" className="category-collection-page__empty" title="No pieces available in this collection yet." text="Explore the full collection and discover another point of view." link={isAccessoryRoute?'/accessories':'/collections'} action={`Explore all ${isAccessoryRoute?'accessories':'collections'}`}/>}
  </section>;
}