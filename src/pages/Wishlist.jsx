import { Link } from "react-router-dom";
import { toast } from "sonner";
import { useQuery } from "../hooks/useQuery";
import { useWishlist } from "../hooks/useWishlist";
import {useAuth} from '../hooks/useAuth';
import { Loading, ErrorState, Empty } from "../components/Feedback";
import { money, imageUrl } from "../lib/supabase";

export default function Wishlist() {
  const { user } = useAuth();
  const q = useWishlist(user?.id);

  if (q.loading && !q.data) return <Loading label="Loading your wishlist…" />;
  if (q.error) return <ErrorState error={q.error} retry={q.refresh} />;

  const items = q.items;
  if (!items.length) {
    return <Empty title="Your wishlist is empty" text="Save pieces you love to find them here later." />;
  }

  async function remove(productId) {
    try {
      await q.remove(productId);
    } catch (err) {
      toast.error(err.message);
    }
  }

  return (
    <div className="page wishlist-page">
      <h1>Wishlist</h1>
      <div className="product-grid">
        {items.map((item) => {
          const product = item.products;
          const image = [...(product?.product_images || [])].sort((a, b) => a.position - b.position)[0];
          return (
            <article key={item.product_id} className="product-card">
              <Link to={product ? `/product/${product.id}` : '/shop'} className="product-photo">
                {image ? <img src={imageUrl(image.path)} alt={product?.name} /> : <span className="image-empty">Image unavailable</span>}
              </Link>
              <div className="product-meta">
                <Link to={product ? `/product/${product.id}` : '/shop'}><h3>{product?.name || 'This piece is no longer available'}</h3></Link>
                {product && <span>{money(product.price_cents)}</span>}
              </div>
              <button className="text-button" onClick={() => remove(item.product_id)}>Remove</button>
            </article>
          );
        })}
      </div>
    </div>
  );
}
