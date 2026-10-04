import { Link } from 'react-router-dom';
export default function NotFound() { return <section className="page"><p className="eyebrow">404</p><h1>Page not found</h1><p>The page may have moved, or the address may be incomplete.</p><Link className="button" to="/shop">Back to the collection</Link></section>; }
