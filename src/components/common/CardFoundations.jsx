import {Link} from 'react-router-dom';

function Media({image,alt='',className=''}){
  return image?<img className={className} src={image} alt={alt} loading="lazy" decoding="async"/>:null;
}

export function ProductCardFoundation({to,image,alt='',name,category,price,children,className=''}){
  const ImageLink=to?Link:'div';
  const linkProps=to?{to,'aria-label':`View ${name}`}:{'aria-hidden':true};
  return <article className={`me-product-card ${className}`.trim()}>
    <ImageLink className="me-product-card__media" {...linkProps}><Media image={image} alt={alt||name}/></ImageLink>
    <div className="me-product-card__details"><div className="me-product-card__name">{to?<Link to={to}>{name}</Link>:name}</div>{price!==undefined&&<span className="me-product-card__price">{price}</span>}{category&&<p className="me-product-card__category">{category}</p>}{children}</div>
  </article>;
}

export function CollectionCardFoundation({to,image,alt='',title,children,className=''}){
  const CardLink=to?Link:'article';
  const linkProps=to?{to,'aria-label':`Explore ${title}`}:{};
  return <CardLink className={`me-collection-card ${className}`.trim()} {...linkProps}><Media image={image} alt={alt||title} className="me-collection-card__image"/><span className="me-collection-card__shade" aria-hidden="true"/><span className="me-collection-card__content"><span className="me-collection-card__title">{title}</span>{children}</span></CardLink>;
}

export function ContentCardFoundation({as:Element='article',className='',children,...props}){
  return <Element className={`me-content-card ${className}`.trim()} {...props}>{children}</Element>;
}