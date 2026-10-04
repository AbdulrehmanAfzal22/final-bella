import {useEffect,useState} from 'react';
import {Save} from 'lucide-react';
import {useQuery} from '../../hooks/useQuery';
import {getAdminSupportMessages,updateSupportStatus} from '../../services/supportService';
import {ErrorState,Loading} from '../Feedback';
import StatusBadge from './StatusBadge';

const statuses=['new','in_progress','resolved','closed'];

export default function SupportDetailsModal({request,onSaved}){
  const [status,setStatus]=useState(request?.status||'new');
  const [note,setNote]=useState(request?.admin_note||'');
  const [reply,setReply]=useState(request?.admin_reply||'');
  const [busy,setBusy]=useState(false);
  const [error,setError]=useState('');
  const messagesQuery=useQuery(()=>request?.id?getAdminSupportMessages(request.id):Promise.resolve([]),[request?.id]);
  useEffect(()=>{setStatus(request?.status||'new');setNote(request?.admin_note||'');setReply(request?.admin_reply||'');setError('');},[request]);
  if(!request)return <section className="support-request-details support-request-details--empty"><p className="eyebrow">REQUEST DETAILS</p><h2>Select a request</h2><p>Customer and complaint details will appear here.</p></section>;

  async function save(event){
    event.preventDefault();
    setBusy(true);setError('');
    try{const updated=await updateSupportStatus(request.id,status,note,reply);await messagesQuery.refresh();await onSaved(updated);}
    catch(saveError){setError(saveError.message||'Unable to update this request.');}
    finally{setBusy(false);}
  }

  return <section className="support-request-details" aria-labelledby="support-request-details-title">
    <header className="support-request-details__heading"><div><p className="eyebrow">REQUEST DETAILS</p><h2 id="support-request-details-title">{request.subject}</h2></div><StatusBadge status={request.status||'new'}/></header>
    <section className="support-request-customer" aria-labelledby="support-customer-title"><h3 id="support-customer-title">Customer Information</h3><dl><div><dt>Name</dt><dd>{request.customer_name}</dd></div><div><dt>Email</dt><dd><a href={`mailto:${request.customer_email}`}>{request.customer_email}</a></dd></div><div><dt>Phone</dt><dd><a href={`tel:${request.customer_phone}`}>{request.customer_phone}</a></dd></div></dl></section>
    <section className="support-request-complaint" aria-labelledby="support-complaint-title"><h3 id="support-complaint-title">Request Details</h3><dl><div><dt>Subject</dt><dd>{request.subject}</dd></div><div><dt>Created date</dt><dd><time dateTime={request.created_at}>{new Date(request.created_at).toLocaleString()}</time></dd></div><div className="support-request-complaint__message"><dt>Message</dt><dd>{request.message}</dd></div></dl></section>
    <section className="support-request-thread" aria-labelledby="support-request-thread-title"><h3 id="support-request-thread-title">Conversation</h3>{messagesQuery.loading&&!messagesQuery.data?<Loading label="Loading conversation…"/>:messagesQuery.error?<ErrorState error={messagesQuery.error} retry={messagesQuery.refresh}/>:<ol>{messagesQuery.data?.map(message=><li className={`support-request-thread__message support-request-thread__message--${message.sender_type}`} key={message.id}><header><strong>{message.sender_type==='admin'?'Bella by RT':'Customer'}</strong><time dateTime={message.created_at}>{new Date(message.created_at).toLocaleString()}</time></header><p>{message.message}</p></li>)}</ol>}</section>
    <form className="support-request-management" onSubmit={save}><h3>Management</h3><label>Status<select value={status} onChange={event=>setStatus(event.target.value)}>{statuses.map(value=><option key={value} value={value}>{value==='in_progress'?'In Progress':value[0].toUpperCase()+value.slice(1)}</option>)}</select></label><label>Internal Admin Note<textarea value={note} onChange={event=>setNote(event.target.value)} rows={4} maxLength={4000} placeholder="Visible only to the Bella by RT support team"/></label><label>Reply to Customer<textarea value={reply} onChange={event=>setReply(event.target.value)} rows={4} maxLength={4000} placeholder="This message will be visible to the customer"/></label>{error&&<p className="error" role="alert">{error}</p>}<button type="submit" className="button" disabled={busy}><Save size={15}/>{busy?'Saving…':'Save Reply'}</button></form>
  </section>;
}
