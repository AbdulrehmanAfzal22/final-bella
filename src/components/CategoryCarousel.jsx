import {ArrowLeft,ArrowUpRight} from 'lucide-react';
import {useEffect,useMemo,useRef,useState} from 'react';
import {Link} from 'react-router-dom';
import {useQuery} from '../hooks/useQuery';
import {getActiveCategories} from '../services/catalog';
import {categoryImageUrl,imageUrl} from '../lib/supabase';
import {categoriesForSection} from '../lib/categoryMatching';
import {ErrorState} from './Feedback';
import Container from './common/Container';

export default function CategoryCarousel({products=[]}){
  const categoriesQuery=useQuery(()=>getActiveCategories(true),[]);
  const [expanded,setExpanded]=useState(false);
  const [entered,setEntered]=useState(false);
  const sectionRef=useRef(null);

  useEffect(()=>{
    const section=sectionRef.current;
    if(!section||!('IntersectionObserver' in window)){
      setEntered(true);
      return;
    }

    const observer=new IntersectionObserver(entries=>{
      if(entries.some(entry=>entry.isIntersecting)){
        setEntered(true);
        observer.disconnect();
      }
    },{threshold:.08});
    observer.observe(section);
    return ()=>observer.disconnect();
  },[]);

  const categories=useMemo(()=>{
    const productImages=new Map();
    products.forEach(product=>{
      if(!product.category_id||productImages.has(product.category_id))return;
      const image=[...(product.product_images||[])].sort((left,right)=>left.position-right.position)[0];
      if(image)productImages.set(product.category_id,image);
    });

    return categoriesForSection(categoriesQuery.data,true).map(category=>{
      const productImage=productImages.get(category.id);
      return {...category,image:category.image_path?categoryImageUrl(category.image_path):productImage?imageUrl(productImage.path):null,alt:category.image_path?category.image_alt||category.name:productImage?.alt||category.name};
    });
  },[categoriesQuery.data,products]);

  const compositions=useMemo(()=>{
    const groups=[];
    for(let index=0;index<categories.length;index+=7)groups.push(categories.slice(index,index+7));
    return groups;
  },[categories]);

  function renderComposition(group,groupIndex){
    const compact=group.length<6;
    const sixItem=group.length===6;

    return <div key={groupIndex} className={`accessories-masonry__composition${compact?' is-compact':''}${sixItem?' is-six':''}`}>
      {group.map((category,index)=>{
        const isTall=index===0||index===3||index===6||(sixItem&&index===5);
        const isFeature=groupIndex===0&&categories.length===1;
        const image=category.image;

        return <Link key={category.id} to={`/accessories/${encodeURIComponent(category.slug)}`} className={`accessories-masonry__card${isTall?' is-tall':''}${isFeature?' is-feature':''}`} style={{'--card-index':groupIndex*7+index}} aria-label={`Explore ${category.name}`}>
          <span className="accessories-masonry__media">{image?<img src={image} alt={category.alt||category.name} loading={groupIndex===0&&index<2?'eager':'lazy'} decoding="async" fetchPriority={groupIndex===0&&index===0?'high':'auto'}/>:<span className="accessories-masonry__placeholder" aria-hidden="true"/>}</span>
          <span className="accessories-masonry__content">
            {isFeature&&<span className="accessories-masonry__feature-kicker">Accessories</span>}
            <span className="accessories-masonry__eyebrow">{category.name}</span>
            {isFeature&&category.description&&<span className="accessories-masonry__description">{category.description}</span>}
            <span className="accessories-masonry__cta">{isFeature?'Explore collection':'Explore'} <ArrowUpRight size={14}/></span>
          </span>
        </Link>;
      })}
    </div>;
  }

  return <section ref={sectionRef} className={`accessories-collections${entered?' is-visible':''}`} aria-labelledby="accessories-collections-title">
    <Container width="wide">
      <header className="accessories-collections__heading">
        <div><p className="eyebrow">Accessories</p><h2 id="accessories-collections-title">Accessories Collection</h2></div>
        <Link className="luxury-text-link" to="/accessories">View all accessories <ArrowUpRight size={16}/></Link>
      </header>
      {categoriesQuery.loading&&!categoriesQuery.data?<div className="accessories-collections__status" role="status">Discovering accessories…</div>:categoriesQuery.error?<ErrorState error={categoriesQuery.error} retry={categoriesQuery.refresh}/>:categories.length?<>
        <div className="accessories-collections__controls"><span>Explore the edit</span></div>
        {renderComposition(compositions[0],0)}
        {compositions.length>1&&<div className={`accessories-masonry__additional${expanded?' is-open':''}`} aria-hidden={!expanded} inert={!expanded}>
          <div className="accessories-masonry__additional-inner">{compositions.slice(1).map((group,index)=>renderComposition(group,index+1))}</div>
        </div>}
        {compositions.length>1&&<div className="accessories-collections__expand"><button type="button" className="accessories-collections__toggle" aria-expanded={expanded} onClick={()=>setExpanded(current=>!current)}>{expanded?'Show less':'View all accessories'} {expanded?<ArrowLeft size={15}/>:<ArrowUpRight size={15}/>}</button></div>}
      </>:<div className="accessories-collections__status">Accessories are being curated.</div>}
    </Container>
  </section>;
}
