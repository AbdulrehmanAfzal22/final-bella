import { Link } from "react-router-dom";
import {useAuth} from '../hooks/useAuth';
import { useQuery } from "../hooks/useQuery";
import { getCustomerOrders } from "../services/orders";
import { Loading, ErrorState, Empty } from "../components/Feedback";
import { money, imageUrl } from "../lib/supabase";

export default function Orders() {
  const { user } = useAuth();
  const q = useQuery(() => (user ? getCustomerOrders(user.id) : []), [user?.id]);

  if (q.loading && !q.data) return <Loading label="Loading your orders…" />;
  if (q.error) return <ErrorState error={q.error} retry={q.refresh} />;

  const orders = q.data || [];
  if (!orders.length) {
    return <Empty title="No orders yet" text="Your order history will appear here once you check out." />;
  }

  return (
    <div className="page orders-page">
      <h1>My Orders</h1>
      {orders.map((order) => (
        <article key={order.id} className="order-card">
          <header>
            <div>
              <strong>Order #{order.order_number}</strong>
              <span className={"badge " + order.status}>{order.status}</span>
            </div>
            <span>{new Date(order.created_at).toLocaleDateString()}</span>
          </header>
          {order.order_items?.map((item) => (
            <div key={item.id} className="order-line">
              {item.image_path && <img src={imageUrl(item.image_path)} alt={item.product_name} width="50" />}
              <span>{item.product_name} ({item.color}, {item.size}) × {item.quantity}</span>
            </div>
          ))}
          <footer>
            <strong>{money(order.total_cents)}</strong>
            <Link to={`/order-confirmation/${order.id}`}>View details →</Link>
          </footer>
        </article>
      ))}
    </div>
  );
}
