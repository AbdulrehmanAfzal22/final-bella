import ProductShowcase from './ProductShowcase';

export default function NewArrivals({products=[],loading=false,error,retry}){
  const featured=products.filter(product=>product.featured);
  return <ProductShowcase className="home-new-arrivals" products={(featured.length?featured:products).slice(0,10)} loading={loading} error={error} retry={retry}/>;
}
