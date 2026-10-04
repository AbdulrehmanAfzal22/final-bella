import { useQuery } from "../hooks/useQuery";
import { getDashboardMetrics } from "../services/dashboard";
import { Loading, ErrorState } from "../components/Feedback";
import { money } from "../lib/supabase";
import {Boxes,CircleAlert,DollarSign,Package,ShoppingCart,Users} from 'lucide-react';
import MetricCard from '../components/admin/MetricCard';
import ChartCard from '../components/admin/ChartCard';

export default function Dashboard() {
  const q = useQuery(() => getDashboardMetrics());

  if (q.loading && !q.data) return <Loading label="Loading dashboard…" />;
  if (q.error) return <ErrorState error={q.error} retry={q.refresh} />;
  const m = q.data;

  return (
    <>
      <div className="section-heading"><div><p className="eyebrow">STUDIO OVERVIEW</p><h1>Dashboard</h1><p className="admin-page-intro">A clear view of Bella by RT operations.</p></div></div>
      <div className="admin-metrics-grid">
        <MetricCard label="Paid revenue" value={money(m.revenueCents)} detail="Recorded payments" Icon={DollarSign}/>
        <MetricCard label="Orders" value={m.orders} detail="All order statuses" Icon={ShoppingCart} href="/admin/orders"/>
        <MetricCard label="Customers" value={m.customers} detail="Registered profiles" Icon={Users} href="/admin/customers"/>
        <MetricCard label="Products" value={m.products} detail="Catalog records" Icon={Package} href="/admin/products"/>
        <MetricCard label="Inventory units" value={m.inventory} detail="Active variant stock" Icon={Boxes} href="/admin/inventory"/>
        <MetricCard label="Inventory alerts" value="Review" detail="Check low-stock variants" Icon={CircleAlert} href="/admin/inventory"/>
      </div>
      <div className="admin-chart-grid admin-dashboard-charts"><ChartCard title="Operations at a glance" description="Current record counts from the studio overview." series={[{label:'Products',value:m.products},{label:'Customers',value:m.customers},{label:'Orders',value:m.orders}]}/><ChartCard title="Inventory attention" description="Stock levels and availability" emptyMessage="Open Inventory to review variant-level stock and low-stock alerts."/></div>
    </>
  );
}
