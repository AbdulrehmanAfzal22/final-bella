const labels={new:'New',pending:'Pending',confirmed:'Confirmed',processing:'Processing',shipped:'Shipped',delivered:'Delivered',cancelled:'Cancelled',draft:'Draft',published:'Published',archived:'Archived',open:'Open',in_progress:'In Progress',resolved:'Resolved',closed:'Closed',paid:'Paid',unpaid:'Unpaid',refunded:'Refunded','in-stock':'In stock','low-stock':'Low stock','out-of-stock':'Out of stock'};

export default function StatusBadge({status}){
  const normal=String(status||'unknown').toLowerCase();
  return <span className={`admin-status-badge admin-status-badge--${normal.replace(/[^a-z0-9]+/g,'-')}`}><span aria-hidden="true"/>{labels[normal]||normal.replaceAll('_',' ')}</span>;
}