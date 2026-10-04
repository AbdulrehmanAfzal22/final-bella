import {useState} from 'react';
import {Star} from 'lucide-react';

const pageSize=5;

export default function ReviewList({reviews=[]}){
  const [visibleCount,setVisibleCount]=useState(pageSize);
  const visibleReviews=reviews.slice(0,visibleCount);
  const remaining=reviews.length-visibleReviews.length;

  return <div className="review-list">
    {visibleReviews.map(review=><article key={review.id} className="review review-list__card">
      <div className="review-list__card-heading"><strong>Customer review</strong><time dateTime={review.created_at}>{new Date(review.created_at).toLocaleDateString()}</time></div>
      <span className="product-review-stars" aria-label={`${review.rating} out of 5 stars`}>{[1,2,3,4,5].map(value=><Star key={value} size={13} fill={value<=review.rating?'currentColor':'none'}/>)}</span>
      {review.comment&&<p>{review.comment}</p>}
    </article>)}
    {remaining>0&&<button className="review-list__load-more" type="button" onClick={()=>setVisibleCount(count=>Math.min(reviews.length,count+pageSize))}>{visibleCount===pageSize?'View all reviews':`Load more reviews (${remaining} remaining)`}</button>}
  </div>;
}
