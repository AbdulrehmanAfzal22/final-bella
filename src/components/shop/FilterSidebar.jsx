export function FilterControls({categories=[],colors=[],sizes=[],params,change}){
  const selectedSize=params.get('size')||'';
  const selectedColor=params.get('color')||'';

  return <div className="shop-filter-controls">
    <label className="shop-filter-controls__search"><span>Search pieces</span><input type="search" value={params.get('q')||''} placeholder="Designer, style, detail" onChange={event=>change('q',event.target.value)}/></label>
    <label><span>Category</span><select value={params.get('category')||''} onChange={event=>change('category',event.target.value)}><option value="">All categories</option>{categories.map(category=><option key={category.id} value={category.id}>{category.name}</option>)}</select></label>
    <label><span>Maximum price · USD</span><input type="number" min="0" step="1" inputMode="decimal" placeholder="No limit" value={params.get('max')||''} onChange={event=>change('max',event.target.value)}/></label>
    <fieldset className="shop-filter-colors"><legend>Colour</legend><div className="shop-filter-colors__options"><button type="button" className={!selectedColor?'is-selected':''} aria-pressed={!selectedColor} onClick={()=>change('color','')}>All colours</button>{colors.map(color=><button type="button" key={color.name} className={selectedColor===color.name?'is-selected':''} aria-label={`Filter by ${color.name}`} aria-pressed={selectedColor===color.name} onClick={()=>change('color',selectedColor===color.name?'':color.name)}><span className="shop-filter-colors__swatch" style={{'--swatch-color':color.hex||'#d8d2c9'}} aria-hidden="true"/><span>{color.name}</span></button>)}</div></fieldset>
    <fieldset className="shop-filter-sizes"><legend>Size</legend><div className="shop-filter-sizes__options"><button type="button" className={!selectedSize?'is-selected':''} aria-pressed={!selectedSize} onClick={()=>change('size','')}>All</button>{sizes.map(size=><button type="button" key={size} className={selectedSize===size?'is-selected':''} aria-pressed={selectedSize===size} onClick={()=>change('size',selectedSize===size?'':size)}>{size}</button>)}</div></fieldset>
    <label className="shop-filter-stock"><input type="checkbox" checked={Boolean(params.get('stock'))} onChange={event=>change('stock',event.target.checked?'1':'')}/><span>In stock only</span></label>
  </div>;
}

export default function FilterSidebar({categories,colors,sizes,params,change,onClear}){
  const activeCount=['q','category','max','color','size','stock'].filter(key=>params.has(key)).length;

  return <aside className="shop-filter-sidebar" aria-label="Shop filters">
    <div className="shop-filter-sidebar__heading"><h2>Refine</h2>{activeCount>0&&<button type="button" onClick={onClear}>Clear all</button>}</div>
    <FilterControls categories={categories} colors={colors} sizes={sizes} params={params} change={change}/>
  </aside>;
}