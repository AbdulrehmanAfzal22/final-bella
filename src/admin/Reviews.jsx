import {useState} from 'react';
import {Link} from 'react-router-dom';
import {toast} from 'sonner';
import {useQuery} from '../hooks/useQuery';
import {getAdminReviews,approveReview,deleteReview} from '../services/reviewAdmin';
import {Loading,ErrorState,Empty} from '../components/Feedback';
import DataTable from '../components/admin/DataTable';
import ReviewStatusBadge from '../components/admin/ReviewStatusBadge';
import {getReviewStatus} from '../lib/reviewStatus';

const filters=['all','pending','approved','spam','rejected'];

export default function Reviews(){
  const query=useQuery(getAdminReviews);
  const [filter,setFilter]=useState('pending');
  const [busy,setBusy]=useState(null);
  const [statusOverrides,setStatusOverrides]=useState({});
  const [actionError,setActionError]=useState('');

  async function moderate(review,action){
    if(action==='delete'&&!window.confirm('Delete this review? This cannot be undone.'))return;
    setBusy(review.id);setActionError('');
    try{
      if(action==='delete')await deleteReview(review.id);
      else{
        await approveReview(review.id,action==='approve');
        setStatusOverrides(current=>({...current,[review.id]:action==='approve'?'approved':'rejected'}));
      }
      await query.refresh();
      toast.success(action==='delete'?'Review deleted.':action==='approve'?'Review approved.':'Review rejected.');
    }catch(error){setActionError(error.message);toast.error(error.message);}
    finally{setBusy(null);}
  }

  if(query.loading&&!query.data)return <Loading label="Loading reviews…"/>;
  if(query.error)return <ErrorState error={query.error} retry={query.refresh}/>;

  const reviews=(query.data||[]).map(review=>({...review,display_status:getReviewStatus(review,statusOverrides[review.id])}));
  const visibleReviews=reviews.filter(review=>filter==='all'||review.display_status===filter);
  const columns=[
    {key:'customer',label:'Customer',render:review=><span title={review.user_id}>{review.profiles?.full_name||review.customer_name||`Customer ${String(review.user_id||'').slice(0,8)}`}</span>},
    {key:'product',label:'Product',render:review=><Link to={`/admin/products/${review.product_id}`}>{review.products?.name||'Product'}</Link>},
    {key:'rating',label:'Rating',render:review=><span aria-label={`${review.rating} out of 5 stars`}>{'★'.repeat(review.rating)}{'☆'.repeat(5-review.rating)} <small>{review.rating}/5</small></span>},
    {key:'comment',label:'Comment',className:'review-admin-comment',render:review=>review.comment||'No written comment'},
    {key:'created_at',label:'Date',render:review=>new Date(review.created_at).toLocaleDateString()},
    {key:'status',label:'Status',render:review=><ReviewStatusBadge review={review} status={review.display_status}/>},
    {key:'actions',label:'Actions',render:review=><div className="admin-table-actions review-admin-actions">{review.display_status!=='approved'&&<button type="button" disabled={busy===review.id} onClick={()=>moderate(review,'approve')}>Approve</button>}{review.display_status!=='rejected'&&<button type="button" disabled={busy===review.id} onClick={()=>moderate(review,'reject')}>Reject</button>}<button className="text-button" type="button" disabled={busy===review.id} onClick={()=>moderate(review,'delete')}>{busy===review.id?'Saving…':'Delete'}</button></div>},
  ];

  return <>
    <div className="section-heading admin-page-heading"><div><p className="eyebrow">CUSTOMER VOICE</p><h1>Reviews Management</h1><p className="admin-page-intro">Review customer feedback and moderate what appears on product pages.</p></div></div>
    <div className="admin-list-toolbar review-admin-toolbar"><label className="admin-select-field"><span>Status</span><select value={filter} onChange={event=>setFilter(event.target.value)}>{filters.map(status=><option key={status} value={status}>{status==='all'?'All':status[0].toUpperCase()+status.slice(1)}</option>)}</select></label><span className="admin-list-toolbar__count">{visibleReviews.length} {visibleReviews.length===1?'review':'reviews'}</span></div>
    {actionError&&<p className="error" role="alert">{actionError}</p>}
    {!visibleReviews.length?<Empty title="No reviews in this view" action={null}/>:<DataTable caption="Customer review management" columns={columns} rows={visibleReviews} rowKey={review=>review.id} empty="No reviews match this status."/>}
  </>;
}
