-- Repairs against the existing cloth-web schema. No users or catalog data are seeded.
CREATE OR REPLACE FUNCTION private.change_cart(p_variant_id uuid, p_quantity integer, p_operation text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  uid uuid := auth.uid();
  available integer;
  current_quantity integer;
  desired integer;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  INSERT INTO public.carts(user_id) VALUES(uid) ON CONFLICT DO NOTHING;
  PERFORM 1 FROM public.carts c WHERE c.user_id=uid FOR UPDATE;
  IF p_operation='remove' THEN
    DELETE FROM public.cart_items ci WHERE ci.user_id=uid AND ci.variant_id=p_variant_id;
    RETURN;
  END IF;
  IF p_operation NOT IN ('add','set') OR p_quantity IS NULL OR p_quantity<1 OR p_quantity>99 THEN
    RAISE EXCEPTION 'Quantity must be between 1 and 99' USING ERRCODE='22023';
  END IF;
  SELECT pv.stock INTO available FROM public.product_variants pv
  JOIN public.products p ON p.id=pv.product_id
  WHERE pv.id=p_variant_id AND pv.active AND p.status='published' FOR SHARE OF p,pv;
  IF NOT FOUND THEN RAISE EXCEPTION 'This product is no longer available'; END IF;
  SELECT ci.quantity INTO current_quantity FROM public.cart_items ci WHERE ci.user_id=uid AND ci.variant_id=p_variant_id;
  IF p_operation='set' AND NOT FOUND THEN RAISE EXCEPTION 'Cart item not found'; END IF;
  desired := CASE WHEN p_operation='add' THEN coalesce(current_quantity,0)+p_quantity ELSE p_quantity END;
  IF desired>99 OR desired>available THEN RAISE EXCEPTION 'Requested quantity exceeds available stock' USING ERRCODE='23514'; END IF;
  INSERT INTO public.cart_items(user_id,variant_id,quantity) VALUES(uid,p_variant_id,desired)
  ON CONFLICT(user_id,variant_id) DO UPDATE SET quantity=excluded.quantity;
END $$;
REVOKE ALL ON FUNCTION private.change_cart(uuid,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.change_cart(uuid,integer,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.add_to_cart(p_variant_id uuid,p_quantity integer)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT private.change_cart($1,$2,'add'); $$;
CREATE OR REPLACE FUNCTION public.set_cart_quantity(p_variant_id uuid,p_quantity integer)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT private.change_cart($1,$2,'set'); $$;
CREATE OR REPLACE FUNCTION public.remove_from_cart(p_variant_id uuid)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT private.change_cart($1,NULL,'remove'); $$;
REVOKE ALL ON FUNCTION public.add_to_cart(uuid,integer),public.set_cart_quantity(uuid,integer),public.remove_from_cart(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.add_to_cart(uuid,integer),public.set_cart_quantity(uuid,integer),public.remove_from_cart(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION private.checkout_impl(p_shipping jsonb,p_shipping_cents integer,p_request_id uuid)
RETURNS TABLE(order_id uuid,order_number bigint,total_cents bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  uid uuid := auth.uid();
  new_order_id uuid;
  new_order_number bigint;
  subtotal bigint;
  address jsonb;
  item record;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'Checkout request ID is required' USING ERRCODE='22023'; END IF;
  IF coalesce(p_shipping_cents,0)<>0 THEN RAISE EXCEPTION 'Shipping is free; the delivery charge cannot be overridden' USING ERRCODE='22023'; END IF;
  INSERT INTO public.carts(user_id) VALUES(uid) ON CONFLICT DO NOTHING;
  -- The same cart lock is taken by all three cart mutations.
  PERFORM 1 FROM public.carts c WHERE c.user_id=uid FOR UPDATE;
  RETURN QUERY SELECT o.id,o.order_number,o.total_cents FROM public.orders o WHERE o.user_id=uid AND o.request_id=p_request_id;
  IF FOUND THEN RETURN; END IF;

  IF p_shipping IS NULL OR jsonb_typeof(p_shipping)<>'object' THEN RAISE EXCEPTION 'Enter a shipping address'; END IF;
  IF length(btrim(coalesce(p_shipping->>'full_name',''))) NOT BETWEEN 1 AND 150
     OR length(btrim(coalesce(p_shipping->>'line1',''))) NOT BETWEEN 1 AND 300
     OR length(btrim(coalesce(p_shipping->>'city',''))) NOT BETWEEN 1 AND 150
     OR length(btrim(coalesce(p_shipping->>'country',''))) NOT BETWEEN 1 AND 100
     OR length(coalesce(p_shipping->>'postal_code',''))>20 OR length(coalesce(p_shipping->>'phone',''))>30 THEN
    RAISE EXCEPTION 'Enter a valid name, street address, city and country' USING ERRCODE='22023';
  END IF;
  address:=jsonb_build_object('full_name',btrim(p_shipping->>'full_name'),'line1',btrim(p_shipping->>'line1'),
    'city',btrim(p_shipping->>'city'),'country',btrim(p_shipping->>'country'),
    'postal_code',btrim(coalesce(p_shipping->>'postal_code','')),'phone',btrim(coalesce(p_shipping->>'phone','')));
  IF NOT EXISTS(SELECT 1 FROM public.cart_items ci WHERE ci.user_id=uid) THEN RAISE EXCEPTION 'Your bag is empty'; END IF;
  -- Freeze prices/publication state, then lock variant stock in a consistent order.
  PERFORM p.id FROM public.products p WHERE p.id IN (
    SELECT pv.product_id FROM public.product_variants pv JOIN public.cart_items ci ON ci.variant_id=pv.id WHERE ci.user_id=uid
  ) ORDER BY p.id FOR SHARE;
  PERFORM pv.id FROM public.product_variants pv JOIN public.cart_items ci ON ci.variant_id=pv.id
  WHERE ci.user_id=uid ORDER BY pv.id FOR UPDATE OF pv;
  FOR item IN SELECT ci.quantity,pv.stock,pv.active,p.status FROM public.cart_items ci
    JOIN public.product_variants pv ON pv.id=ci.variant_id JOIN public.products p ON p.id=pv.product_id WHERE ci.user_id=uid
  LOOP
    IF NOT item.active OR item.status<>'published' THEN RAISE EXCEPTION 'A piece in your bag is no longer available'; END IF;
    IF item.stock<item.quantity THEN RAISE EXCEPTION 'Insufficient stock for one or more items' USING ERRCODE='23514'; END IF;
  END LOOP;
  SELECT sum(p.price_cents::bigint*ci.quantity) INTO subtotal FROM public.cart_items ci
  JOIN public.product_variants pv ON pv.id=ci.variant_id JOIN public.products p ON p.id=pv.product_id WHERE ci.user_id=uid;
  INSERT INTO public.orders AS o(user_id,request_id,status,payment_status,subtotal_cents,shipping_cents,total_cents,shipping_address)
  VALUES(uid,p_request_id,'pending','unpaid',subtotal,0,subtotal,address)
  RETURNING o.id,o.order_number INTO new_order_id,new_order_number;
  INSERT INTO public.order_items(order_id,variant_id,product_name,color,size,image_path,unit_price_cents,quantity)
  SELECT new_order_id,pv.id,p.name,pv.color,pv.size,
    (SELECT im.path FROM public.product_images im WHERE im.product_id=p.id ORDER BY (lower(im.color)=lower(pv.color)) DESC NULLS LAST,im.position LIMIT 1),
    p.price_cents,ci.quantity FROM public.cart_items ci JOIN public.product_variants pv ON pv.id=ci.variant_id
    JOIN public.products p ON p.id=pv.product_id WHERE ci.user_id=uid;
  UPDATE public.product_variants pv SET stock=pv.stock-ci.quantity FROM public.cart_items ci WHERE ci.variant_id=pv.id AND ci.user_id=uid;
  INSERT INTO public.order_status_history(order_id,status) VALUES(new_order_id,'pending');
  DELETE FROM public.cart_items ci WHERE ci.user_id=uid;
  RETURN QUERY SELECT new_order_id,new_order_number,subtotal;
END $$;
REVOKE ALL ON FUNCTION private.checkout_impl(jsonb,integer,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.checkout_impl(jsonb,integer,uuid) TO authenticated;

-- Backward-compatible entry point for the previous frontend.
CREATE OR REPLACE FUNCTION public.process_checkout(shipping jsonb,shipping_cents integer DEFAULT 0)
RETURNS TABLE(order_id uuid,order_number bigint,total_cents bigint)
LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT * FROM private.checkout_impl($1,$2,gen_random_uuid()); $$;
CREATE OR REPLACE FUNCTION public.checkout_order(p_shipping jsonb,p_request_id uuid)
RETURNS TABLE(order_id uuid,order_number bigint,total_cents bigint)
LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT * FROM private.checkout_impl($1,0,$2); $$;
REVOKE ALL ON FUNCTION public.process_checkout(jsonb,integer),public.checkout_order(jsonb,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.process_checkout(jsonb,integer),public.checkout_order(jsonb,uuid) TO authenticated;

ALTER POLICY reviews_insert_own ON public.reviews WITH CHECK ((SELECT auth.uid())=user_id AND approved=false);
ALTER POLICY reviews_admin_update ON public.reviews USING ((SELECT private.is_admin())) WITH CHECK ((SELECT private.is_admin()));

CREATE OR REPLACE FUNCTION private.update_order_status(p_order_id uuid,p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE current_status text;
BEGIN
  IF auth.uid() IS NULL OR NOT private.is_admin() THEN RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501'; END IF;
  IF p_status IS NULL OR p_status NOT IN ('pending','confirmed','processing','shipped','delivered','cancelled') THEN RAISE EXCEPTION 'Invalid status'; END IF;
  SELECT o.status INTO current_status FROM public.orders o WHERE o.id=p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found'; END IF;
  IF current_status=p_status THEN RETURN; END IF;
  IF current_status IN ('cancelled','delivered') THEN RAISE EXCEPTION 'This order is already closed'; END IF;
  IF p_status='cancelled' THEN
    IF current_status='shipped' THEN RAISE EXCEPTION 'A shipped order cannot be cancelled; contact the customer about a return'; END IF;
    PERFORM pv.id FROM public.product_variants pv WHERE pv.id IN (SELECT oi.variant_id FROM public.order_items oi WHERE oi.order_id=p_order_id) ORDER BY pv.id FOR UPDATE;
    UPDATE public.product_variants pv SET stock=pv.stock+x.quantity FROM (
      SELECT oi.variant_id,sum(oi.quantity)::integer AS quantity FROM public.order_items oi WHERE oi.order_id=p_order_id GROUP BY oi.variant_id
    ) x WHERE pv.id=x.variant_id;
  ELSIF array_position(ARRAY['pending','confirmed','processing','shipped','delivered'],p_status)
      <=array_position(ARRAY['pending','confirmed','processing','shipped','delivered'],current_status) THEN
    RAISE EXCEPTION 'Order status can only move forward';
  END IF;
  UPDATE public.orders o SET status=p_status WHERE o.id=p_order_id;
  INSERT INTO public.order_status_history(order_id,status) VALUES(p_order_id,p_status);
END $$;
CREATE OR REPLACE FUNCTION public.set_order_status(p_order_id uuid,p_status text)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT private.update_order_status($1,$2); $$;
REVOKE ALL ON FUNCTION private.update_order_status(uuid,text),public.set_order_status(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.update_order_status(uuid,text),public.set_order_status(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION private.record_payment_status(p_order_id uuid,p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE old_status text; order_status text;
BEGIN
  IF auth.uid() IS NULL OR NOT private.is_admin() THEN RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501'; END IF;
  IF p_status IS NULL OR p_status NOT IN ('unpaid','paid','refunded') THEN RAISE EXCEPTION 'Invalid payment status'; END IF;
  SELECT o.payment_status,o.status INTO old_status,order_status FROM public.orders o WHERE o.id=p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found'; END IF;
  IF old_status=p_status THEN RETURN; END IF;
  IF p_status='paid' AND order_status='cancelled' THEN RAISE EXCEPTION 'Cannot mark a cancelled order as paid'; END IF;
  IF p_status='refunded' AND old_status<>'paid' THEN RAISE EXCEPTION 'Only a paid order can be marked refunded'; END IF;
  IF p_status='unpaid' AND old_status='refunded' THEN RAISE EXCEPTION 'A refunded payment cannot be marked unpaid'; END IF;
  UPDATE public.orders o SET payment_status=p_status WHERE o.id=p_order_id;
  INSERT INTO public.admin_notes(order_id,note) VALUES(p_order_id,'Payment recorded as '||p_status||' by admin '||auth.uid()::text);
END $$;
CREATE OR REPLACE FUNCTION public.set_payment_status(p_order_id uuid,p_status text)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT private.record_payment_status($1,$2); $$;
REVOKE ALL ON FUNCTION private.record_payment_status(uuid,text),public.set_payment_status(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.record_payment_status(uuid,text),public.set_payment_status(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION private.create_ticket(p_subject text,p_body text,p_order_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid:=auth.uid(); tid uuid;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_order_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.orders o WHERE o.id=p_order_id AND o.user_id=uid) THEN
    RAISE EXCEPTION 'Order not found' USING ERRCODE='42501';
  END IF;
  INSERT INTO public.support_tickets(user_id,order_id,subject) VALUES(uid,p_order_id,btrim(p_subject)) RETURNING id INTO tid;
  INSERT INTO public.support_messages(ticket_id,sender_role,sender_id,body) VALUES(tid,'customer',uid,btrim(p_body));
  RETURN tid;
END $$;
CREATE OR REPLACE FUNCTION private.reply_to_ticket(p_ticket_id uuid,p_body text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid:=auth.uid(); is_adm boolean:=private.is_admin(); ticket public.support_tickets%ROWTYPE;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  SELECT t.* INTO ticket FROM public.support_tickets t WHERE t.id=p_ticket_id FOR UPDATE;
  IF NOT FOUND OR (ticket.user_id<>uid AND NOT is_adm) THEN RAISE EXCEPTION 'Ticket not found' USING ERRCODE='42501'; END IF;
  INSERT INTO public.support_messages(ticket_id,sender_role,sender_id,body)
  VALUES(p_ticket_id,CASE WHEN is_adm THEN 'admin' ELSE 'customer' END,uid,btrim(p_body));
  UPDATE public.support_tickets SET status=CASE WHEN is_adm AND status='open' THEN 'in_progress'
    WHEN NOT is_adm AND status IN ('resolved','closed') THEN 'open' ELSE status END,updated_at=now() WHERE id=p_ticket_id;
END $$;
CREATE OR REPLACE FUNCTION private.update_ticket_status(p_ticket_id uuid,p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT private.is_admin() THEN RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501'; END IF;
  IF p_status IS NULL OR p_status NOT IN ('open','in_progress','resolved','closed') THEN RAISE EXCEPTION 'Invalid status' USING ERRCODE='22023'; END IF;
  UPDATE public.support_tickets SET status=p_status WHERE id=p_ticket_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Ticket not found'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.create_support_ticket(p_subject text,p_body text,p_order_id uuid DEFAULT NULL)
RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT private.create_ticket($1,$2,$3); $$;
CREATE OR REPLACE FUNCTION public.add_support_message(p_ticket_id uuid,p_body text)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT private.reply_to_ticket($1,$2); $$;
CREATE OR REPLACE FUNCTION public.set_ticket_status(p_ticket_id uuid,p_status text)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT private.update_ticket_status($1,$2); $$;
REVOKE ALL ON FUNCTION private.create_ticket(text,text,uuid),private.reply_to_ticket(uuid,text),private.update_ticket_status(uuid,text),
  public.create_support_ticket(text,text,uuid),public.add_support_message(uuid,text),public.set_ticket_status(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.create_ticket(text,text,uuid),private.reply_to_ticket(uuid,text),private.update_ticket_status(uuid,text),
  public.create_support_ticket(text,text,uuid),public.add_support_message(uuid,text),public.set_ticket_status(uuid,text) TO authenticated;
NOTIFY pgrst,'reload schema';
