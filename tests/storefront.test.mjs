import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { productOptions, galleryImages } from '../src/lib/productOptions.js';
import { nextOrderStatuses, recordedRevenue } from '../src/lib/orderStatus.js';
import { uuid } from '../src/lib/uuid.js';
import { getReviewStatus } from '../src/lib/reviewStatus.js';

test('HTTP preview fallback generates valid version 4 identifiers', () => {
  const fallback = { getRandomValues: array => globalThis.crypto.getRandomValues(array) };
  const first = uuid(fallback), second = uuid(fallback);
  assert.match(first,/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  assert.notEqual(first,second);
});

const variants = [
  {color:'Ink',size:'M',active:true,stock:2},
  {color:'Ink',size:'XL',active:true,stock:0},
  {color:'Clay',size:'L',active:true,stock:1},
  {color:'Clay',size:'S',active:false,stock:5},
];
test('Initial product selection shows only sizes for the displayed colour', () => {
  const result = productOptions(variants);
  assert.equal(result.colour,'Ink');
  assert.deepEqual(result.variants.map(v=>v.size),['M','XL']);
});
test('Switching colour excludes previous-colour and inactive sizes', () => {
  const result = productOptions(variants,' clay ');
  assert.equal(result.colour,'Clay');
  assert.deepEqual(result.variants.map(v=>v.size),['L']);
});
test('A removed colour falls back to an available colour', () => {
  assert.equal(productOptions(variants,'Green').colour,'Ink');
  assert.equal(productOptions([]).colour,'');
});
test('Colour photography is prioritised and other colour photography hidden', () => {
  const images=[{path:'ink',color:'Ink',position:0},{path:'clay',color:' clay ',position:2},{path:'care',color:null,position:1}];
  assert.deepEqual(galleryImages(images,'Clay').map(i=>i.path),['clay','care']);
  assert.deepEqual(galleryImages(images,'Green').map(i=>i.path),['care']);
  assert.deepEqual(images.map(i=>i.path),['ink','clay','care']);
});
test('Gallery remains usable when no colour-labelled photography exists', () => {
  assert.deepEqual(galleryImages([{path:'cover',position:0}],'Ink').map(i=>i.path),['cover']);
  assert.deepEqual(galleryImages(undefined,'Ink'),[]);
});
test('Closed orders cannot reopen and shipped orders cannot be cancelled', () => {
  assert.deepEqual(nextOrderStatuses('shipped'),['delivered']);
  assert.deepEqual(nextOrderStatuses('delivered'),[]);
  assert.deepEqual(nextOrderStatuses('cancelled'),[]);
  assert.ok(nextOrderStatuses('pending').includes('cancelled'));
  assert.ok(!nextOrderStatuses('processing').includes('confirmed'));
});
test('Revenue excludes unpaid and refunded orders', () => {
  assert.equal(recordedRevenue([{payment_status:'unpaid',total_cents:20000},{payment_status:'paid',total_cents:5000},{payment_status:'refunded',total_cents:7000}]),5000);
});

test('Review status uses API moderation values and falls back to approval flag',()=>{
  assert.equal(getReviewStatus({approved:true}),'approved');
  assert.equal(getReviewStatus({approved:false}),'pending');
  assert.equal(getReviewStatus({approved:false,status:'spam'}),'spam');
  assert.equal(getReviewStatus({approved:true},'rejected'),'rejected');
});

test('Support inbox migration creates profile-linked conversations and chat messages',()=>{
  const migration=readFileSync(new URL('../supabase/migrations/20260930120000_whatsapp_support_inbox.sql',import.meta.url),'utf8');
  assert.match(migration,/ALTER TABLE public\.profiles ADD COLUMN IF NOT EXISTS email text/);
  assert.match(migration,/CREATE TABLE public\.support_conversations[\s\S]*customer_id uuid NOT NULL UNIQUE REFERENCES public\.profiles\(id\)/);
  assert.match(migration,/CREATE TABLE public\.support_messages[\s\S]*conversation_id uuid NOT NULL REFERENCES public\.support_conversations\(id\)[\s\S]*sender_type text NOT NULL CHECK \(sender_type IN \('customer', 'admin'\)\)/);
  assert.match(migration,/c\.customer_id = auth\.uid\(\)/);
  assert.match(migration,/private\.is_admin\(\)/);
  assert.match(migration,/customer_read_at/);
  assert.match(migration,/admin_read_at/);
  assert.match(migration,/public\.ensure_customer_profile\(\)/);
});

test('Support messages are gated by ownership and admin checks',()=>{
  const migration=readFileSync(new URL('../supabase/migrations/20260930120000_whatsapp_support_inbox.sql',import.meta.url),'utf8');
  assert.match(migration,/CREATE POLICY support_conversations_read[\s\S]*customer_id = \(SELECT auth\.uid\(\)\) OR \(SELECT private\.is_admin\(\)\)/);
  assert.match(migration,/CREATE POLICY support_messages_read[\s\S]*c\.customer_id = \(SELECT auth\.uid\(\)\) OR \(SELECT private\.is_admin\(\)\)/);
  assert.match(migration,/Support conversation not found' USING ERRCODE = '42501'/);
  assert.match(migration,/IF NOT private\.is_admin\(\) THEN[\s\S]*RAISE EXCEPTION 'Admin access required'/);
});

test('Customer first message reuses the one auth-linked support conversation',()=>{
  const migration=readFileSync(new URL('../supabase/migrations/20261001120000_restore_single_customer_support_thread.sql',import.meta.url),'utf8');
  const page=readFileSync(new URL('../src/pages/ContactSupport.jsx',import.meta.url),'utf8');
  const workspace=readFileSync(new URL('../src/components/SupportChatWorkspace.jsx',import.meta.url),'utf8');
  assert.match(migration,/CREATE UNIQUE INDEX IF NOT EXISTS support_conversations_customer_id_uidx[\s\S]*ON public\.support_conversations\(customer_id\)/);
  assert.match(migration,/first_value\(id\) OVER \([\s\S]*PARTITION BY customer_id/);
  assert.match(migration,/UPDATE public\.support_messages AS m[\s\S]*SET conversation_id = merge_map\.canonical_id/);
  assert.match(migration,/CREATE OR REPLACE FUNCTION public\.start_customer_support_conversation\(p_message text\)/);
  assert.match(migration,/public\.ensure_customer_profile\(\)/);
  assert.match(migration,/ON CONFLICT \(customer_id\) DO NOTHING/);
  assert.match(migration,/SELECT c\.id INTO conversation_id[\s\S]*WHERE c\.customer_id = current_user_id/);
  assert.match(migration,/INSERT INTO public\.support_messages\(conversation_id, sender_type, message\)[\s\S]*VALUES \(conversation_id, 'customer', clean_message\)/);
  assert.match(migration,/DROP FUNCTION IF EXISTS public\.create_customer_support_conversation\(text, text\)/);
  assert.match(page,/startCustomerSupportConversation\(message\)/);
  assert.match(page,/startingConversation=\{activeId===newConversation\}/);
  assert.match(workspace,/Start a Conversation/);
  assert.doesNotMatch(page,/support-start-modal|createCustomerSupportConversation/);
});
