import { Router } from "express";
import { prisma } from "../db.js";
import {
  CreateItemSchema,
  IdParamSchema,
  UpdateItemSchema,
  UpdatePurchasedSchema,
} from "../lib/validation.js";
import { serializeItem } from "../lib/serialize.js";

export const wishlistRouter = Router();

wishlistRouter.get("/", async (_req, res, next) => {
  try {
    const items = await prisma.wishlistItem.findMany({
      orderBy: [{ isPurchased: "asc" }, { createdAt: "desc" }],
    });
    res.json({ count: items.length, items: items.map(serializeItem) });
  } catch (err) {
    next(err);
  }
});

wishlistRouter.get("/:id", async (req, res, next) => {
  try {
    const { id } = IdParamSchema.parse(req.params);
    const item = await prisma.wishlistItem.findUnique({ where: { id } });
    if (!item) return res.status(404).json({ error: "wishlist item not found" });
    res.json(serializeItem(item));
  } catch (err) {
    next(err);
  }
});

wishlistRouter.post("/", async (req, res, next) => {
  try {
    const body = CreateItemSchema.parse(req.body);
    const item = await prisma.wishlistItem.create({
      data: {
        name: body.name,
        price: body.price,
        category: body.category ?? null,
        url: body.url ?? null,
      },
    });
    res.status(201).json(serializeItem(item));
  } catch (err) {
    next(err);
  }
});

wishlistRouter.patch("/:id", async (req, res, next) => {
  try {
    const { id } = IdParamSchema.parse(req.params);
    const body = UpdateItemSchema.parse(req.body);
    const existing = await prisma.wishlistItem.findUnique({ where: { id } });
    if (!existing) return res.status(404).json({ error: "wishlist item not found" });
    const item = await prisma.wishlistItem.update({
      where: { id },
      data: {
        ...(body.name !== undefined ? { name: body.name } : {}),
        ...(body.price !== undefined ? { price: body.price } : {}),
        ...(body.category !== undefined ? { category: body.category } : {}),
        ...(body.url !== undefined ? { url: body.url } : {}),
        ...(body.isPurchased !== undefined ? { isPurchased: body.isPurchased } : {}),
      },
    });
    res.json(serializeItem(item));
  } catch (err) {
    next(err);
  }
});

wishlistRouter.delete("/:id", async (req, res, next) => {
  try {
    const { id } = IdParamSchema.parse(req.params);
    const existing = await prisma.wishlistItem.findUnique({ where: { id } });
    if (!existing) return res.status(404).json({ error: "wishlist item not found" });
    await prisma.wishlistItem.delete({ where: { id } });
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

wishlistRouter.patch("/:id/purchased", async (req, res, next) => {
  try {
    const { id } = IdParamSchema.parse(req.params);
    const { isPurchased } = UpdatePurchasedSchema.parse(req.body);
    const existing = await prisma.wishlistItem.findUnique({ where: { id } });
    if (!existing) return res.status(404).json({ error: "wishlist item not found" });
    const item = await prisma.wishlistItem.update({
      where: { id },
      data: { isPurchased },
    });
    res.json(serializeItem(item));
  } catch (err) {
    next(err);
  }
});
