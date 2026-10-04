const steps=[{id:'shipping-information',number:'01',label:'Shipping'},{id:'delivery',number:'02',label:'Delivery'},{id:'order-summary',number:'03',label:'Review'}];

export default function CheckoutSteps(){
  return <nav className="checkout-steps" aria-label="Checkout steps">{steps.map((step,index)=><a href={`#${step.id}`} className={index===0?'is-current':''} key={step.id}><span>{step.number}</span><span>{step.label}</span></a>)}</nav>;
}