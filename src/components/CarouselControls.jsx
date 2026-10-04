import {AnimatePresence,motion,useReducedMotion} from 'framer-motion';
import {ArrowLeft,ArrowRight} from 'lucide-react';
import {ease} from '../lib/motion';

export default function CarouselControls({current,total,progress,onPrevious,onNext,atStart,atEnd}){
  const reducedMotion=useReducedMotion();
  const currentLabel=String(current).padStart(2,'0');
  const totalLabel=String(total).padStart(2,'0');

  return <div className="home-collections__controls">
    <span>Discover by category</span>
    <div className="home-collections__control-tools">
      <span className="home-collections__counter" aria-label={`Collection ${current} of ${total}`} aria-live="polite">
        <AnimatePresence initial={false} mode="popLayout">
          <motion.span key={currentLabel} initial={reducedMotion?{opacity:0}:{y:'100%',opacity:0}} animate={{y:0,opacity:1}} exit={reducedMotion?{opacity:0}:{y:'-100%',opacity:0}} transition={{duration:reducedMotion ? .2 : .45,ease}}>{currentLabel}</motion.span>
        </AnimatePresence>
        <span aria-hidden="true"> / {totalLabel}</span>
      </span>
      <span className="home-collections__progress" aria-hidden="true"><motion.span style={{scaleX:progress}}/></span>
      <div className="home-collections__arrows">
        <motion.button type="button" onClick={onPrevious} aria-label="Scroll collections left" disabled={atStart} whileHover={reducedMotion?undefined:{color:'#F8F5EF'}} whileTap={reducedMotion?undefined:{scale:.96}} transition={{duration:.35,ease}}>
          <motion.span className="home-collections__arrow-fill" initial={false} animate={{scale:reducedMotion?0:undefined}} whileHover={reducedMotion?undefined:{scale:1}} transition={{duration:.35,ease}}/>
          <ArrowLeft size={16} aria-hidden="true"/>
        </motion.button>
        <motion.button type="button" onClick={onNext} aria-label="Scroll collections right" disabled={atEnd} whileHover={reducedMotion?undefined:{color:'#F8F5EF'}} whileTap={reducedMotion?undefined:{scale:.96}} transition={{duration:.35,ease}}>
          <motion.span className="home-collections__arrow-fill" initial={false} animate={{scale:reducedMotion?0:undefined}} whileHover={reducedMotion?undefined:{scale:1}} transition={{duration:.35,ease}}/>
          <ArrowRight size={16} aria-hidden="true"/>
        </motion.button>
      </div>
    </div>
  </div>;
}