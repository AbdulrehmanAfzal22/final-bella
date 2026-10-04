import { Link } from "react-router-dom";
import { toast } from "sonner";
import { useAuth } from "../hooks/useAuth";
import { useCart } from "../hooks/useCart";
import { Loading, ErrorState, Empty } from "../components/Feedback";
import CartHeader from "../components/commerce/CartHeader";
import LuxuryCartItem from "../components/commerce/LuxuryCartItem";
import CartSummary from "../components/commerce/CartSummary";
import "../styles/commerce-flow.css";

export default function Cart() {
  const { user } = useAuth();
  const query = useCart(user?.id);

  if (query.loading && !query.data) return <Loading label="Opening your collection…" />;
  if (query.error) return <ErrorState error={query.error} retry={query.refresh} />;

  const items = query.data || [];
  const unavailable = items.some(
    (item) =>
      !item.product_variants?.products ||
      !item.product_variants.active ||
      item.product_variants.stock < item.quantity
  );
  const total = items.reduce(
    (sum, item) =>
      sum + (item.product_variants?.products?.price_cents || 0) * item.quantity,
    0
  );

  async function changeQuantity(variantId, quantity) {
    await query.setQuantity(variantId, quantity);
  }

  async function removeItem(variantId) {
    try {
      await query.remove(variantId);
    } catch (error) {
      toast.error(error.message);
    }
  }

  if (!items.length) {
    return (
      <div className="page cart-experience cart-experience--empty">
        <Empty variant="premium" eyebrow="Bella by RT · Your edit" title="Your collection awaits." text="Considered pieces, saved for the moments that matter." link="/shop" action="Continue shopping"/>
      </div>
    );
  }

  return (
    <div className="page cart-experience">
      <CartHeader count={items.reduce((sum, item) => sum + (Number(item.quantity) || 0), 0)} />
      <div className="cart-experience__layout">
        <section className="cart-experience__items" aria-label="Your collection">
          {items.map((item) => (
            <LuxuryCartItem
              key={item.variant_id}
              item={item}
              onQuantityChange={changeQuantity}
              onRemove={removeItem}
            />
          ))}
        </section>
        <CartSummary subtotal={total} unavailable={unavailable} />
      </div>
      <p className="cart-experience__continue">
        <Link to="/shop">Continue exploring the collection</Link>
      </p>
    </div>
  );
}
