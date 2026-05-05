import { z } from "zod";

export const GenerateBodySchema = z.object({
  force: z.boolean().optional().default(false),
});
