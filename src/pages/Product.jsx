import { useState } from "react";
import { useParams, Link } from "react-router-dom";
import { toast } from "sonner";
import { getProduct } from "../services/catalog";
import { addToCart } from "../services/cart";
import { addToWishlist } from "../services/wishlist";
import { useQuery } from "../hooks/useQuery";
import { useAuth } from "../hooks/useAuth";
import { usePageMetadata } from "../hooks/usePageMetadata";
import { Loading, ErrorState, Empty } from "../components/Feedback";
import ProductGallery from "../components/ProductGallery";
import Reviews from "../components/Reviews";
import ProductInfo from "../components/product/ProductInfo";
import VariantSelector from "../components/product/VariantSelector";
import PurchasePanel from "../components/product/PurchasePanel";
import ProductAccordion from "../components/product/ProductAccordion";
import RecommendationCarousel from "../components/product/RecommendationCarousel";
import { imageUrl } from "../lib/supabase";
import { productOptions, galleryImages } from "../lib/productOptions";
import "../styles/product-detail.css";

export default function Product() {
  const { id } = useParams();
  return <ProductDetail key={id} id={id} />;
}

function ProductDetail({ id }) {
  const { user } = useAuth();
  const query = useQuery(() => getProduct(id), [id]);
  const [color, setColor] = useState(null);
  const [size, setSize] = useState(null);
  const [busy, setBusy] = useState(false);
  const product = query.data;
  const options = productOptions(product?.product_variants, color);
  const selectedVariant = options.variants.find((variant) => variant.size === size);

  usePageMetadata({
    title: product?.name || "Product",
    description: product?.description?.slice(0, 160) || "Discover a considered piece from Bella by RT.",
    image: imageUrl(product?.product_images?.[0]?.path),
    type: "product",
    noindex: !product || product.status !== "published",
  });

  if (query.loading && !query.data) return <Loading label="Opening this piece…" />;
  if (query.error) return <ErrorState error={query.error} retry={query.refresh} />;
  if (!product || product.status !== "published")
    return (
      <Empty
        title="This piece is no longer available"
        text="Browse the rest of the collection instead."
        link="/shop"
        action="View the collection"
      />
    );

  async function handleAddToCart(quantity) {
    if (!user) return toast.error("Please sign in to add items to your bag.");
    if (!selectedVariant) return toast.error("Please choose a colour and size.");
    setBusy(true);
    try {
      await addToCart(selectedVariant.id, quantity);
      toast.success("Added to your bag.");
    } catch (error) {
      toast.error(error.message);
    } finally {
      setBusy(false);
    }
  }

  async function handleWishlist() {
    if (!user) return toast.error("Please sign in to save pieces.");
    try {
      await addToWishlist(user.id, product.id);
      toast.success("Saved to your wishlist.");
    } catch (error) {
      toast.error(error.message);
    }
  }

  return (
    <div className="page product-detail product-detail--editorial">
      <div className="product-detail-grid">
        <ProductGallery key={options.colour} images={galleryImages(product.product_images, options.colour)} />
        <ProductInfo product={product} selectedVariant={selectedVariant}>
          <VariantSelector options={options} allVariants={product.product_variants||[]} size={size} onColorChange={value=>{setColor(value);setSize(null);}} onSizeChange={setSize}/>
          <PurchasePanel selectedVariant={selectedVariant} onAddToCart={handleAddToCart} onWishlist={handleWishlist} busy={busy}/>
          {!selectedVariant&&<p className="product-selection-note">Choose a size to add this piece to your bag.</p>}
          {!user&&<p className="product-signin-note"><Link to={'/login?returnTo='+encodeURIComponent('/product/'+id)}>Sign in</Link> to shop and save your favourites.</p>}
          <ProductAccordion product={product}/>
          <Link className="product-back-link" to="/shop">Back to the collection</Link>
        </ProductInfo>
      </div>
      <Reviews productId={product.id}/>
      <RecommendationCarousel productId={product.id} categoryId={product.category_id}/>
    </div>
  );
}
