import { z } from "zod";

export const TaskStatusSchema = z.enum(["BACKLOG", "TODO", "DOING", "DONE"]);
export const TaskPrioritySchema = z.enum(["LOW", "MEDIUM", "HIGH"]);

export const CreateTaskSchema = z.object({
  title: z.string().trim().min(1, "title is required").max(200),
  description: z.string().trim().max(5000).optional().nullable(),
  status: TaskStatusSchema.optional(),
  priority: TaskPrioritySchema.optional().nullable(),
});

export const UpdateTaskSchema = z.object({
  title: z.string().trim().min(1).max(200).optional(),
  description: z.string().trim().max(5000).optional().nullable(),
  priority: TaskPrioritySchema.optional().nullable(),
});

export const UpdateStatusSchema = z.object({
  status: TaskStatusSchema,
});

export const IdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const ListQuerySchema = z.object({
  status: TaskStatusSchema.optional(),
});

export const CompletedCountQuerySchema = z.object({
  weekStart: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "weekStart must be YYYY-MM-DD"),
  weekEnd: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "weekEnd must be YYYY-MM-DD"),
});
