import { useState, useEffect } from "react";
import { toast } from "sonner";
import { ImagePlus, Trash2, Upload, X } from "lucide-react";
import { useQuery } from "../hooks/useQuery";
import {
  getCategories,
  createCategory,
  updateCategory,
  updateCategoryImage,
  deleteCategory,
} from "../services/catalog";
import { Loading, ErrorState, Empty } from "../components/Feedback";
import { categoryImageUrl } from "../lib/supabase";
import { uuid } from "../lib/uuid";
import { removeCategoryImage, uploadCategoryImage } from "../services/categoryImages";

const slugify = (value) =>
  value.toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");

function friendlyCategoryError(error){
  if(error?.code==='23505')return 'A category with this name or slug already exists.';
  return error?.message||'Unable to save category.';
}

export default function Categories({isAccessory=false,showHeading=true}) {
  const query = useQuery(() => getCategories(isAccessory), [isAccessory]);
  const [name, setName] = useState("");
  const [slug, setSlug] = useState("");
  const [description, setDescription] = useState("");
  const [displayOrder, setDisplayOrder] = useState("0");
  const [isActive, setIsActive] = useState(true);
  const [categoryIsAccessory, setCategoryIsAccessory] = useState(isAccessory);
  const [editingCategory, setEditingCategory] = useState(null);
  const [slugEdited, setSlugEdited] = useState(false);
  const [imageFile, setImageFile] = useState(null);
  const [imagePreview, setImagePreview] = useState("");
  const [replacementImage, setReplacementImage] = useState(null);
  const [replacementPreview, setReplacementPreview] = useState("");
  const [busy, setBusy] = useState(false);
  const [imageBusy, setImageBusy] = useState(null);

  useEffect(()=>{
    setName('');setSlug('');setDescription('');setDisplayOrder('0');setIsActive(true);setCategoryIsAccessory(isAccessory);setEditingCategory(null);setSlugEdited(false);setImageFile(null);setReplacementImage(null);setBusy(false);setImageBusy(null);
  },[isAccessory]);

  useEffect(() => {
    setImagePreview('');
    if (!imageFile) return;
    const preview = URL.createObjectURL(imageFile);
    setImagePreview(preview);
    return () => URL.revokeObjectURL(preview);
  }, [imageFile]);

  useEffect(() => {
    setReplacementPreview('');
    if (!replacementImage) return;
    const preview = URL.createObjectURL(replacementImage.file);
    setReplacementPreview(preview);
    return () => URL.revokeObjectURL(preview);
  }, [replacementImage]);

  function changeName(value) {
    setName(value);
    if (!slugEdited) setSlug(slugify(value));
  }

  function chooseCreateImage(event) {
    const file = event.target.files?.[0] || null;
    event.target.value = "";
    if (file && (!["image/jpeg", "image/png", "image/webp"].includes(file.type) || file.size > 5 * 1024 * 1024)) {
      toast.error("Use a JPEG, PNG, or WebP image under 5 MB.");
      return;
    }
    setImageFile(file);
  }

  async function submit(event) {
    event.preventDefault();
    setBusy(true);
    let uploadedPath = null;
    const categoryId = editingCategory?.id || uuid();
    const previousImagePath = editingCategory?.image_path || null;
    let saved = false;
    try {
      if (imageFile) uploadedPath = await uploadCategoryImage(imageFile, categoryId);
      const categoryValues = {
        name: name.trim(),
        slug: slugify(slug),
        description: description.trim(),
        display_order: Number(displayOrder) || 0,
        is_active: isActive,
        is_accessory: categoryIsAccessory,
        image_path: uploadedPath || previousImagePath,
        image_alt: uploadedPath ? name.trim() : editingCategory?.image_alt || '',
      };
      if (editingCategory) await updateCategory(categoryId, categoryValues);
      else await createCategory({ id: categoryId, ...categoryValues });
      saved = true;
      if (uploadedPath && previousImagePath) { try { await removeCategoryImage(previousImagePath); } catch (cleanupError) { console.warn('Previous category image cleanup requires retry', cleanupError.message); }}
      uploadedPath = null;
      setName(''); setSlug(''); setDescription(''); setDisplayOrder('0'); setIsActive(true); setCategoryIsAccessory(isAccessory); setSlugEdited(false); setImageFile(null); setEditingCategory(null);
      await query.refresh();
      toast.success(editingCategory ? 'Category updated.' : 'Category created.');
    } catch (error) {
      if (!saved&&uploadedPath) { try { await removeCategoryImage(uploadedPath); } catch (cleanupError) { console.warn('Category image cleanup requires retry', cleanupError.message); }}
      toast.error(saved?'Category saved, but the list could not be refreshed.':friendlyCategoryError(error));
    } finally { setBusy(false); }
  }

  function editCategory(category) {
    setEditingCategory(category);
    setName(category.name);
    setSlug(category.slug);
    setDescription(category.description || '');
    setDisplayOrder(String(category.display_order || 0));
    setIsActive(category.is_active !== false);
    setCategoryIsAccessory(category.is_accessory===true);
    setSlugEdited(true);
    setImageFile(null);
    setReplacementImage(null);
  }

  function cancelEdit() {
    setEditingCategory(null);
    setName(''); setSlug(''); setDescription(''); setDisplayOrder('0'); setIsActive(true); setCategoryIsAccessory(isAccessory); setSlugEdited(false); setImageFile(null);
  }

  async function replaceImage(category, file) {
    if (!file) return;
    setImageBusy(category.id);
    let uploadedPath = null;
    let committed = false;
    try {
      uploadedPath = await uploadCategoryImage(file, category.id);
      await updateCategoryImage(category.id, uploadedPath, category.name);
      committed = true;
      uploadedPath = null;
      if (category.image_path) { try { await removeCategoryImage(category.image_path); } catch (cleanupError) { console.warn('Previous category image cleanup requires retry', cleanupError.message); }}
      await query.refresh();
      toast.success('Category image updated.');
      return true;
    } catch (error) {
      if (!committed&&uploadedPath) { try { await removeCategoryImage(uploadedPath); } catch (cleanupError) { console.warn('Category image cleanup requires retry', cleanupError.message); }}
      toast.error(committed?'Image saved, but the category list could not be refreshed.':friendlyCategoryError(error));
      return committed;
    } finally { setImageBusy(null); }
  }

  function chooseReplacementImage(category, event) {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type) || file.size > 5 * 1024 * 1024) {
      toast.error('Use a JPEG, PNG, or WebP image under 5 MB.');
      return;
    }
    setReplacementImage({ categoryId: category.id, file });
  }

  async function saveReplacement(category) {
    if (!replacementImage || replacementImage.categoryId !== category.id) return;
    if (await replaceImage(category, replacementImage.file)) setReplacementImage(null);
  }

  async function clearImage(category) {
    setImageBusy(category.id);
    try {
      await updateCategoryImage(category.id, null, '');
      if (category.image_path) { try { await removeCategoryImage(category.image_path); } catch (cleanupError) { console.warn('Category image cleanup requires retry', cleanupError.message); }}
      await query.refresh();
      toast.success('Category image removed. Product imagery will be used instead.');
    } catch (error) { toast.error(error.message); }
    finally { setImageBusy(null); }
  }

  async function removeCategory(category) {
    try {
      await deleteCategory(category.id);
      if (category.image_path) { try { await removeCategoryImage(category.image_path); } catch (cleanupError) { console.warn('Deleted category image cleanup requires retry', cleanupError.message); }}
      await query.refresh();
      toast.success('Category deleted.');
    } catch (error) { toast.error(error.message); }
  }

  return (
    <div className="admin-categories-page">
      {showHeading&&<div className="section-heading">
        <div>
          <p className="eyebrow">ORGANISE {isAccessory?'ACCESSORIES':'COLLECTIONS'}</p>
          <h1>{isAccessory?'Accessories':'Collections'} categories</h1>
          <p className="admin-page-intro">Create category destinations and choose their campaign imagery.</p>
        </div>
      </div>}
      <section className="admin-category-create panel" aria-labelledby="category-create-title">
        <h2 id="category-create-title">{editingCategory ? `Edit ${editingCategory.name}` : 'Create category'}</h2>
        <form onSubmit={submit} className="admin-category-form">
          <label>Category name<input value={name} onChange={event=>changeName(event.target.value)} placeholder="For example, Embroidered" required maxLength="80"/></label>
          <label>Category slug<input value={slug} onChange={event=>{setSlug(event.target.value);setSlugEdited(true);}} placeholder="embroidered" required maxLength="80" pattern="[a-z0-9]+(-[a-z0-9]+)*"/><small>Used in the collection address: /collections/{slug||'category-name'}</small></label>
          <label className="admin-category-description">Description<textarea value={description} onChange={event=>setDescription(event.target.value)} maxLength="500" rows="3" placeholder="A short collection introduction"/></label>
          <label>Display order<input type="number" min="0" step="1" value={displayOrder} onChange={event=>setDisplayOrder(event.target.value)} required/></label>
          <label className="admin-category-toggle"><input type="checkbox" checked={isActive} onChange={event=>setIsActive(event.target.checked)}/> Active on the storefront</label>
          <label className="admin-category-toggle"><input type="checkbox" checked={categoryIsAccessory} onChange={event=>setCategoryIsAccessory(event.target.checked)}/> Store under Accessories</label>
          <label className="admin-category-upload">
            <span>Category image <small>Optional · JPEG, PNG or WebP · 5 MB max</small></span>
            <span className="admin-category-upload__control">
              <ImagePlus size={17}/><span>{imageFile?imageFile.name:'Choose category image'}</span><input type="file" accept="image/jpeg,image/png,image/webp" onChange={chooseCreateImage}/></span>
          </label>
          {imagePreview&&<div className="admin-category-preview"><img src={imagePreview} alt={name?`${name} category preview`:'Category image preview'}/><button type="button" onClick={()=>setImageFile(null)} aria-label="Remove selected category image"><X size={15}/> Remove image</button></div>}
          <div className="admin-category-form__actions">{editingCategory&&<button className="button outline" type="button" onClick={cancelEdit} disabled={busy}>Cancel</button>}<button className="button" type="submit" disabled={busy||!name.trim()||!slugify(slug)}>{busy?'Saving category…':<><Upload size={15}/> {editingCategory?'Save changes':'Save category'}</>}</button></div>
        </form>
      </section>
      <section className="admin-category-list" aria-label="Existing categories">
        <div className="admin-category-list__heading"><h2>Existing categories</h2>{query.data&&<span>{query.data.length} total</span>}</div>
        {query.loading&&!query.data?<Loading/>:query.error?<ErrorState error={query.error} retry={query.refresh}/>:!query.data?.length?<Empty title="No categories yet" text="Create your first category above." link={null} action={null}/>:<div className="admin-category-rows">{query.data.map(category=><article className="admin-category-row" key={category.id}>
          <div className="admin-category-row__image">{category.image_path?<img src={categoryImageUrl(category.image_path)} alt={category.image_alt||category.name} loading="lazy"/>:<span aria-hidden="true"><ImagePlus size={20}/></span>}</div>
          <div className="admin-category-row__info"><strong>{category.name}</strong><span>/{category.slug}</span>{category.description&&<small>{category.description}</small>}<small>{category.is_active===false?'Inactive':'Active'} · Order {category.display_order||0}</small></div>
          <div className="admin-category-row__actions"><button className="admin-category-remove-image" type="button" onClick={()=>editCategory(category)}>Edit category</button>{replacementImage?.categoryId===category.id?<><div className="admin-category-replacement-preview"><img src={replacementPreview} alt={`${category.name} replacement preview`}/><span>{replacementImage.file.name}</span></div><button className="admin-category-image-button" type="button" disabled={imageBusy===category.id} onClick={()=>saveReplacement(category)}><Upload size={14}/><span>{imageBusy===category.id?'Uploading…':'Save image'}</span></button><button className="admin-category-remove-image" type="button" disabled={imageBusy===category.id} onClick={()=>setReplacementImage(null)}><X size={14}/> Cancel</button></>:<label className="admin-category-image-button"><Upload size={14}/><span>{category.image_path?'Replace image':'Add image'}</span><input type="file" accept="image/jpeg,image/png,image/webp" disabled={imageBusy===category.id} onChange={event=>chooseReplacementImage(category,event)}/></label>}{category.image_path&&replacementImage?.categoryId!==category.id&&<button className="admin-category-remove-image" type="button" disabled={imageBusy===category.id} onClick={()=>clearImage(category)} aria-label={`Remove image for ${category.name}`}><X size={14}/> Remove image</button>}<button className="text-button admin-category-delete" type="button" onClick={()=>removeCategory(category)}><Trash2 size={14}/> Delete category</button></div>
        </article>)}</div>}
      </section>
    </div>
  );
}
