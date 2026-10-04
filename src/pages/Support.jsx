import { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { toast } from 'sonner';
import {useAuth} from '../hooks/useAuth';
import { useQuery } from '../hooks/useQuery';
import { getTickets, getTicketMessages, getSupportOrders, createTicket, replyToTicket, setTicketStatus } from '../services/support';
import { Loading, ErrorState, Empty } from '../components/Feedback';

function TicketThread({ ticket, administration, onChange }) {
  const q = useQuery(() => getTicketMessages(ticket.id), [ticket.id]);
  const [body, setBody] = useState('');
  const [busy, setBusy] = useState(false);
  async function reply(event) {
    event.preventDefault(); setBusy(true);
    try { await replyToTicket(ticket.id, body); setBody(''); await q.refresh(); await onChange(); }
    catch (error) { toast.error(error.message); }
    finally { setBusy(false); }
  }
  async function changeStatus(status) {
    setBusy(true);
    try { await setTicketStatus(ticket.id, status); await onChange(); }
    catch (error) { toast.error(error.message); }
    finally { setBusy(false); }
  }
  return <section className="support-thread" aria-label="Conversation">
    <h2>{ticket.subject}</h2><p className="muted">{ticket.orders ? 'Order #'+ticket.orders.order_number : 'General enquiry'}</p>
    {administration ? <label>Ticket status<select value={ticket.status} disabled={busy} onChange={e=>changeStatus(e.target.value)}>{['open','in_progress','resolved','closed'].map(status=><option key={status} value={status}>{status.replace('_',' ')}</option>)}</select></label> : <p className="badge">{ticket.status.replace('_',' ')}</p>}
    {q.loading && !q.data ? <Loading /> : q.error ? <ErrorState error={q.error} retry={q.refresh} /> : <div className="support-messages">{(q.data || []).map(message=><article className={'support-message '+message.sender_role} key={message.id}><header><strong>{message.sender_role === 'admin' ? 'Bella by RT support' : 'Customer'}</strong><time dateTime={message.created_at}>{new Date(message.created_at).toLocaleString()}</time></header><p>{message.body}</p></article>)}</div>}
    <form onSubmit={reply}><label>Reply<textarea value={body} required maxLength={4000} rows={4} onChange={e=>setBody(e.target.value)} /></label><button className="button" disabled={busy || !body.trim()}>{busy ? 'Sending...' : 'Send reply'}</button></form>
  </section>;
}

export default function Support({ administration = false }) {
  const { user } = useAuth();
  const [params, setParams] = useSearchParams();
  const q = useQuery(() => Promise.all([getTickets(), administration ? [] : getSupportOrders(user.id)]), [user.id, administration]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  if (q.loading && !q.data) return <Loading label="Loading support..." />;
  if (q.error) return <ErrorState error={q.error} retry={q.refresh} />;
  const [tickets, orders] = q.data || [[], []];
  const selected = tickets.find(ticket => ticket.id === params.get('ticket'));
  async function submit(event) {
    event.preventDefault(); const form = event.currentTarget;
    const data = Object.fromEntries(new FormData(form)); setBusy(true); setError('');
    try { const id = await createTicket(data); await q.refresh(); form.reset(); setParams({ ticket: id }); toast.success('Support request sent.'); }
    catch (err) { setError(err.message); }
    finally { setBusy(false); }
  }
  return <div className={administration ? 'support-page' : 'page support-page'}>
    <div className="section-heading"><h1>{administration ? 'Customer Support' : 'Help & complaints'}</h1>{!administration && selected && <button className="button outline" onClick={()=>setParams({})}>New request</button>}</div>
    <div className="support-grid"><nav className="support-list" aria-label="Support requests">{tickets.length ? tickets.map(ticket=><button className={'support-ticket '+(selected?.id===ticket.id?'selected':'')} key={ticket.id} onClick={()=>setParams({ticket:ticket.id})}><strong>{ticket.subject}</strong><span>{ticket.status.replace('_',' ')}</span><small>{new Date(ticket.updated_at).toLocaleDateString()}</small></button>) : <p className="muted">No support requests yet.</p>}</nav>
      {selected ? <TicketThread key={selected.id} ticket={selected} administration={administration} onChange={q.refresh} /> : administration ? <Empty title="Select a support request" action={null} /> : <form className="support-form" onSubmit={submit}><h2>New request</h2><label>Related order<select name="orderId" defaultValue={params.get('order') || ''}><option value="">General enquiry</option>{orders.map(order=><option value={order.id} key={order.id}>Order #{order.order_number}</option>)}</select></label><label>Subject<input name="subject" required maxLength={200} /></label><label>Message<textarea name="body" required rows={6} maxLength={4000} /></label>{error && <p className="error" role="alert">{error}</p>}<button className="button" disabled={busy}>{busy ? 'Sending...' : 'Send request'}</button></form>}
    </div>
  </div>;
}
