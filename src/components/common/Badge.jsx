const tones=new Set(['neutral','bronze','success','warning','danger']);

export default function Badge({tone='neutral',as:Element='span',className='',children,...props}){
  const safeTone=tones.has(tone)?tone:'neutral';
  return <Element className={`me-badge me-badge--${safeTone} ${className}`.trim()} {...props}>{children}</Element>;
}