import {useId} from 'react';
import {Link} from 'react-router-dom';

export default function EmptyState({title='Nothing here yet',text,link='/shop',action='Explore the collection',variant='legacy',eyebrow,className=''}){
  const titleId=useId();
  if(variant==='premium')return <section className={`me-empty-state ${className}`.trim()} aria-labelledby={titleId}>{eyebrow&&<p className="me-empty-state__eyebrow">{eyebrow}</p>}<h2 className="me-empty-state__title" id={titleId}>{title}</h2>{text&&<p className="me-empty-state__description">{text}</p>}{action&&<div className="me-empty-state__action"><Link className="me-button me-button--outline" to={link}>{action}</Link></div>}</section>;
  return <div className="state"><h2>{title}</h2>{text&&<p>{text}</p>}{action&&<Link className="button outline" to={link}>{action}</Link>}</div>;
}