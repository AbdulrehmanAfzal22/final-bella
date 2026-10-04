import './BrandLogo.css';

export default function BrandLogo({className='',alt='Bella by RT'}){
  return <img className={`brand-logo ${className}`.trim()} src="/assets/bella-logo.png" alt={alt} decoding="async" draggable="false"/>;
}