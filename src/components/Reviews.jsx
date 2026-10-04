import { useState } from "react";
import {Link} from 'react-router-dom';
import {useAuth} from '../hooks/useAuth';
import { useQuery } from "../hooks/useQuery";
import { getProductReviews, addReview } from "../services/reviews";
import { Loading, ErrorState } from "./Feedback";
import RatingSummary from './RatingSummary';
import ReviewList from './ReviewList';
import {getReviewStatus} from '../lib/reviewStatus';

export default function Reviews({ productId }) {
  const { user } = useAuth();
  const q = useQuery(() => getProductReviews(productId), [productId]);
  const [rating, setRating] = useState(5);
  const [comment, setComment] = useState("");
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState("");
  const reviews=q.data||[];

  function writeReview(){document.getElementById('product-review-form')?.scrollIntoView({behavior:'smooth',block:'center'});}

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setNotice("");
    try {
      const result=await addReview({ product_id: productId, user_id: user.id, rating, comment });
      setComment("");
      setNotice(getReviewStatus(result)==='spam'?'Your review is under moderation.':'Your review has been submitted and is awaiting approval.');
    } catch (err) {
      setNotice(err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="reviews" aria-labelledby="product-reviews-title">
      <div className="product-reviews-heading"><h2 id="product-reviews-title">Customer reviews</h2>{user?<button type="button" onClick={writeReview}>Write a review</button>:<Link to={'/login?returnTo='+encodeURIComponent('/product/'+productId)} className="product-reviews-heading__link">Sign in to review</Link>}</div>
      {!q.loading&&!q.error&&<RatingSummary reviews={reviews}/>}

      {q.loading ? (
        <Loading label="Loading reviews…" />
      ) : q.error ? (
        <ErrorState error={q.error} retry={q.refresh} />
      ) : reviews.length === 0 ? (
        <p className="muted">No reviews yet — be the first to share your thoughts.</p>
      ) : (
        <ReviewList reviews={reviews}/>
      )}

      {user ? (
        <form id="product-review-form" onSubmit={submit} className="review-form product-review-form">
          <label>
            Rating
            <select value={rating} onChange={(e) => setRating(Number(e.target.value))}>
              {[5, 4, 3, 2, 1].map((n) => (
                <option key={n} value={n}>{n} / 5</option>
              ))}
            </select>
          </label>
          <label>
            Your review
            <textarea
              value={comment}
              maxLength={2000}
              onChange={(e) => setComment(e.target.value)}
              placeholder="Share your experience with this piece"
            />
          </label>
          {notice && <p className="notice review-notice" role="status">{notice}</p>}
          <button className="button outline" type="submit" disabled={busy}>
            {busy ? "Submitting…" : "Submit review"}
          </button>
        </form>
      ) : (
        <p className="muted">Sign in to leave a review.</p>
      )}
    </section>
  );
}
