import { useQuery } from "../hooks/useQuery";
import { getCustomers } from "../services/customers";
import { Loading, ErrorState, Empty } from "../components/Feedback";
import DataTable from "../components/admin/DataTable";
import {money} from '../lib/supabase';

export default function Customers() {
  const query = useQuery(getCustomers);
  if (query.loading && !query.data) return <Loading label="Loading customers…" />;
  if (query.error) return <ErrorState error={query.error} retry={query.refresh} />;
  const customers = query.data || [];
  const columns = [
    {
      key: "customer",
      label: "Customer",
      render: (customer) => (
        <div className="admin-customer-cell">
          <span>{(customer.full_name || "M").slice(0, 1).toUpperCase()}</span>
          <div>
            <strong>{customer.full_name || "Unnamed customer"}</strong>
            <small>Bella by RT customer</small>
          </div>
        </div>
      ),
    },
    { key: "orders", label: "Orders", numeric: true, render: (customer) => customer.orders?.length || 0 },
    {
      key: "spent",
      label: "Order value",
      numeric: true,
      render: (customer) => {
        const total = customer.orders?.reduce((sum, order) => sum + (order.total_cents || 0), 0);
        return total ? money(total) : "-";
      },
    },
    {
      key: "activity",
      label: "Last activity",
      render: (customer) => {
        const latest = [...(customer.orders || [])].sort(
          (a, b) => new Date(b.created_at) - new Date(a.created_at)
        )[0];
        return latest ? (
          <time dateTime={latest.created_at}>{new Date(latest.created_at).toLocaleDateString()}</time>
        ) : "No orders yet";
      },
    },
  ];
  return (
    <>
      <div className="section-heading admin-page-heading">
        <div>
          <p className="eyebrow">RELATIONSHIPS</p>
          <h1>Customers</h1>
          <p className="admin-page-intro">Customer profiles and order activity.</p>
        </div>
      </div>
      {customers.length ? (
        <DataTable
          caption="Customers"
          columns={columns}
          rows={customers}
          rowKey={(customer) => customer.id}
          empty="No customer records."
        />
      ) : (
        <Empty title="No customers yet" action={null} />
      )}
    </>
  );
}
