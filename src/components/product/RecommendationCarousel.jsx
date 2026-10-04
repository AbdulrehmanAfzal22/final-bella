import {useRef} from 'react';
import {ChevronLeft,ChevronRight} from 'lucide-react';
import {useQuery} from '../../hooks/useQuery';
import {getProducts} from '../../services/catalog';
import ProductCard from '../ProductCard';
import {Loading} from '../Feedback';

export default function RecommendationCarousel({productId,categoryId}){
  const query=useQuery(getProducts,[productId]);
  const track=useRef(null);
  const catalog=(query.data||[]).filter(product=>product.id!==productId);
  const sameCategory=catalog.filter(product=>categoryId&&product.category_id===categoryId);
  const recommendations=[...sameCategory,...catalog.filter(product=>!sameCategory.includes(product))].slice(0,8);

  if(query.loading&&!query.data)return <section className="product-recommendations"><h2>You may also like</h2><Loading label="Curating related pieces…"/></section>;
  if(query.error||!recommendations.length)return null;

  return <section className="product-recommendations" aria-labelledby="recommendations-title"><header><div><p className="eyebrow">The Bella by RT edit</p><h2 id="recommendations-title">You may also like</h2></div>{recommendations.length>1&&<div className="product-recommendations__controls"><button type="button" aria-label="Scroll recommendations left" onClick={()=>track.current?.scrollBy({left:-320,behavior:'smooth'})}><ChevronLeft size={18}/></button><button type="button" aria-label="Scroll recommendations right" onClick={()=>track.current?.scrollBy({left:320,behavior:'smooth'})}><ChevronRight size={18}/></button></div>}</header><div ref={track} className="product-recommendations__track">{recommendations.map(product=><div className="product-recommendations__item" key={product.id}><ProductCard product={product}/></div>)}</div></section>;
}