import { Router } from "express";
import { prisma } from "../db.js";
import { EligibleQuerySchema } from "../lib/validation.js";
import { serializeItem } from "../lib/serialize.js";

export const internalRouter = Router();

internalRouter.get("/wishlist/eligible", async (req, res, next) => {
  try {
    const { maxPrice } = EligibleQuerySchema.parse(req.query);
    const items = await prisma.wishlistItem.findMany({
      where: {
        isPurchased: false,
        price: { lte: maxPrice },
      },
      orderBy: { price: "asc" },
    });
    const serialized = items.map(serializeItem).map((i) => ({
      id: i.id,
      name: i.name,
      price: i.price,
      category: i.category,
      url: i.url,
    }));
    res.json({ maxPrice, count: serialized.length, items: serialized });
  } catch (err) {
    next(err);
  }
});
