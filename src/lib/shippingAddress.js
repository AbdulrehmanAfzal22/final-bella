export function shippingFromSavedAddress(address){
  return {
    full_name:address?.full_name||'',
    line1:address?.line1||'',
    city:address?.city||'',
    postal_code:address?.postal_code||'',
    country:address?.country||'',
    phone:address?.phone||'',
  };
}