import { useEffect, useState } from "react";
import { getProductVariants, createVariant, deleteVariant } from "../services/variants";

export default function VariantManager({ productId }) {
  const [variants,setVariants]=useState([]);
  const [form,setForm]=useState({color:"",size:"",stock:0});

  async function load(){
    setVariants(await getProductVariants(productId));
  }

  useEffect(()=>{ if(productId) load(); },[productId]);

  async function add(){
    await createVariant({...form, product_id: productId});
    setForm({color:"",size:"",stock:0});
    load();
  }

  async function remove(id){
    await deleteVariant(id);
    load();
  }

  return <div>
    <input value={form.color} onChange={e=>setForm({...form,color:e.target.value})} placeholder="Color"/>
    <input value={form.size} onChange={e=>setForm({...form,size:e.target.value})} placeholder="Size"/>
    <input type="number" value={form.stock} onChange={e=>setForm({...form,stock:Number(e.target.value)})}/>
    <button onClick={add}>Add Variant</button>
    {variants.map(v=><div key={v.id}>{v.color} / {v.size} / {v.stock}<button onClick={()=>remove(v.id)}>Delete</button></div>)}
  </div>
}
