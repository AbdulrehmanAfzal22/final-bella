export const normaliseColour = value => String(value || '').trim().toLowerCase();

export function productOptions(variants = [], requestedColour = '') {
  const active = variants.filter(variant => variant.active);
  const colours = [...new Map(active.map(variant => [normaliseColour(variant.color), variant.color])).values()];
  const colour = colours.find(value => normaliseColour(value) === normaliseColour(requestedColour)) || colours[0] || '';
  return { colours, colour, variants: active.filter(variant => normaliseColour(variant.color) === normaliseColour(colour)) };
}

export function galleryImages(images = [], colour = '') {
  const sorted = [...images].sort((a, b) => a.position - b.position);
  const matching = sorted.filter(image => normaliseColour(image.color) === normaliseColour(colour) && image.color);
  const general = sorted.filter(image => !image.color?.trim());
  return matching.length ? [...matching, ...general] : general.length ? general : sorted;
}
