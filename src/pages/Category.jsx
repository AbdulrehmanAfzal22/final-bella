import {Link,useParams} from 'react-router-dom';
import {useQuery} from '../hooks/useQuery';
import {useProducts} from '../hooks/useProducts';
import {getCategories} from '../services/catalog';
import {ErrorState,Empty,Loading} from '../components/Feedback';
import ProductGrid from '../components/commerce/ProductGrid';
import {usePageMetadata} from '../hooks/usePageMetadata';

export default function Category(){
  const {category:slug}=useParams();
  const productsQuery=useProducts();
  const categoriesQuery=useQuery(getCategories);
  const category=categoriesQuery.data?.find(item=>item.slug===slug);
  const title=category?.name||slug.replace(/-/g,' ');
  usePageMetadata({title:`${title} collection`,description:`Explore ${title} from Bella by RT.`,noindex:Boolean(categoriesQuery.data&&!category)});

  if((productsQuery.loading&&!productsQuery.data)||(categoriesQuery.loading&&!categoriesQuery.data))return <Loading label="Opening this collection…"/>;
  if(productsQuery.error)return <ErrorState error={productsQuery.error} retry={productsQuery.refresh}/>;
  if(categoriesQuery.error)return <ErrorState error={categoriesQuery.error} retry={categoriesQuery.refresh}/>;
  if(!category)return <Empty title="Collection not found" text="This collection may have moved. Browse all of Bella by RT instead." link="/shop" action="View all pieces"/>;
  const products=(productsQuery.data||[]).filter(product=>product.category_id===category.id);

  return <section className="page category-page"><p className="eyebrow"><Link to="/collections">Collections</Link> / {category.name}</p><h1>{category.name}</h1>{products.length?<ProductGrid products={products}/>:<Empty title="No pieces in this collection yet" text="Explore the full collection while we prepare what comes next." link="/shop" action="View all pieces"/>}</section>;
}