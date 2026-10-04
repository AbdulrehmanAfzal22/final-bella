import {supabase,unwrap} from '../lib/supabase';

export async function ensureCustomerProfile(){
  return unwrap(await supabase.rpc('ensure_customer_profile'));
}

export async function getSupportInbox(){
  return unwrap(await supabase.rpc('admin_get_support_inbox'))||[];
}

export async function getMySupportConversations(){
  return unwrap(await supabase.rpc('get_my_support_conversations'))||[];
}

export async function startCustomerSupportConversation(message){
  return unwrap(await supabase.rpc('start_customer_support_conversation',{
    p_message:message,
  }));
}

export async function getSupportMessages(conversationId,admin=false){
  if(!conversationId)return [];
  return unwrap(await supabase.rpc(admin?'admin_get_support_messages':'get_my_support_messages',{p_conversation_id:conversationId}))||[];
}

export async function sendSupportMessage(message,conversationId=null,admin=false){
  const functionName=admin?'admin_send_support_message':'send_customer_support_message';
  const args={p_conversation_id:conversationId,p_message:message};
  return unwrap(await supabase.rpc(functionName,args));
}

export async function markSupportConversationRead(conversationId,admin=false){
  if(!conversationId)return;
  return unwrap(await supabase.rpc('mark_support_conversation_read',{
    p_conversation_id:conversationId,
    p_admin:admin,
  }));
}
