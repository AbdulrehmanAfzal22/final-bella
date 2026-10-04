import {ArrowRight} from 'lucide-react';
import {Link} from 'react-router-dom';
import {useQuery} from '../hooks/useQuery';
import {getActiveCategories} from '../services/catalog';
import {categoryImageUrl,imageUrl} from '../lib/supabase';
import {categoriesForSection} from '../lib/categoryMatching';
import RevealAnimation from './RevealAnimation';

export const STYLE_DISCOVERY_SECTION={
  title:'Find Your Glow',
  cards:[
    {id:'everyday-elegance',title:'Everyday Glow',description:'Gloss favourites for your everyday ritual.',categoryLink:{section:'collections',slug:null,match:['gloss','oil','balm']},image:'/assets/bella-beauty-editorial.png',imageAlt:'A woman in a decorative lip gloss still life'},
    {id:'occasion-wear',title:'A Touch of Colour',description:'Explore colour for your favourite moments.',categoryLink:{section:'collections',slug:null,match:['tint','makeup']},image:'/assets/bella-tint.png',imageAlt:'Decorative rosy lip and cheek tint still life'},
    {id:'complete-the-look',title:'Complete The Look',description:'Accessories that finish your style.',categoryLink:{section:'accessories',slug:null,match:[]},image:'/assets/bella-balm.png',imageAlt:'Decorative beauty essentials'}
  ]
};

function findStyleCategory(categories,card){
  const candidates=categoriesForSection(categories,card.categoryLink.section==='accessories');
  if(card.categoryLink.slug)return candidates.find(category=>category.slug===card.categoryLink.slug)||null;
  if(card.categoryLink.section==='accessories')return candidates[0]||null;
  return candidates.find(category=>{
    const value=`${category.name||''} ${category.slug||''}`.toLowerCase();
    return card.categoryLink.match.some(keyword=>value.includes(keyword));
  })||null;
}

export default function StorySection({products=[],section=STYLE_DISCOVERY_SECTION}){
  const categoriesQuery=useQuery(()=>getActiveCategories(null),[]);
  const categories=categoriesQuery.data||[];
  const productImages=new Map();
  products.forEach(product=>{
    if(!product.category_id||productImages.has(product.category_id))return;
    const image=[...(product.product_images||[])].sort((left,right)=>left.position-right.position)[0];
    if(image)productImages.set(product.category_id,image);
  });

  return <section className="home-style-discovery" aria-labelledby="home-style-discovery-title">
    <header className="home-style-discovery__heading"><p className="eyebrow">The Bella by RT edit</p><h2 id="home-style-discovery-title">{section.title}</h2></header>
    <div className="home-style-discovery__grid">{section.cards.map((card,index)=>{
      const category=findStyleCategory(categories,card);
      const productImage=category&&productImages.get(category.id);
      const image=card.image||(category?.image_path?categoryImageUrl(category.image_path):productImage?imageUrl(productImage.path):null);
      const imageAlt=card.image?card.imageAlt:category?.image_path?category.image_alt||category.name:productImage?.alt||category?.name||card.imageAlt;
      const base=card.categoryLink.section==='accessories'?'/accessories':'/collections';
      const to=category?.slug?`${base}/${encodeURIComponent(category.slug)}`:base;
      return <RevealAnimation key={card.id} className="home-style-discovery__item" delay={index*100}>
        <article className="home-style-card">
          <Link className="home-style-card__image-link" to={to} aria-label={`Explore ${card.title}`}><img src={image} alt={imageAlt} loading="lazy" decoding="async"/><span className="home-style-card__shade" aria-hidden="true"/><span className="home-style-card__arrow" aria-hidden="true"><ArrowRight size={18}/></span></Link>
          <div className="home-style-card__copy"><h3>{card.title}</h3><p>{card.description}</p><Link className="home-style-card__cta" to={to}>Explore <ArrowRight size={15} aria-hidden="true"/></Link></div>
        </article>
      </RevealAnimation>;
    })}</div>
  </section>;
}