import {getReviewStatus} from '../../lib/reviewStatus';

export default function ReviewStatusBadge({review,status}){
  const value=getReviewStatus(review,status);
  return <span className={`review-status-badge review-status-badge--${value}`}>{value}</span>;
}
