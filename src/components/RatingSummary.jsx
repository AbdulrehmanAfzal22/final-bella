import {Star} from 'lucide-react';

export default function RatingSummary({reviews=[]}){
  const count=reviews.length;
  const average=count?reviews.reduce((sum,review)=>sum+Number(review.rating||0),0)/count:0;
  const rounded=Math.round(average);
  return <div className="product-review-summary" aria-label={count?`Average rating ${average.toFixed(1)} out of 5 from ${count} approved ${count===1?'review':'reviews'}`:'No approved reviews yet'}>
    <div className="rating-summary__stars" aria-hidden="true">{[1,2,3,4,5].map(value=><Star key={value} size={17} fill={value<=rounded?'currentColor':'none'}/>)}</div>
    <strong className="product-review-summary__score">{count?average.toFixed(1):'—'}</strong>
    <span className="product-review-summary__count">{count?`Based on ${count} ${count===1?'review':'reviews'}`:'No approved reviews yet'}</span>
  </div>;
}
