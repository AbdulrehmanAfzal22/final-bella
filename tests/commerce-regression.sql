-- Run with the project SQL executor, not as a migration. Every fixture is rolled back.
-- Uses the existing QA identities; no passwords or memberships are modified.
DO $suite$
DECLARE
  r jsonb:='[]'; pid uuid:=gen_random_uuid(); vid uuid:=gen_random_uuid(); cid uuid:=gen_random_uuid();
  request_id uuid:=gen_random_uuid(); oid uuid; tid uuid; got record;
  support_thread_id uuid; support_thread_followup_id uuid; support_other_subject_id uuid;
  support_subject text:='ROLLBACK QA SUPPORT '||gen_random_uuid()::text;
  support_other_subject text:='ROLLBACK QA SUPPORT OTHER '||gen_random_uuid()::text;
  customer uuid:='887ec16d-c4fe-468f-a20c-da799b0efcad';
  other_customer uuid:='736975b4-1c86-4699-bae2-05d1362b1259';
  admin_id uuid:='343a1900-bfeb-4861-90b3-ff2025bd9874';
  address jsonb:='{"full_name":"ROLLBACK QA","line1":"TEST ONLY","city":"TEST","country":"TEST","total_cents":1}';
BEGIN
 BEGIN
  CREATE TEMP TABLE qa_regression_scope(value int);
  EXECUTE $helper$
    CREATE FUNCTION pg_temp.check_regression(label text,statement text,expected_state text DEFAULT NULL)
    RETURNS jsonb LANGUAGE plpgsql AS $body$
    DECLARE actual boolean;
    BEGIN
      EXECUTE statement INTO actual;
      RETURN jsonb_build_object('test',label,'pass',expected_state IS NULL AND coalesce(actual,false));
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('test',label,'pass',SQLSTATE=expected_state,'sqlstate',SQLSTATE,'error',SQLERRM);
    END $body$;
  $helper$;
  INSERT INTO public.categories(id,name,slug) VALUES(cid,'ROLLBACK QA - NOT FOR SALE','rollback-qa-'||replace(cid::text,'-',''));
  INSERT INTO public.products(id,name,price_cents,category_id,status) VALUES(pid,'ROLLBACK QA - NOT FOR SALE',12500,cid,'published');
  INSERT INTO public.product_variants(id,product_id,color,size,stock) VALUES(vid,pid,'Ink','M',3);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated')::text,true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  r:=r||pg_temp.check_regression('Add beyond stock rejected',format('SELECT public.add_to_cart(%L,4) IS NULL',vid),'23514');
  r:=r||pg_temp.check_regression('Null quantity rejected',format('SELECT public.add_to_cart(%L,NULL) IS NULL',vid),'22023');
  r:=r||pg_temp.check_regression('Empty cart checkout rejected',format('SELECT count(*)=1 FROM public.checkout_order(%L,%L)',address,request_id),'P0001');
  PERFORM public.add_to_cart(vid,2);
  r:=r||pg_temp.check_regression('Invalid address rejected',format('SELECT count(*)=1 FROM public.checkout_order(''{}'',%L)',request_id),'22023');
  r:=r||pg_temp.check_regression('Customer shipping override rejected',format('SELECT count(*)=1 FROM public.process_checkout(%L,999)',address),'22023');
  r:=r||pg_temp.check_regression('Null request ID rejected',format('SELECT count(*)=1 FROM public.checkout_order(%L,NULL)',address),'22023');
  EXECUTE 'RESET ROLE';
  UPDATE public.product_variants SET stock=1 WHERE id=vid;
  EXECUTE 'SET LOCAL ROLE authenticated';
  r:=r||pg_temp.check_regression('Checkout stock revalidated',format('SELECT count(*)=1 FROM public.checkout_order(%L,%L)',address,request_id),'23514');
  r:=r||pg_temp.check_regression('Failed checkout preserves cart',format('SELECT quantity=2 FROM public.cart_items WHERE variant_id=%L',vid));
  r:=r||pg_temp.check_regression('Failed checkout creates no order',format('SELECT count(*)=0 FROM public.orders WHERE request_id=%L',request_id));
  EXECUTE 'RESET ROLE';
  UPDATE public.product_variants SET stock=3 WHERE id=vid;
  EXECUTE 'SET LOCAL ROLE authenticated';
  SELECT * INTO got FROM public.checkout_order(address,request_id);
  oid:=got.order_id;
  r:=r||pg_temp.check_regression('Idempotent retry returns same order',format('SELECT order_id=%L FROM public.checkout_order(%L,%L)',oid,address,request_id));
  r:=r||pg_temp.check_regression('Retry does not decrement stock twice',format('SELECT stock=1 FROM public.product_variants WHERE id=%L',vid));
  r:=r||pg_temp.check_regression('Totals cannot be supplied in address',format('SELECT total_cents=25000 AND NOT(shipping_address ? ''total_cents'') AND payment_status=''unpaid'' FROM public.orders WHERE id=%L',oid));
  r:=r||pg_temp.check_regression('Customer cannot record payment',format('SELECT public.set_payment_status(%L,''paid'') IS NULL',oid),'42501');
  tid:=public.create_support_ticket('ROLLBACK QA','TEST MESSAGE',oid);
  r:=r||pg_temp.check_regression('Customer creates ticket and message',format('SELECT count(*)=1 FROM public.support_ticket_messages WHERE ticket_id=%L',tid));
  r:=r||pg_temp.check_regression('Customer cannot set support status',format('SELECT public.set_ticket_status(%L,''closed'') IS NULL',tid),'42501');

  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','email','thread-customer@example.invalid')::text,true);
  support_thread_id:=public.submit_support_request('THREAD QA','thread-customer@example.invalid','555-0101',support_subject,'Customer opening message');
  support_thread_followup_id:=public.submit_support_request('THREAD QA','thread-customer@example.invalid','555-0101',support_subject,'Customer follow-up message');
  r:=r||pg_temp.check_regression('Same customer and subject reuse one request',format('SELECT %L::uuid=%L::uuid',support_thread_id,support_thread_followup_id));
  r:=r||pg_temp.check_regression('Customer follow-up appends message',format('SELECT count(*)=2 FROM public.get_my_support_messages(%L)',support_thread_id));
  support_other_subject_id:=public.submit_support_request('THREAD QA','thread-customer@example.invalid','555-0101',support_other_subject,'Different subject message');
  r:=r||pg_temp.check_regression('Different subject creates a request',format('SELECT %L::uuid<>%L::uuid',support_thread_id,support_other_subject_id));

  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',other_customer,'role','authenticated')::text,true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  r:=r||pg_temp.check_regression('Other customer cannot see ticket',format('SELECT count(*)=0 FROM public.support_tickets WHERE id=%L',tid));
  r:=r||pg_temp.check_regression('Other customer cannot see messages',format('SELECT count(*)=0 FROM public.support_ticket_messages WHERE ticket_id=%L',tid));
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',other_customer,'role','authenticated','email','other-thread-customer@example.invalid')::text,true);
  r:=r||pg_temp.check_regression('Other customer cannot read request thread',format('SELECT count(*)=0 FROM public.get_my_support_messages(%L)',support_thread_id),'42501');
  r:=r||pg_temp.check_regression('Same subject from another customer stays separate',format('SELECT public.submit_support_request(''OTHER QA'',''other-thread-customer@example.invalid'',''555-0202'',%L,''Other customer message'')<>%L',support_subject,support_thread_id));
  r:=r||pg_temp.check_regression('Other customer cannot reply',format('SELECT public.add_support_message(%L,''TEST'') IS NULL',tid),'42501');
  r:=r||pg_temp.check_regression('Other customer cannot claim order in ticket',format('SELECT public.create_support_ticket(''TEST'',''TEST'',%L) IS NOT NULL',oid),'42501');
  r:=r||pg_temp.check_regression('Other customer cannot retrieve idempotent order',format('SELECT count(*)=1 FROM public.checkout_order(%L,%L)',address,request_id),'P0001');

  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated')::text,true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.admin_update_support_request(support_thread_id,'in_progress','','Admin first reply');
  r:=r||pg_temp.check_regression('Admin reply appends trusted thread message',format('SELECT count(*)=1 FROM public.admin_get_support_messages(%L) WHERE sender_type=''admin'' AND message=''Admin first reply''',support_thread_id));
  PERFORM public.set_order_status(oid,'confirmed');
  r:=r||pg_temp.check_regression('Backward order transition rejected',format('SELECT public.set_order_status(%L,''pending'') IS NULL',oid),'P0001');
  r:=r||pg_temp.check_regression('Unpaid refund rejected',format('SELECT public.set_payment_status(%L,''refunded'') IS NULL',oid),'P0001');
  PERFORM public.set_payment_status(oid,'paid');
  r:=r||pg_temp.check_regression('Manual payment status persists',format('SELECT payment_status=''paid'' FROM public.orders WHERE id=%L',oid));
  r:=r||pg_temp.check_regression('Payment note is recorded',format('SELECT count(*)=1 FROM public.admin_notes WHERE order_id=%L',oid));
  PERFORM public.set_payment_status(oid,'refunded');
  PERFORM public.set_order_status(oid,'cancelled');
  r:=r||pg_temp.check_regression('Cancellation restores stock',format('SELECT stock=3 FROM public.product_variants WHERE id=%L',vid));
  PERFORM public.set_order_status(oid,'cancelled');
  r:=r||pg_temp.check_regression('Repeated cancellation does not duplicate stock',format('SELECT stock=3 FROM public.product_variants WHERE id=%L',vid));
  r:=r||pg_temp.check_regression('Cancellation adds history once',format('SELECT count(*)=1 FROM public.order_status_history WHERE order_id=%L AND status=''cancelled''',oid));
  r:=r||pg_temp.check_regression('Cancelled order cannot reopen',format('SELECT public.set_order_status(%L,''confirmed'') IS NULL',oid),'P0001');
  PERFORM public.add_support_message(tid,'ADMIN TEST REPLY');
  r:=r||pg_temp.check_regression('Admin support reply has trusted sender role',format('SELECT count(*)=1 FROM public.support_ticket_messages WHERE ticket_id=%L AND sender_role=''admin''',tid));
  PERFORM public.set_ticket_status(tid,'closed');
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated')::text,true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.add_support_message(tid,'CUSTOMER FOLLOW UP');
  r:=r||pg_temp.check_regression('Customer follow-up reopens support ticket',format('SELECT status=''open'' FROM public.support_tickets WHERE id=%L',tid));
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','email','thread-customer@example.invalid')::text,true);
  PERFORM public.submit_support_request('THREAD QA','thread-customer@example.invalid','555-0101',support_subject,'Second customer follow-up');
  r:=r||pg_temp.check_regression('Admin reply and customer follow-up share one thread',format('SELECT count(*)=4 FROM public.get_my_support_messages(%L)',support_thread_id));
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims','{"role":"anon"}',true);
  EXECUTE 'SET LOCAL ROLE anon';
  r:=r||pg_temp.check_regression('Anonymous checkout permission revoked',format('SELECT count(*)=1 FROM public.checkout_order(%L,%L)',address,request_id),'42501');
  r:=r||pg_temp.check_regression('Anonymous support permission revoked','SELECT public.create_support_ticket(''TEST'',''TEST'',NULL) IS NOT NULL','42501');
  EXECUTE 'RESET ROLE';
  RAISE EXCEPTION USING ERRCODE='PZ003',MESSAGE='Rollback regression fixtures';
 EXCEPTION
  WHEN SQLSTATE 'PZ003' THEN NULL;
  WHEN OTHERS THEN r:=r||jsonb_build_object('test','Regression execution','pass',false,'sqlstate',SQLSTATE,'error',SQLERRM);
 END;
 PERFORM set_config('maison_qa.regression_results',r::text,false);
END $suite$;
SELECT current_setting('maison_qa.regression_results')::jsonb AS results;
