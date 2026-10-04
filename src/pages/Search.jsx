import { useEffect, useState } from "react";
import { searchProducts } from "../services/search";

export default function Search() {
  const [products, setProducts] = useState([]);

  useEffect(() => {
    searchProducts({}).then(setProducts);
  }, []);

  return (
    <section>
      <h1>Search Products</h1>
      {products.map((product) => (
        <article key={product.id}>
          {product.name}
        </article>
      ))}
    </section>
  );
}
