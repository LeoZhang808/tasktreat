// Weighted random selection where each item's weight equals its price.
// More expensive eligible items have a higher chance, but cheaper ones can still win.

export function pickWeighted<T extends { price: number }>(
  items: T[],
): { item: T; weight: number; totalWeight: number } {
  if (items.length === 0) {
    throw new Error("pickWeighted called with empty list");
  }
  const total = items.reduce((sum, i) => sum + i.price, 0);
  if (total <= 0) {
    // Fallback: every weight is zero — pick uniformly.
    const idx = Math.floor(Math.random() * items.length);
    return { item: items[idx], weight: items[idx].price, totalWeight: total };
  }
  const r = Math.random() * total;
  let acc = 0;
  for (const item of items) {
    acc += item.price;
    if (r < acc) {
      return { item, weight: item.price, totalWeight: total };
    }
  }
  // Floating-point edge case fallback.
  const last = items[items.length - 1];
  return { item: last, weight: last.price, totalWeight: total };
}
