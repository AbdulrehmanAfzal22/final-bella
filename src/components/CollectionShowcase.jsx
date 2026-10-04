import {motion} from 'framer-motion';
import {ArrowUpRight} from 'lucide-react';
import {Link} from 'react-router-dom';
import CollectionPuzzle from './CollectionPuzzle';
import RevealText from './common/RevealText';
import Container from './common/Container';
import {ErrorState} from './Feedback';
import {useQuery} from '../hooks/useQuery';
import {getActiveCategories} from '../services/catalog';
import {categoriesForSection} from '../lib/categoryMatching';
import {collectionImage,collectionImageAlt} from '../lib/collectionImage';
import {ease} from '../lib/motion';

const MotionLink=motion.create(Link);

export default function CollectionShowcase({products=[]}){
  const categoriesQuery=useQuery(()=>getActiveCategories(false),[]);
  const productImagesByCategory=new Map();
  for(const product of products){
    const category=product.categories;
    if(!category?.id||productImagesByCategory.has(category.id))continue;
    const image=[...(product.product_images||[])].sort((a,b)=>a.position-b.position)[0];
    if(image)productImagesByCategory.set(category.id,image);
  }
  const collections=categoriesForSection(categoriesQuery.data,false).map((category,index)=>{
    const productImage=productImagesByCategory.get(category.id);
    return {
      slug:category.slug,
      name:category.name,
      displayOrder:category.display_order||0,
      image:collectionImage(category,productImage,index),
      alt:collectionImageAlt(category,productImage)
    };
  }).sort((a,b)=>a.displayOrder-b.displayOrder);

  return <section className="home-collections" aria-labelledby="home-collections-title">
    <Container width="wide">
      <header className="me-section-title home-collections__section-title">
        <div className="me-section-title__copy">
          <motion.p className="me-section-title__eyebrow" initial={{opacity:0,y:20}} whileInView={{opacity:1,y:0}} viewport={{once:true,amount:.3}} transition={{duration:.8,delay:.3,ease}}>Discover the edit</motion.p>
          <RevealText id="home-collections-title" className="me-section-title__heading" text="Shop by category"/>
          <motion.p className="me-section-title__description" initial={{opacity:0,y:20}} whileInView={{opacity:1,y:0}} viewport={{once:true,amount:.3}} transition={{duration:.8,delay:.3,ease}}>A little shine, a touch of colour, a beauty ritual that is yours.</motion.p>
        </div>
        <div className="me-section-title__action">
          <MotionLink className="luxury-text-link home-collections__view-all" to="/collections" initial="rest" whileHover="hover" whileFocus="hover">
            View all collections <ArrowUpRight size={17} aria-hidden="true"/><motion.span className="home-collections__view-all-line" variants={{rest:{scaleX:1,originX:0},hover:{scaleX:0,originX:1}}} transition={{duration:.42,ease}} aria-hidden="true"/>
          </MotionLink>
        </div>
      </header>
      {categoriesQuery.loading&&!categoriesQuery.data?<div className="home-collections__loading" role="status">Discovering the collection…</div>:categoriesQuery.error?<ErrorState error={categoriesQuery.error} retry={categoriesQuery.refresh}/>:collections.length?<CollectionPuzzle collections={collections} limitRows/>:<div className="home-collections__empty"><p className="eyebrow">The collection is taking shape</p><Link className="luxury-text-link" to="/collections">View all collections <ArrowUpRight size={17}/></Link></div>}
    </Container>
  </section>;
}