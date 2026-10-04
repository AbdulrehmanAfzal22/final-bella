export default function CollectionNav({categories=[],params,onSelect}){
  const selectedCategory=params.get('category');
  const isNew=params.get('sort')==='newest'&&!selectedCategory;
  const allSelected=!selectedCategory&&!isNew;

  return <nav className="shop-collection-nav" aria-label="Browse the collection">
    <span className="shop-collection-nav__label">The edit</span>
    <div className="shop-collection-nav__items">
      <button type="button" className={allSelected?'is-active':''} aria-current={allSelected?'page':undefined} onClick={()=>onSelect('all')}>All</button>
      <button type="button" className={isNew?'is-active':''} aria-current={isNew?'page':undefined} onClick={()=>onSelect('newest')}>New arrivals</button>
      {categories.length>0&&<span className="shop-collection-nav__group">Categories</span>}
      {categories.map(category=><button key={category.id} type="button" className={selectedCategory===category.id?'is-active':''} aria-current={selectedCategory===category.id?'page':undefined} onClick={()=>onSelect(category.id)}>{category.name}</button>)}
    </div>
  </nav>;
}