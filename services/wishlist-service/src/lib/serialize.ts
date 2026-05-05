import type { WishlistItem } from "../../prisma/generated/index.js";

// Prisma returns Decimal as a Decimal.js object; the API contract is a plain number.
export function serializeItem(item: WishlistItem) {
  return {
    ...item,
    price: Number(item.price),
  };
}
