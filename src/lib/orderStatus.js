export const orderStatuses = ['pending', 'confirmed', 'processing', 'shipped', 'delivered'];

export function nextOrderStatuses(status) {
  if (status === 'cancelled' || status === 'delivered') return [];
  const index = orderStatuses.indexOf(status);
  if (index < 0) return [];
  return [...orderStatuses.slice(index + 1), ...(status === 'shipped' ? [] : ['cancelled'])];
}

export function recordedRevenue(orders = []) {
  return orders.filter(order => order.payment_status === 'paid')
    .reduce((sum, order) => sum + Number(order.total_cents || 0), 0);
}
