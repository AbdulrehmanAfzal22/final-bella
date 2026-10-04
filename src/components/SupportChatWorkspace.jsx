import {useState} from 'react';
import {ArrowLeft,ArrowUp,MessageCircle} from 'lucide-react';
import {ErrorState,Loading} from './Feedback';

const clock=value=>value?new Intl.DateTimeFormat(undefined,{hour:'numeric',minute:'2-digit'}).format(new Date(value)):'';
const shortDate=value=>value?new Intl.DateTimeFormat(undefined,{month:'short',day:'numeric'}).format(new Date(value)):'';
const initials=name=>String(name||'C').trim().split(/\s+/).slice(0,2).map(part=>part[0]).join('').toUpperCase();

export default function SupportChatWorkspace({conversations,activeConversation,activeId,onSelect,messages,messagesLoading,messagesError,retryMessages,onSend,onStartConversation,startingConversation=false,sending,viewer,customerName,customerEmail}){
  const [draft,setDraft]=useState('');
  const [sendError,setSendError]=useState('');
  const [mobileChatOpen,setMobileChatOpen]=useState(false);
  const activeName=viewer==='admin'?activeConversation?.customer_name:customerName;
  const activeEmail=viewer==='admin'?activeConversation?.customer_email:customerEmail;
  const isOpen=!!activeId;

  function selectConversation(id){
    onSelect(id);
    if(viewer==='customer')setMobileChatOpen(Boolean(id));
  }

  function backToConversations(){
    onSelect(null);
    if(viewer==='customer')setMobileChatOpen(false);
  }

  async function submit(event){
    event.preventDefault();
    const message=draft.trim();
    if(!message||sending)return;
    setSendError('');
    try{await onSend(message);setDraft('');}
    catch(error){setSendError(error.message||'Your message could not be sent. Please try again.');}
  }

  return <div className={`support-chat${isOpen?' is-chat-open':''}${viewer==='customer'&&mobileChatOpen?' is-mobile-chat-open':''}`}>
    <aside className="support-chat__sidebar" aria-label="Conversation list">
      <header className="support-chat__sidebar-heading"><div><p className="eyebrow">MESSAGES</p><h2>{viewer==='admin'?'Customers':'Conversations'}</h2></div><span>{conversations.length}</span></header>
      <nav className="support-chat__list">
        {conversations.map(conversation=>{
          const name=viewer==='admin'?conversation.customer_name:customerName;
          const preview=conversation.latest_message||'Start a conversation with our team';
          const previewSender=conversation.latest_sender_type==='admin'?'Bella by RT: ':conversation.latest_sender_type==='customer'&&viewer==='admin'?'You: ':'';
          return <button className={`support-chat__list-item${conversation.id===activeId?' is-selected':''}`} type="button" key={conversation.id} onClick={()=>selectConversation(conversation.id)} aria-current={conversation.id===activeId?'true':undefined}>
            <span className="support-chat__avatar">{initials(name)}</span>
            <span className="support-chat__list-copy"><span className="support-chat__list-top"><strong>{name||'Customer'}</strong><time dateTime={conversation.latest_message_created_at||conversation.updated_at}>{shortDate(conversation.latest_message_created_at||conversation.updated_at)}</time></span>{conversation.subject&&<span className="support-chat__list-subject">{conversation.subject}</span>}<span className="support-chat__list-email">{viewer==='admin'?conversation.customer_email:customerEmail}</span><span className="support-chat__preview">{previewSender}{preview}</span></span>
            {Number(conversation.unread_count)>0&&<span className="support-chat__unread" aria-label={`${conversation.unread_count} unread messages`}>{conversation.unread_count}</span>}
          </button>;
        })}
        {!conversations.length&&<div className="support-chat__list-empty"><p>{viewer==='customer'?'You have no conversations yet.':'Your conversations will appear here.'}</p>{viewer==='customer'&&<button className="support-chat__start" type="button" onClick={()=>{onStartConversation();setMobileChatOpen(true);}}>Start a Conversation</button>}</div>}
      </nav>
      {viewer==='customer'&&<footer className="support-chat__identity"><span className="support-chat__avatar support-chat__avatar--small">{initials(customerName)}</span><span><strong>{customerName}</strong><small>{customerEmail}</small></span></footer>}
    </aside>
    <section className="support-chat__thread" aria-label={activeConversation||startingConversation?'Active conversation':'No conversation selected'}>
      {activeConversation||startingConversation? <>
        <header className="support-chat__thread-heading">
          <button className="support-chat__back" type="button" aria-label="Back to conversations" onClick={backToConversations}><ArrowLeft size={19}/><span>Conversations</span></button>
          <span className="support-chat__avatar">{initials(activeName)}</span>
          <span className="support-chat__thread-person"><strong>{activeName||'Customer'}</strong><small>{activeConversation?.subject||activeEmail}</small></span>
          <span className="support-chat__online-mark" aria-label="Customer support" title="Customer support"/>
        </header>
        <div className="support-chat__messages" aria-live="polite">
          {messagesLoading&&!messages.length?<Loading label="Loading conversation…"/>:messagesError?<ErrorState error={messagesError} retry={retryMessages}/>:messages.length?messages.map(message=>{
            return <article className={`support-chat__message support-chat__message--${message.sender_type}`} key={message.id}>
              <p>{message.message}</p><time dateTime={message.created_at}>{clock(message.created_at)}</time>
            </article>;
          }):<div className="support-chat__empty-thread"><MessageCircle size={25}/><p>No messages yet</p><span>Send a message to begin this conversation.</span></div>}
        </div>
        <form className="support-chat__composer" onSubmit={submit}>
          {sendError&&<p className="support-chat__error" role="alert">{sendError}</p>}
          <label className="support-chat__input-wrap"><span className="sr-only">Write a message</span><textarea name="support-message" value={draft} onChange={event=>setDraft(event.target.value)} onKeyDown={event=>{if(event.key==='Enter'&&!event.shiftKey){event.preventDefault();event.currentTarget.form.requestSubmit();}}} placeholder="Write a message..." rows="1" maxLength="4000" autoComplete="off" autoCorrect="off" autoCapitalize="sentences" enterKeyHint="send" spellCheck="false" data-gramm="false" data-lpignore="true" data-1p-ignore="true" required/></label>
          <button className="support-chat__send" type="submit" aria-label="Send message" title="Send message" disabled={sending||!draft.trim()}><ArrowUp size={20} strokeWidth={1.8}/></button>
        </form>
      </>:<div className={`support-chat__welcome${viewer==='customer'?' support-chat__welcome--concierge':''}`}>
        {viewer==='customer'&&<img src="/assets/bella-beauty-editorial.png" alt="Bella by RT beauty editorial"/>}
        <div className="support-chat__welcome-copy"><p className="eyebrow">BELLA BY RT · PERSONAL SERVICE</p><h2>{viewer==='admin'?'Choose a customer':'Welcome to Bella by RT Customer Care'}</h2><span>{viewer==='admin'?'Select a conversation to read and reply.':'Your personal styling and support assistant'}</span></div>
      </div>}
    </section>
  </div>;
}