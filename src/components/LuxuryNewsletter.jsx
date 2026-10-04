import {useState} from 'react';
import {ArrowRight} from 'lucide-react';
import {toast} from 'sonner';
import Button from './common/Button';
import Container from './common/Container';
import Input from './common/Input';
import RevealAnimation from './RevealAnimation';

export default function LuxuryNewsletter(){
  const [email,setEmail]=useState('');
  function submit(event){event.preventDefault();toast.info('Journal sign-up is not connected yet.');}
  return <section className="home-journal" id="home-journal" aria-labelledby="home-journal-title">
    <Container width="wide" className="home-journal__inner">
      <RevealAnimation className="home-journal__copy"><p className="eyebrow">Private Journal</p><h2 id="home-journal-title">Stories behind<br/>your beauty ritual</h2><p>Discover new collections, beauty inspiration and Bella by RT stories.</p></RevealAnimation>
      <RevealAnimation className="home-journal__image" delay={110}><img src="/assets/bella-beauty-editorial.png" alt="Decorative lip gloss editorial" loading="lazy" decoding="async"/></RevealAnimation>
      <RevealAnimation as="div" className="home-journal__form-wrap" delay={180}><p className="home-journal__card-label">A note from the beauty studio</p><h3 className="home-journal__form-title">Notes from Bella</h3><form className="home-journal__form" onSubmit={submit}><Input className="home-journal__input" type="email" name="email" label="Email address" autoComplete="email" placeholder="Your email address" required value={email} onChange={event=>setEmail(event.target.value)}/><Button variant="outline" className="home-journal__submit" type="submit">Join the journal <ArrowRight size={16}/></Button></form><p className="home-journal__privacy">Occasional letters, considered carefully.</p></RevealAnimation>
    </Container>
  </section>;
}