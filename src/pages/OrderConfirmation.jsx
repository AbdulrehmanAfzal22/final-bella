import { useParams } from "react-router-dom";
import { useAuth } from "../hooks/useAuth";
import { useQuery } from "../hooks/useQuery";
import { getOrderConfirmation } from "../services/orderConfirmation";
import { Loading, ErrorState, Empty } from "../components/Feedback";
import OrderConfirmationView from "../components/commerce/OrderConfirmation";
import "../styles/commerce-flow.css";

export default function OrderConfirmation() {
  const { orderId } = useParams();
  const { user } = useAuth();
  const query = useQuery(
    () => user ? getOrderConfirmation(orderId, user.id) : null,
    [user?.id, orderId]
  );

  if (query.loading && !query.data) return <Loading label="Loading your order…" />;
  if (query.error) return <ErrorState error={query.error} retry={query.refresh} />;
  if (!query.data) return <div className="page order-confirmation-experience">
    <Empty variant="premium" eyebrow="Bella by RT · Order details" title="Order not found" text="Check your order history for your recent orders." link="/orders" action="My orders" />
  </div>;

  return <div className="page order-confirmation-experience">
    <OrderConfirmationView order={query.data} />
  </div>;
}
