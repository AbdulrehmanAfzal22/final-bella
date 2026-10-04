export default function ShippingForm({shipping,addresses,selectedAddress,onAddressChange,onFieldChange,addressError}){
  const fields=[
    {name:'full_name',label:'Full name',autoComplete:'shipping name',required:true,wide:true},
    {name:'line1',label:'Address line',autoComplete:'shipping address-line1',required:true,wide:true},
    {name:'city',label:'City',autoComplete:'shipping address-level2',required:true},
    {name:'postal_code',label:'Postal code',autoComplete:'shipping postal-code'},
    {name:'country',label:'Country',autoComplete:'shipping country-name',required:true},
    {name:'phone',label:'Phone number',autoComplete:'shipping tel',type:'tel'},
  ];

  return <section className="checkout-section" id="shipping-information" aria-labelledby="shipping-title">
    <div className="checkout-section__heading"><span>01</span><div><p className="commerce-eyebrow">Delivery details</p><h2 id="shipping-title">Shipping information</h2></div></div>
    <div className="checkout-address-select"><label htmlFor="saved-address">Saved addresses</label><select id="saved-address" value={selectedAddress} onChange={onAddressChange}><option value="">Enter a new address</option>{(addresses||[]).map(address=><option key={address.id} value={address.id}>{address.label||'Address'} · {address.full_name} · {address.line1}, {address.city}</option>)}</select>{addressError&&<p className="checkout-field-note" role="status">Saved addresses could not be loaded. Enter your shipping address below.</p>}</div>
    <div className="checkout-fields">{fields.map(field=><label className={field.wide?'checkout-field checkout-field--wide':'checkout-field'} key={field.name} htmlFor={`shipping-${field.name}`}><span>{field.label}{field.required&&<sup aria-hidden="true">*</sup>}</span><input id={`shipping-${field.name}`} name={field.name} type={field.type||'text'} autoComplete={field.autoComplete} required={field.required||undefined} maxLength={field.name==='line1'?300:field.name==='full_name'||field.name==='city'?150:field.name==='postal_code'?20:field.name==='country'?100:30} value={shipping[field.name]} onChange={event=>onFieldChange(field.name,event.target.value)}/></label>)}</div>
    <p className="checkout-required-note"><span aria-hidden="true">*</span> Required fields</p>
  </section>;
}