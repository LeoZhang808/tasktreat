import { Router } from "express";
import { prisma } from "../db.js";
import { CompletedCountQuerySchema } from "../lib/validation.js";

export const internalRouter = Router();

internalRouter.get("/tasks/completed-count", async (req, res, next) => {
  try {
    const { weekStart, weekEnd } = CompletedCountQuerySchema.parse(req.query);

    // Inclusive [weekStart 00:00 UTC, weekEnd 23:59:59.999 UTC]
    const start = new Date(`${weekStart}T00:00:00.000Z`);
    const end = new Date(`${weekEnd}T23:59:59.999Z`);

    const completedTasks = await prisma.task.count({
      where: {
        status: "DONE",
        completedAt: { gte: start, lte: end },
      },
    });

    res.json({ weekStart, weekEnd, completedTasks });
  } catch (err) {
    next(err);
  }
});
