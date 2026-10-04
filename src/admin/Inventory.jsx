import QuantityEditor from '../components/QuantityEditor';
import {useQuery} from '../hooks/useQuery';
import {getInventory,updateStock,getLowStockItems} from '../services/inventoryAdmin';
import {Loading,ErrorState,Empty} from '../components/Feedback';
import DataTable from '../components/admin/DataTable';
import StatusBadge from '../components/admin/StatusBadge';

export default function Inventory(){
  const query=useQuery(()=>getInventory());
  if(query.loading&&!query.data)return <Loading label="Loading inventory…"/>;
  if(query.error)return <ErrorState error={query.error} retry={query.refresh}/>;
  const items=query.data||[];
  if(!items.length)return <Empty title="No variants yet" text="Add products with variants to manage stock here." link="/admin/products/create" action="Add a product"/>;
  const lowStock=getLowStockItems(items);
  async function changeStock(item,value){await updateStock(item.id,value,item.updated_at);await query.refresh();}
  const columns=[
    {key:'product',label:'Product',render:item=><div className="admin-product-cell"><strong>{item.products?.name||'Unavailable product'}</strong><small>{item.products?.status||'—'}</small></div>},
    {key:'color',label:'Colour',render:item=><span className="admin-variant-label"><i style={{backgroundColor:item.color_hex||'#d8d2c9'}}/>{item.color}</span>},
    {key:'size',label:'Size'},
    {key:'availability',label:'Availability',render:item=><StatusBadge status={item.stock===0?'out-of-stock':item.stock<=5?'low-stock':'in-stock'}/>},
    {key:'stock',label:'Available units',numeric:true,render:item=><QuantityEditor value={item.stock} label={`Stock for ${item.products?.name} ${item.color} ${item.size}`} onSave={value=>changeStock(item,value)}/>},
  ];
  return <><div className="section-heading admin-page-heading"><div><p className="eyebrow">STOCK CONTROL</p><h1>Inventory</h1><p className="admin-page-intro">Variant availability and stock adjustments.</p></div></div>{lowStock.length>0&&<p className="notice admin-stock-notice" role="status">{lowStock.length} variant{lowStock.length===1?'':'s'} at low stock (5 or fewer units).</p>}<DataTable caption="Inventory by product variant" columns={columns} rows={items} rowKey={item=>item.id}/></>;
}
