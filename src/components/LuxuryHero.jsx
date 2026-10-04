import {useEffect,useRef} from 'react';
import {ArrowDown,ArrowUpRight} from 'lucide-react';
import {Link} from 'react-router-dom';

export default function LuxuryHero(){
  const heroRef=useRef(null);

  useEffect(()=>{
    const hero=heroRef.current;
    if(!hero||window.matchMedia('(prefers-reduced-motion: reduce)').matches)return;
    let frame=0;
    const update=()=>{
      cancelAnimationFrame(frame);
      frame=requestAnimationFrame(()=>{
        const offset=Math.max(-30,Math.min(30,-hero.getBoundingClientRect().top*.08));
        hero.style.setProperty('--hero-parallax',`${offset}px`);
      });
    };
    window.addEventListener('scroll',update,{passive:true});
    update();
    return()=>{window.removeEventListener('scroll',update);cancelAnimationFrame(frame);};
  },[]);

  return <section ref={heroRef} className="luxury-hero home-hero" aria-labelledby="hero-title" style={{'--hero-image-source':'url("/assets/bella-hero-v2.png")'}}>
    <img className="luxury-hero__image" src="/assets/bella-hero-v2.png" sizes="100vw" alt="Decorative lip gloss still life in rose gold and pearl pink" fetchPriority="high" decoding="async"/>
    <div className="luxury-hero__shade"/>
    <div className="luxury-hero__content">
      <p className="luxury-hero__eyebrow hero-enter hero-enter--one">Bella by RT <span>—</span> The beauty edit</p>
      <h1 id="hero-title" className="luxury-hero__title hero-enter hero-enter--two">A little gloss.<br/><em>A little more you.</em></h1>
      <p className="luxury-hero__description hero-enter hero-enter--three">Lip gloss, colour and beauty essentials<br className="desktop-break"/> for your everyday ritual.</p>
      <Link className="luxury-outline-button hero-enter hero-enter--four" to="/shop">Explore the collection <ArrowUpRight size={18}/></Link>
    </div>
    <a className="luxury-hero__scroll" href="#home-collections-title" aria-label="Scroll to the Bella by RT story"><span>Discover the collection</span><ArrowDown size={15}/></a>
    <p className="luxury-hero__index" aria-hidden="true">01 / 04</p>
  </section>;
}
