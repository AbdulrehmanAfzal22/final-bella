export function isAccessoryCategory(category){
  return category?.is_accessory===true;
}

export function categoriesForSection(categories,isAccessory,{activeOnly=true}={}){
  return (categories||[]).filter(category=>category.is_accessory===isAccessory&&(!activeOnly||category.is_active===true));
}

export function findCategoryByRoute(categories,routeValue){
  const toSlug=value=>String(value||'').trim().toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/(^-|-$)/g,'');
  const value=String(routeValue||'').trim().toLowerCase();
  const slug=toSlug(value);
  return categories.find(category=>String(category.id).toLowerCase()===value)
    ||categories.find(category=>String(category.slug||'').toLowerCase()===value)
    ||categories.find(category=>toSlug(category.name)===slug)
    ||null;
}