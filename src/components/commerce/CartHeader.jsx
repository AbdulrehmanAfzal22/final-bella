import {Link} from 'react-router-dom';

export default function CartHeader({count=0}){
  return <header className="commerce-page-header cart-header">
    <p className="commerce-eyebrow">Bella by RT · Your edit</p>
    <h1>Your Collection</h1>
    <p>{count} {count===1?'considered piece':'considered pieces'} selected for you.</p>
    <Link to="/shop">Continue exploring <span aria-hidden="true">↗</span></Link>
  </header>;
}