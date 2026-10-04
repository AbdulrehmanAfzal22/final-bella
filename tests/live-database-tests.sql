-- Live role-aware tests. All fixture rows and temporary helpers are rolled back.
-- Existing QA users are only referenced; no users, passwords or memberships change.
DO $suite$
DECLARE
  r jsonb := '[]';
  pid uuid := gen_random_uuid();
  vid uuid := gen_random_uuid();
  cid uuid := gen_random_uuid();
  oid uuid := gen_random_uuid();
  customer uuid := '887ec16d-c4fe-468f-a20c-da799b0efcad';
  other_customer uuid := '736975b4-1c86-4699-bae2-05d1362b1259';
  admin_id uuid := '343a1900-bfeb-4861-90b3-ff2025bd9874';
  payload jsonb;
  got jsonb;
BEGIN
 BEGIN
  CREATE TEMP TABLE qa_scope(value int);
  EXECUTE $helper$
    CREATE FUNCTION pg_temp.qa_check(label text, statement text, expected_error boolean DEFAULT false)
    RETURNS jsonb LANGUAGE plpgsql AS $body$
    DECLARE actual boolean;
    BEGIN
      EXECUTE statement INTO actual;
      RETURN jsonb_build_object('test',label,'pass',NOT expected_error AND coalesce(actual,false),'actual',actual);
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('test',label,'pass',expected_error,'sqlstate',SQLSTATE,'error',SQLERRM);
    END $body$;
  $helper$;
  INSERT INTO public.wishlists(user_id) VALUES(customer),(other_customer) ON CONFLICT DO NOTHING;
  -- Test record uses an explicit negative order number to avoid consuming an order sequence.
  INSERT INTO public.orders(id,order_number,user_id,request_id,subtotal_cents,total_cents,shipping_address)
  OVERRIDING SYSTEM VALUE VALUES(oid,-2609250955,customer,gen_random_uuid(),12500,12500,'{"full_name":"TEMPORARY QA","line1":"TEST ONLY","city":"TEST","country":"TEST"}');
  INSERT INTO public.order_items(order_id,product_name,color,size,unit_price_cents,quantity)
  VALUES(oid,'TEMPORARY QA — NOT FOR SALE','Ink','M',12500,1);
  INSERT INTO public.order_status_history(order_id,status) VALUES(oid,'pending');

  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated')::text,true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  r:=r||pg_temp.qa_check('Existing QA admin recognized','SELECT public.is_admin()');
  r:=r||pg_temp.qa_check('Admin category creation',format('WITH x AS (INSERT INTO public.categories(id,name,slug) VALUES(%L,''TEMPORARY QA — NOT FOR SALE'',%L) RETURNING id) SELECT count(*)=1 FROM x',cid,'temporary-qa-'||cid));
  payload:=jsonb_build_object('id',pid,'name','TEMPORARY QA — NOT FOR SALE','description','Rollback-only integration fixture','price_cents',12500,'category_id',cid,'status','draft','featured',false,'variants',jsonb_build_array(jsonb_build_object('id',vid,'color','Ink','color_hex','#222222','size','M','stock',3)),'images','[]'::jsonb);
  r:=r||pg_temp.qa_check('Admin transactional draft product save',format('SELECT public.save_product(%L::jsonb)=%L::uuid',payload,pid));
  r:=r||pg_temp.qa_check('Product save without category rejected',format('SELECT public.save_product(%L::jsonb) IS NOT NULL',payload||jsonb_build_object('category_id',NULL)),true);
  r:=r||pg_temp.qa_check('Publishing without description rejected',format('SELECT public.save_product(%L::jsonb) IS NOT NULL',payload||jsonb_build_object('status','published','description','   ')),true);
  r:=r||pg_temp.qa_check('Publishing without an image rejected',format('SELECT public.save_product(%L::jsonb) IS NOT NULL',payload||'{"status":"published"}'::jsonb),true);
  r:=r||pg_temp.qa_check('Unuploaded image rejected',format('SELECT public.save_product(%L::jsonb) IS NOT NULL',payload||jsonb_build_object('status','published','images',jsonb_build_array(jsonb_build_object('path',pid||'/not-uploaded.png')))),true);
  r:=r||pg_temp.qa_check('Failed publish leaves draft unchanged',format('SELECT status=''draft'' AND (SELECT count(*)=0 FROM public.product_images WHERE product_id=%L) FROM public.products WHERE id=%L',pid,pid));

  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims','{"role":"anon"}',true);
  EXECUTE 'SET LOCAL ROLE anon';
  r:=r||pg_temp.qa_check('Anonymous reader cannot see draft',format('SELECT count(*)=0 FROM public.products WHERE id=%L',pid));
  r:=r||pg_temp.qa_check('Anonymous add to cart rejected',format('SELECT public.add_to_cart(%L,1) IS NULL',vid),true);

  EXECUTE 'RESET ROLE';
  -- A rollback-only published-row fixture; this does NOT test image upload/publish through the UI.
  UPDATE public.products SET status='published' WHERE id=pid;
  PERFORM set_config('request.jwt.claims','{"role":"anon"}',true);
  EXECUTE 'SET LOCAL ROLE anon';
  r:=r||pg_temp.qa_check('Anonymous reader sees published product',format('SELECT count(*)=1 FROM public.products WHERE id=%L',pid));
  r:=r||pg_temp.qa_check('Anonymous reader sees active variant',format('SELECT count(*)=1 FROM public.product_variants WHERE id=%L',vid));

  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated')::text,true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  r:=r||pg_temp.qa_check('Customer is not admin','SELECT NOT public.is_admin()');
  r:=r||pg_temp.qa_check('Customer cannot change product price',format('WITH x AS (UPDATE public.products SET price_cents=1 WHERE id=%L RETURNING id) SELECT count(*)=0 FROM x',pid));
  r:=r||pg_temp.qa_check('Customer cannot clear product category',format('WITH x AS (UPDATE public.products SET category_id=NULL WHERE id=%L RETURNING id) SELECT count(*)=0 FROM x',pid));
   r:=r||pg_temp.qa_check('Customer cannot archive product',format('WITH x AS (UPDATE public.products SET status=''archived'' WHERE id=%L RETURNING id) SELECT count(*)=0 FROM x',pid));
  r:=r||pg_temp.qa_check('Customer product-save RPC rejected',format('SELECT public.save_product(%L::jsonb) IS NOT NULL',payload),true);
  r:=r||pg_temp.qa_check('Customer category creation rejected',format('WITH x AS (INSERT INTO public.categories(name,slug) VALUES(''UNAUTHORIZED QA'',%L) RETURNING id) SELECT count(*)=1 FROM x','unauthorized-'||pid),true);
  BEGIN
   PERFORM public.add_to_cart(vid,1);
   r:=r||pg_temp.qa_check('Customer add to cart persists',format('SELECT quantity=1 FROM public.cart_items WHERE variant_id=%L AND user_id=%L',vid,customer));
   PERFORM public.set_cart_quantity(vid,2);
   r:=r||pg_temp.qa_check('Customer quantity update persists',format('SELECT quantity=2 FROM public.cart_items WHERE variant_id=%L AND user_id=%L',vid,customer));
   PERFORM public.remove_from_cart(vid);
   r:=r||pg_temp.qa_check('Customer cart removal persists',format('SELECT count(*)=0 FROM public.cart_items WHERE variant_id=%L AND user_id=%L',vid,customer));
   PERFORM public.add_to_cart(vid,2);
  EXCEPTION WHEN OTHERS THEN r:=r||jsonb_build_object('test','Cart flow execution','pass',false,'sqlstate',SQLSTATE,'error',SQLERRM); END;
  r:=r||pg_temp.qa_check('Zero cart quantity rejected',format('SELECT public.set_cart_quantity(%L,0) IS NULL',vid),true);
  r:=r||pg_temp.qa_check('Wishlist add succeeds',format('WITH x AS (INSERT INTO public.wishlist_items(user_id,product_id) VALUES(%L,%L) RETURNING product_id) SELECT count(*)=1 FROM x',customer,pid));
  r:=r||pg_temp.qa_check('Review submission succeeds',format('WITH x AS (INSERT INTO public.reviews(product_id,user_id,rating,comment,approved) VALUES(%L,%L,5,''TEMPORARY QA REVIEW'',false) RETURNING id) SELECT count(*)=1 FROM x',pid,customer));
  r:=r||pg_temp.qa_check('Owner can read own order',format('SELECT count(*)=1 FROM public.orders WHERE id=%L',oid));
  r:=r||pg_temp.qa_check('Owner can read own order items',format('SELECT count(*)=1 FROM public.order_items WHERE order_id=%L',oid));
  r:=r||pg_temp.qa_check('Owner can read own order history',format('SELECT count(*)=1 FROM public.order_status_history WHERE order_id=%L',oid));
  r:=r||pg_temp.qa_check('Customer cannot set order status',format('SELECT public.set_order_status(%L,''shipped'') IS NULL',oid),true);
  BEGIN
   SELECT to_jsonb(c) INTO got FROM public.process_checkout('{"full_name":"TEMPORARY QA","line1":"TEST ONLY","city":"TEST","country":"TEST"}',0) c;
   r:=r||jsonb_build_object('test','COD checkout creates an order','pass',got IS NOT NULL,'result',got);
   r:=r||pg_temp.qa_check('Checkout uses server product price',format('SELECT total_cents=25000 AND payment_status=''unpaid'' FROM public.orders WHERE id=%L',got->>'order_id'));
   r:=r||pg_temp.qa_check('Checkout decrements stock',format('SELECT stock=1 FROM public.product_variants WHERE id=%L',vid));
   r:=r||pg_temp.qa_check('Checkout clears cart',format('SELECT count(*)=0 FROM public.cart_items WHERE variant_id=%L AND user_id=%L',vid,customer));
  EXCEPTION WHEN OTHERS THEN
   r:=r||jsonb_build_object('test','COD checkout creates an order','pass',false,'sqlstate',SQLSTATE,'error',SQLERRM);
  END;

  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',other_customer,'role','authenticated')::text,true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  r:=r||pg_temp.qa_check('Other customer cannot see cart',format('SELECT count(*)=0 FROM public.cart_items WHERE user_id=%L',customer));
  r:=r||pg_temp.qa_check('Other customer cannot see wishlist',format('SELECT count(*)=0 FROM public.wishlist_items WHERE user_id=%L',customer));
  r:=r||pg_temp.qa_check('Other customer cannot see order',format('SELECT count(*)=0 FROM public.orders WHERE id=%L',oid));
  r:=r||pg_temp.qa_check('Other customer cannot see order items',format('SELECT count(*)=0 FROM public.order_items WHERE order_id=%L',oid));
  r:=r||pg_temp.qa_check('Other customer cannot see order history',format('SELECT count(*)=0 FROM public.order_status_history WHERE order_id=%L',oid));
  r:=r||pg_temp.qa_check('Other customer cannot see pending review',format('SELECT count(*)=0 FROM public.reviews WHERE product_id=%L',pid));
  r:=r||pg_temp.qa_check('Customer cannot self-approve a review',format('WITH x AS (INSERT INTO public.reviews(product_id,user_id,rating,comment,approved) VALUES(%L,%L,5,''TEMPORARY QA SELF APPROVAL'',true) RETURNING id) SELECT count(*)=1 FROM x',pid,other_customer),true);

  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated')::text,true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  r:=r||pg_temp.qa_check('Admin can see customer order',format('SELECT count(*)=1 FROM public.orders WHERE id=%L',oid));
   r:=r||pg_temp.qa_check('Product category cannot be cleared',format('WITH x AS (UPDATE public.products SET category_id=NULL WHERE id=%L RETURNING id) SELECT count(*)=1 FROM x',pid),'23502');
  BEGIN
   PERFORM public.set_order_status(oid,'shipped');
   r:=r||pg_temp.qa_check('Admin status update persists',format('SELECT status=''shipped'' FROM public.orders WHERE id=%L',oid));
   r:=r||pg_temp.qa_check('Admin status change adds history',format('SELECT count(*)=1 FROM public.order_status_history WHERE order_id=%L AND status=''shipped''',oid));
  EXCEPTION WHEN OTHERS THEN r:=r||jsonb_build_object('test','Admin status update flow','pass',false,'sqlstate',SQLSTATE,'error',SQLERRM); END;
  r:=r||pg_temp.qa_check('Invalid order status rejected',format('SELECT public.set_order_status(%L,''not-valid'') IS NULL',oid),true);
  r:=r||pg_temp.qa_check('Admin approves a review',format('WITH x AS (UPDATE public.reviews SET approved=true WHERE product_id=%L RETURNING id) SELECT count(*)=1 FROM x',pid));
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims','{"role":"anon"}',true);
  EXECUTE 'SET LOCAL ROLE anon';
  r:=r||pg_temp.qa_check('Approved review is publicly readable',format('SELECT count(*)=1 FROM public.reviews WHERE product_id=%L AND approved',pid));
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated')::text,true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  r:=r||pg_temp.qa_check('Admin hides a review',format('WITH x AS (UPDATE public.reviews SET approved=false WHERE product_id=%L RETURNING id) SELECT count(*)=1 FROM x',pid));
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims','{"role":"anon"}',true);
  EXECUTE 'SET LOCAL ROLE anon';
  r:=r||pg_temp.qa_check('Hidden review is no longer publicly readable',format('SELECT count(*)=0 FROM public.reviews WHERE product_id=%L',pid));
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated')::text,true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  UPDATE public.products SET status='archived',featured=false WHERE id=pid;
  r:=r||pg_temp.qa_check('Archived product is soft-deleted from catalog',format('SELECT status=''archived'' AND NOT featured FROM public.products WHERE id=%L',pid));
  r:=r||pg_temp.qa_check('Archived product order history remains intact',format('SELECT count(*)=1 FROM public.order_items WHERE order_id=%L AND variant_id=%L',(got->>'order_id')::uuid,vid));
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims','{"role":"anon"}',true);
  EXECUTE 'SET LOCAL ROLE anon';
  r:=r||pg_temp.qa_check('Anonymous cannot see archived product',format('SELECT count(*)=0 FROM public.products WHERE id=%L',pid));
  EXECUTE 'RESET ROLE';
  RAISE EXCEPTION USING ERRCODE='PZ001',MESSAGE='Rollback all QA fixtures';
 EXCEPTION
  WHEN SQLSTATE 'PZ001' THEN NULL;
  WHEN OTHERS THEN r:=r||jsonb_build_object('test','Test setup/execution','pass',false,'sqlstate',SQLSTATE,'error',SQLERRM);
 END;
 PERFORM set_config('maison_qa.results',r::text,false);
END $suite$;
SELECT current_setting('maison_qa.results')::jsonb AS results;
