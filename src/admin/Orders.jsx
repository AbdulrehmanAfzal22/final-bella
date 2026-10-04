import { useState } from 'react';
import { toast } from 'sonner';
import { useQuery } from '../hooks/useQuery';
import { getAdminOrders, updateOrderStatus, updatePaymentStatus } from '../services/adminOrders';
import { Loading, ErrorState, Empty } from '../components/Feedback';
import { money } from '../lib/supabase';
import { nextOrderStatuses } from '../lib/orderStatus';
import DataTable from '../components/admin/DataTable';
import StatusBadge from '../components/admin/StatusBadge';

export default function Orders() {
  const query = useQuery(getAdminOrders);
  const [busy, setBusy] = useState(null);
  const [filter, setFilter] = useState('');
  const [sort, setSort] = useState({ key: 'created_at', direction: 'desc' });

  async function change(order, status, payment = false) {
    if (status === 'cancelled' && !window.confirm('Cancel this order and return its items to stock?')) return;
    if (payment && !window.confirm('Record payment as '+status+'? This only updates your records; it does not charge or refund money.')) return;
    setBusy(order.id);
    try {
      await (payment ? updatePaymentStatus : updateOrderStatus)(order.id, status);
      await query.refresh();
      toast.success(payment ? 'Payment record updated.' : 'Order status updated.');
    } catch (error) { toast.error(error.message); }
    finally { setBusy(null); }
  }

  const orders = [...(query.data || [])].filter(order => !filter || order.status === filter).sort((a, b) => {
    const direction = sort.direction === 'asc' ? 1 : -1;
    const left = sort.key === 'total_cents' ? a.total_cents : sort.key === 'customer' ? (a.customer?.full_name || a.shipping_address?.full_name || '').toLowerCase() : new Date(a.created_at).getTime();
    const right = sort.key === 'total_cents' ? b.total_cents : sort.key === 'customer' ? (b.customer?.full_name || b.shipping_address?.full_name || '').toLowerCase() : new Date(b.created_at).getTime();
    return (left > right ? 1 : left < right ? -1 : 0) * direction;
  });

  function sortBy(key) {
    setSort(current => ({ key, direction: current.key === key && current.direction === 'asc' ? 'desc' : 'asc' }));
  }

  const columns = [
    { key: 'order', label: 'Order', render: order => <div className="admin-order-cell"><strong>#{order.order_number}</strong></div> },
    { key: 'customer', label: 'Customer', sortable: true, render: order => <span>{order.customer?.full_name||order.shipping_address?.full_name||'Customer'}</span> },
    { key: 'status', label: 'Status', render: order => <div className="admin-status-control"><StatusBadge status={order.status}/><select aria-label={'Update status for order '+order.order_number} value={order.status} disabled={busy===order.id} onChange={event=>change(order,event.target.value)}><option value={order.status}>{order.status}</option>{nextOrderStatuses(order.status).map(status=><option key={status} value={status}>{status.replace('_',' ')}</option>)}</select></div> },
    { key: 'created_at', label: 'Date', sortable: true, render: order => <time dateTime={order.created_at}>{new Date(order.created_at).toLocaleString()}</time> },
    { key: 'total_cents', label: 'Amount', sortable: true, numeric: true, render: order => money(order.total_cents) },
    { key: 'details', label: 'Details', render: order => <details className="admin-order-details"><summary>View order</summary><div className="admin-order-details__panel"><div className="admin-order-details__grid"><section><h3>Delivery address</h3><p>{order.shipping_address?.full_name||order.customer?.full_name}<br/>{order.shipping_address?.line1}<br/>{order.shipping_address?.city} {order.shipping_address?.postal_code}<br/>{order.shipping_address?.country}{order.shipping_address?.phone&&<><br/>Phone: {order.shipping_address.phone}</>}</p></section><label>Payment record (COD)<select aria-label={'Payment for order '+order.order_number} value={order.payment_status} disabled={busy===order.id} onChange={event=>change(order,event.target.value,true)}>{['unpaid','paid','refunded'].map(status=><option key={status} value={status} disabled={status!==order.payment_status&&((status==='paid'&&order.status==='cancelled')||(status==='refunded'&&order.payment_status!=='paid')||(status==='unpaid'&&order.payment_status==='refunded'))}>{status}</option>)}</select></label></div>{order.order_items?.map(item=><div className="admin-order-details__line" key={item.id}><span>{item.product_name} · {item.color}, {item.size} × {item.quantity}</span><strong>{money(item.unit_price_cents*item.quantity)}</strong></div>)}<details className="admin-order-history"><summary>Order history</summary><ol className="order-history">{[...(order.order_status_history||[])].sort((a,b)=>new Date(a.created_at)-new Date(b.created_at)).map(entry=><li key={entry.id}>{entry.status} <time dateTime={entry.created_at}>{new Date(entry.created_at).toLocaleString()}</time></li>)}</ol></details></div></details>},
  ];

  return <>
    <div className="section-heading admin-page-heading"><div><p className="eyebrow">COMMERCE</p><h1>Orders</h1><p className="admin-page-intro">Track fulfillment and update order records.</p></div></div>
    <div className="admin-list-toolbar"><label className="admin-select-field"><span>Status</span><select value={filter} onChange={event=>setFilter(event.target.value)}><option value="">All orders</option>{['pending','confirmed','processing','shipped','delivered','cancelled'].map(status=><option key={status} value={status}>{status.replace('_',' ')}</option>)}</select></label><span className="admin-list-toolbar__count">{orders.length} {orders.length===1?'order':'orders'}</span></div>
    {query.loading&&!query.data?<Loading label="Loading orders…"/>:query.error?<ErrorState error={query.error} retry={query.refresh}/>:!orders.length?<Empty title="No orders found" action={null}/>:<DataTable caption="Orders" columns={columns} rows={orders} rowKey={order=>order.id} sortKey={sort.key} sortDirection={sort.direction} onSort={sortBy} empty="No orders match this status."/>}
  </>;
}
