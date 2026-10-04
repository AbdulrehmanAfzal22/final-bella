export default function VariantSelector({options,allVariants=[],size,onColorChange,onSizeChange}){
  const colorOptions=[...new Map(options.colours.map(color=>[color,allVariants.find(variant=>variant.active&&variant.color===color)]))];

  return <div className="product-variant-selector">
    {options.colours.length>0&&<fieldset className="product-color-selector"><legend>Colour <span>{options.colour}</span></legend><div className="product-color-selector__options">{colorOptions.map(([color,variant])=><button key={color} type="button" className={options.colour===color?'is-selected':''} aria-label={`Choose ${color} colour`} aria-pressed={options.colour===color} onClick={()=>onColorChange(color)}><span style={{'--variant-swatch':variant?.color_hex||'#d8d2c9'}}/></button>)}</div></fieldset>}
    <fieldset className="product-size-selector"><legend>Size <span>{size||'Select a size'}</span></legend><div className="product-size-selector__options">{options.variants.map(variant=>{
      const unavailable=variant.stock<1;
      return <button key={variant.id} type="button" className={`${size===variant.size?'is-selected':''} ${unavailable?'is-unavailable':''}`} aria-pressed={size===variant.size} aria-label={`${variant.size}${unavailable?' - out of stock':''}`} disabled={unavailable} onClick={()=>onSizeChange(variant.size)}>{variant.size}</button>;
    })}</div></fieldset>
  </div>;
}