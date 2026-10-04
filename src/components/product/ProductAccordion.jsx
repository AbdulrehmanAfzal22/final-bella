import {ChevronDown} from 'lucide-react';

export default function ProductAccordion({product}){
  const sections=[
    {title:'Description',content:product.description||'Product details will be shared soon.'},
    {title:'Materials',content:product.materials||'For composition details, please contact the Bella by RT studio.'},
    {title:'Shipping',content:'Complimentary shipping on all orders. Delivery timing and tracking details are shared after your order is confirmed.'},
    {title:'Care instructions',content:product.care||'Care instructions will be included with your piece.'},
  ];

  return <section className="product-accordion" aria-label="Product details">{sections.map((section,index)=><details key={section.title} open={index===0}><summary><span>{section.title}</span><ChevronDown size={17}/></summary><p>{section.content}</p></details>)}</section>;
}