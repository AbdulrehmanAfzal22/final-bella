import { supabase, unwrap } from '../lib/supabase';

export const getTickets = async () => unwrap(await supabase.from('support_tickets')
  .select('*,orders(order_number)').order('updated_at', { ascending: false }));
export const getTicketMessages = async id => unwrap(await supabase.from('support_messages')
  .select('id,sender_role,body,created_at').eq('ticket_id', id).order('created_at'));
export const getSupportOrders = async userId => unwrap(await supabase.from('orders')
  .select('id,order_number').eq('user_id', userId).order('created_at', { ascending: false }));
export const createTicket = async ({ subject, body, orderId }) => unwrap(await supabase.rpc('create_support_ticket', {
  p_subject: subject.trim(), p_body: body.trim(), p_order_id: orderId || null,
}));
export const replyToTicket = async (id, body) => unwrap(await supabase.rpc('add_support_message', { p_ticket_id: id, p_body: body.trim() }));
export const setTicketStatus = async (id, status) => unwrap(await supabase.rpc('set_ticket_status', { p_ticket_id: id, p_status: status }));
