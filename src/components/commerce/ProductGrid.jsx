import ProductCard from '../ProductCard';

export default function ProductGrid({products=[],className='product-grid',columns}){
  const classes=[className,columns?`product-grid--${columns}`:''].filter(Boolean).join(' ');
  return <div className={classes}>{products.map(product=><ProductCard key={product.id} product={product}/>)}</div>;
}