const reviewStatuses=new Set(['pending','approved','spam','rejected']);

export function getReviewStatus(review,override){
  if(reviewStatuses.has(override))return override;
  if(reviewStatuses.has(review?.status))return review.status;
  return review?.approved===true?'approved':'pending';
}