import { Link } from 'react-router-dom';
export default function About() {
  return <section className="page about-page"><p className="eyebrow">OUR PERSPECTIVE</p><h1>Bella by RT</h1><p className="lead">Your everyday beauty edit. A point of view that is yours.</p><p>Explore beauty favourites by shade, pack size and collection. Save the pieces you love, check availability and follow your order from your account.</p><h2>Shopping with us</h2><p>Prices are shown in USD. Checkout currently offers free shipping and cash on delivery; no online payment is taken.</p><div className="action-row"><Link className="button" to="/shop">Explore the collection</Link><Link className="text-link" to="/contact-support">Contact support</Link></div></section>;
}
