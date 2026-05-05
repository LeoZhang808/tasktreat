import { z } from "zod";

export const CreateItemSchema = z.object({
  name: z.string().trim().min(1, "name is required").max(200),
  price: z.coerce.number().positive("price must be greater than 0"),
  category: z.string().trim().max(100).optional().nullable(),
  url: z.string().url().max(2048).optional().nullable(),
});

export const UpdateItemSchema = z.object({
  name: z.string().trim().min(1).max(200).optional(),
  price: z.coerce.number().positive().optional(),
  category: z.string().trim().max(100).optional().nullable(),
  url: z.string().url().max(2048).optional().nullable(),
  isPurchased: z.boolean().optional(),
});

export const UpdatePurchasedSchema = z.object({
  isPurchased: z.boolean(),
});

export const IdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const EligibleQuerySchema = z.object({
  maxPrice: z.coerce.number().nonnegative(),
});
