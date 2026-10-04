export default function Container({as:Element='div',width='default',className='',children,...props}){
  const widthClass=width==='wide'?'me-container--wide':width==='narrow'?'me-container--narrow':'';
  return <Element className={`me-container ${widthClass} ${className}`.trim()} {...props}>{children}</Element>;
}