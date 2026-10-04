import {useEffect,useState} from 'react';
import {Link} from 'react-router-dom';
import {useAuth} from '../hooks/useAuth';
import {usePageMetadata} from '../hooks/usePageMetadata';
import {useQuery} from '../hooks/useQuery';
import {ErrorState,Loading} from '../components/Feedback';
import SupportChatWorkspace from '../components/SupportChatWorkspace';
import {getMySupportConversations,getSupportMessages,markSupportConversationRead,sendSupportMessage,startCustomerSupportConversation} from '../services/supportService';

const newConversation='new';

export default function ContactSupport(){
  const {user}=useAuth();
  const conversationsQuery=useQuery(getMySupportConversations,[user?.id]);
  const [activeId,setActiveId]=useState(null);
  const [sending,setSending]=useState(false);
  const activeConversation=(conversationsQuery.data||[]).find(conversation=>conversation.id===activeId)||null;
  const messagesQuery=useQuery(async()=>({conversationId:activeId,messages:activeId&&activeId!==newConversation?await getSupportMessages(activeId):[]}),[activeId]);
  const visibleMessages=messagesQuery.data?.conversationId===activeId?messagesQuery.data.messages:[];
  usePageMetadata({title:'Customer Care',description:'Message the Bella by RT customer care team.'});

  useEffect(()=>{
    if(activeId===null&&conversationsQuery.data?.length)setActiveId(conversationsQuery.data[0].id);
  },[activeId,conversationsQuery.data]);

  useEffect(()=>{
    if(!activeId||activeId===newConversation)return;
    markSupportConversationRead(activeId).then(()=>conversationsQuery.refresh()).catch(error=>console.error('Unable to mark support messages as read:',error));
  },[activeId]);

  async function send(message){
    setSending(true);
    try{
      const conversationId=activeId===newConversation
        ?await startCustomerSupportConversation(message)
        :await sendSupportMessage(message,activeId);
      await conversationsQuery.refresh();
      setActiveId(conversationId);
    }finally{setSending(false);}
  }

  if(!user)return <section className="page support-chat-page"><div className="support-chat-signin"><img src="/assets/bella-beauty-editorial.png" alt="Bella by RT beauty editorial"/><div className="support-chat-signin__copy"><p className="eyebrow">BELLA BY RT CUSTOMER CARE</p><h1>Let’s talk.</h1><p>Sign in to message our team and keep your conversation in one place.</p><Link className="button" to="/login?returnTo=%2Fcontact-support">Sign in</Link></div></div></section>;
  if(conversationsQuery.loading&&!conversationsQuery.data)return <Loading label="Loading your messages…"/>;
  if(conversationsQuery.error)return <ErrorState error={conversationsQuery.error} retry={conversationsQuery.refresh}/>;

  return <section className="page support-chat-page" aria-label="Customer support chat">
    <header className="support-chat-page__heading"><div><p className="eyebrow">BELLA BY RT CUSTOMER CARE</p><h1>Your messages</h1></div><p>We’re here to help.</p></header>
    <SupportChatWorkspace
      conversations={conversationsQuery.data||[]}
      activeConversation={activeConversation}
      activeId={activeId}
      onSelect={setActiveId}
      messages={visibleMessages}
      messagesLoading={messagesQuery.loading}
      messagesError={messagesQuery.error}
      retryMessages={messagesQuery.refresh}
      onSend={send}
      onStartConversation={()=>setActiveId(newConversation)}
      startingConversation={activeId===newConversation}
      sending={sending}
      viewer="customer"
      customerName={user.user_metadata?.full_name||user.email?.split('@')[0]||'Customer'}
      customerEmail={user.email||''}
    />
  </section>;
}