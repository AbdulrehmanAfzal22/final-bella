import {useEffect,useState} from 'react';
import {useQuery} from '../hooks/useQuery';
import {getSupportInbox,getSupportMessages,markSupportConversationRead,sendSupportMessage} from '../services/supportService';
import {ErrorState,Loading} from '../components/Feedback';
import SupportChatWorkspace from '../components/SupportChatWorkspace';

export default function SupportRequests(){
  const inboxQuery=useQuery(getSupportInbox);
  const [activeId,setActiveId]=useState(null);
  const [sending,setSending]=useState(false);
  const activeConversation=(inboxQuery.data||[]).find(conversation=>conversation.id===activeId)||null;
  const messagesQuery=useQuery(async()=>({conversationId:activeId,messages:activeId?await getSupportMessages(activeId,true):[]}),[activeId]);
  const visibleMessages=messagesQuery.data?.conversationId===activeId?messagesQuery.data.messages:[];

  useEffect(()=>{
    if(!activeId)return;
    markSupportConversationRead(activeId,true).then(()=>inboxQuery.refresh()).catch(error=>console.error('Unable to mark support messages as read:',error));
  },[activeId]);

  async function send(message){
    setSending(true);
    try{
      await sendSupportMessage(message,activeId,true);
      await Promise.all([messagesQuery.refresh(),inboxQuery.refresh()]);
    }finally{setSending(false);}
  }

  if(inboxQuery.loading&&!inboxQuery.data)return <Loading label="Loading support inbox…"/>;
  if(inboxQuery.error)return <ErrorState error={inboxQuery.error} retry={inboxQuery.refresh}/>;
  return <section className="support-inbox-page">
    <header className="section-heading admin-page-heading"><div><p className="eyebrow">CUSTOMER CARE</p><h2>Support Inbox</h2><p className="admin-page-intro">Private conversations with Bella by RT customers.</p></div><span className="support-inbox-page__count">{inboxQuery.data?.length||0} customers</span></header>
    <SupportChatWorkspace
      conversations={inboxQuery.data||[]}
      activeConversation={activeConversation}
      activeId={activeId}
      onSelect={setActiveId}
      messages={visibleMessages}
      messagesLoading={messagesQuery.loading}
      messagesError={messagesQuery.error}
      retryMessages={messagesQuery.refresh}
      onSend={send}
      sending={sending}
      viewer="admin"
    />
  </section>;
}