import { Router } from "express";
import { TaskStatus } from "../../prisma/generated/index.js";
import { prisma } from "../db.js";
import {
  CreateTaskSchema,
  IdParamSchema,
  ListQuerySchema,
  UpdateStatusSchema,
  UpdateTaskSchema,
} from "../lib/validation.js";

export const tasksRouter = Router();

tasksRouter.get("/", async (req, res, next) => {
  try {
    const { status } = ListQuerySchema.parse(req.query);
    const tasks = await prisma.task.findMany({
      where: status ? { status } : undefined,
      orderBy: [{ status: "asc" }, { createdAt: "desc" }],
    });
    res.json({ count: tasks.length, tasks });
  } catch (err) {
    next(err);
  }
});

tasksRouter.get("/:id", async (req, res, next) => {
  try {
    const { id } = IdParamSchema.parse(req.params);
    const task = await prisma.task.findUnique({ where: { id } });
    if (!task) return res.status(404).json({ error: "task not found" });
    res.json(task);
  } catch (err) {
    next(err);
  }
});

tasksRouter.post("/", async (req, res, next) => {
  try {
    const body = CreateTaskSchema.parse(req.body);
    const task = await prisma.task.create({
      data: {
        title: body.title,
        description: body.description ?? null,
        status: body.status ?? TaskStatus.BACKLOG,
        priority: body.priority ?? null,
        completedAt: body.status === TaskStatus.DONE ? new Date() : null,
      },
    });
    res.status(201).json(task);
  } catch (err) {
    next(err);
  }
});

tasksRouter.patch("/:id", async (req, res, next) => {
  try {
    const { id } = IdParamSchema.parse(req.params);
    const body = UpdateTaskSchema.parse(req.body);
    const existing = await prisma.task.findUnique({ where: { id } });
    if (!existing) return res.status(404).json({ error: "task not found" });
    const task = await prisma.task.update({
      where: { id },
      data: {
        ...(body.title !== undefined ? { title: body.title } : {}),
        ...(body.description !== undefined ? { description: body.description } : {}),
        ...(body.priority !== undefined ? { priority: body.priority } : {}),
      },
    });
    res.json(task);
  } catch (err) {
    next(err);
  }
});

tasksRouter.delete("/:id", async (req, res, next) => {
  try {
    const { id } = IdParamSchema.parse(req.params);
    const existing = await prisma.task.findUnique({ where: { id } });
    if (!existing) return res.status(404).json({ error: "task not found" });
    await prisma.task.delete({ where: { id } });
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

tasksRouter.patch("/:id/status", async (req, res, next) => {
  try {
    const { id } = IdParamSchema.parse(req.params);
    const { status } = UpdateStatusSchema.parse(req.body);
    const existing = await prisma.task.findUnique({ where: { id } });
    if (!existing) return res.status(404).json({ error: "task not found" });

    // Stamp completedAt only the first time a task enters DONE.
    // Per MVP spec, do NOT clear completedAt when moving back out of DONE.
    const shouldStampCompletion =
      status === TaskStatus.DONE && existing.completedAt === null;

    const task = await prisma.task.update({
      where: { id },
      data: {
        status,
        ...(shouldStampCompletion ? { completedAt: new Date() } : {}),
      },
    });
    res.json(task);
  } catch (err) {
    next(err);
  }
});
