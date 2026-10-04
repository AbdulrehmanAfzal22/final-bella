import {motion,useReducedMotion,useSpring,useTransform} from 'framer-motion';
import {ArrowUpRight} from 'lucide-react';
import {Link} from 'react-router-dom';
import {ease} from '../lib/motion';

const MotionLink=motion.create(Link);
const cardVariants={rest:{},hover:{}};
const overlayVariants={rest:{opacity:.6},hover:{opacity:1,transition:{duration:.8,ease}}};
const titleVariants={rest:{y:0},hover:{y:-10,transition:{duration:.8,ease}}};
const arrowCurrentVariants={rest:{x:0,y:0},hover:{x:14,y:-14,transition:{duration:.45,ease}}};
const arrowNextVariants={rest:{x:-14,y:14},hover:{x:0,y:0,transition:{duration:.45,delay:.05,ease}}};

export default function CollectionCard({collection,index,x,velocity}){
  const reducedMotion=useReducedMotion();
  const parallax=useTransform(x,value=>reducedMotion?0:Math.max(-42,Math.min(42,value*-.12)));
  const skew=useSpring(useTransform(velocity,[-2500,0,2500],[5,0,-5]),{stiffness:300,damping:40});
  const hover=reducedMotion?undefined:'hover';
  const layoutId=reducedMotion?undefined:`collection-${collection.slug}`;

  return <motion.div className="home-collections__item" style={{skewX:reducedMotion?0:skew}}>
    <MotionLink
      className="home-collection-card"
      to={`/collections/${encodeURIComponent(collection.slug)}`}
      aria-label={`Explore ${collection.name}`}
      variants={cardVariants}
      initial="rest"
      whileHover={hover}
      whileFocus={hover}
    >
      <motion.span
        className="home-collection-card__visual"
        initial={reducedMotion?{opacity:0}:{clipPath:'inset(100% 0% 0% 0%)'}}
        whileInView={reducedMotion?{opacity:1}:{clipPath:'inset(0% 0% 0% 0%)'}}
        viewport={{once:true,amount:.3}}
        transition={{duration:reducedMotion ? .6 : 1.3,delay:reducedMotion?0:index*.12,ease}}
      >
        {collection.image?<motion.img
          src={collection.image}
          alt={collection.alt}
          loading="lazy"
          decoding="async"
          layoutId={layoutId}
          initial={{scale:reducedMotion?1:1.3,opacity:reducedMotion?0:1}}
          whileInView={{scale:1,opacity:1}}
          whileHover={hover?{scale:1.07,transition:{duration:1.4,ease}}:undefined}
          viewport={{once:true,amount:.3}}
          transition={{scale:{duration:reducedMotion ? .6 : 1.8,ease},opacity:{duration:.7,ease},layout:{duration:1,ease}}}
          style={{x:parallax,scale:reducedMotion?1:1.25}}
        />:<span aria-hidden="true">{collection.name.slice(0,1)}</span>}
        <motion.span className="home-collection-card__shade" variants={overlayVariants}/>
      </motion.span>
      <span className="home-collection-card__content">
        <motion.span className="home-collection-card__title" variants={titleVariants}>{collection.name}</motion.span>
        <span className="home-collection-card__cta">Explore collection <span className="home-collection-card__arrow-swap" aria-hidden="true"><motion.span variants={arrowCurrentVariants}><ArrowUpRight size={14}/></motion.span><motion.span variants={arrowNextVariants}><ArrowUpRight size={14}/></motion.span></span></span>
      </span>
    </MotionLink>
  </motion.div>;
}