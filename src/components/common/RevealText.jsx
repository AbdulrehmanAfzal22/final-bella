import {motion,useReducedMotion} from 'framer-motion';
import {ease} from '../../lib/motion';

export default function RevealText({id,text,className=''}){
  const reducedMotion=useReducedMotion();
  const words=String(text).trim().split(/\s+/);
  if(reducedMotion)return <motion.h2 id={id} className={className} aria-label={text} initial={{opacity:0}} whileInView={{opacity:1}} viewport={{once:true,amount:.3}} transition={{duration:.6,ease}}>{text}</motion.h2>;

  return <motion.h2 id={id} className={`reveal-text ${className}`.trim()} aria-label={text} initial="hidden" whileInView="visible" viewport={{once:true,amount:.3}} variants={{hidden:{},visible:{transition:{staggerChildren:.08}}}}>
    <span aria-hidden="true">{words.map((word,index)=><span className="reveal-text__mask" key={`${word}-${index}`}><motion.span className="reveal-text__word" variants={{hidden:{y:'110%'},visible:{y:'0%',transition:{duration:1.1,ease}}}}>{word}</motion.span>{index<words.length-1?' ':''}</span>)}</span>
  </motion.h2>;
}