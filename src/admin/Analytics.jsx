import { useQuery } from "../hooks/useQuery";
import { getAnalytics } from "../services/analytics";
import { Loading, ErrorState } from "../components/Feedback";
import { money } from "../lib/supabase";
import MetricCard from '../components/admin/MetricCard';
import ChartCard from '../components/admin/ChartCard';
import {CheckCircle2,DollarSign,ShoppingBag} from 'lucide-react';

export default function Analytics() {
  const q = useQuery(() => getAnalytics());

  if (q.loading && !q.data) return <Loading label="Loading analytics…" />;
  if (q.error) return <ErrorState error={q.error} retry={q.refresh} />;
  const data = q.data;

  return (
    <>
      <div className="section-heading"><div><p className="eyebrow">PERFORMANCE</p><h1>Analytics</h1><p className="admin-page-intro">Recorded commerce activity across the store.</p></div></div>
      <div className="admin-metrics-grid admin-metrics-grid--analytics"><MetricCard label="Paid revenue" value={money(data.revenueCents)} detail="Recorded payments" Icon={DollarSign}/><MetricCard label="Orders" value={data.totalOrders} detail="All statuses" Icon={ShoppingBag}/><MetricCard label="Delivered" value={data.completedOrders} detail="Completed orders" Icon={CheckCircle2}/></div>
      <div className="admin-chart-grid"><ChartCard title="Order completion" description="Delivered orders compared with all other recorded statuses." series={[{label:'Delivered',value:data.completedOrders},{label:'Other statuses',value:Math.max(0,data.totalOrders-data.completedOrders)}]}/><ChartCard title="Sales trends" description="Revenue over time" emptyMessage="Time-series data is not included in the current analytics report."/><ChartCard title="Top products" description="Best-performing pieces" emptyMessage="Product-level order breakdown is not included in the current analytics report."/><ChartCard title="Category performance" description="Sales by collection" emptyMessage="Category-level revenue is not included in the current analytics report."/></div>
    </>
  );
}
