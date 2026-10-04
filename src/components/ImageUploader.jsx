import { useState } from "react";
import { uploadProductImage } from "../services/storage";

export default function ImageUploader({ productId, onUploaded }) {
  const [uploading, setUploading] = useState(false);

  async function handleUpload(event) {
    const file = event.target.files?.[0];
    if (!file) return;

    setUploading(true);

    try {
      const image = await uploadProductImage(file, productId);
      onUploaded?.(image);
    } finally {
      setUploading(false);
    }
  }

  return (
    <div>
      <input type="file" accept="image/*" onChange={handleUpload} />
      {uploading && <p>Uploading...</p>}
    </div>
  );
}
