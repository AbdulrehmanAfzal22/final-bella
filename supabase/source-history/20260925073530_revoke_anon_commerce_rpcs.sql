revoke execute on function public.add_to_cart(uuid, int) from anon;
revoke execute on function public.set_cart_quantity(uuid, int) from anon;
revoke execute on function public.remove_from_cart(uuid) from anon;
revoke execute on function public.process_checkout(jsonb, int) from anon;
revoke execute on function public.set_order_status(uuid, text) from anon;
