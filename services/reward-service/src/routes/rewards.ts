import { Router } from "express";
import { prisma } from "../db.js";
import { fetchCompletedCount, fetchEligibleItems } from "../lib/clients.js";
import { pickWeighted } from "../lib/select.js";
import { getWeekRange, ymdToDate } from "../lib/week.js";
import { serializeReward } from "../lib/serialize.js";
import { GenerateBodySchema } from "../lib/validation.js";

export const rewardsRouter = Router();

const REWARD_VALUE_PER_TASK = Number(process.env.REWARD_VALUE_PER_TASK ?? 5);

rewardsRouter.get("/current", async (_req, res, next) => {
  try {
    const { weekStart } = getWeekRange();
    const reward = await prisma.weeklyReward.findUnique({
      where: { weekStart: ymdToDate(weekStart) },
    });
    if (!reward) {
      return res.json({ weekStart, reward: null });
    }
    res.json({ weekStart, reward: serializeReward(reward) });
  } catch (err) {
    next(err);
  }
});

rewardsRouter.get("/history", async (_req, res, next) => {
  try {
    const rewards = await prisma.weeklyReward.findMany({
      orderBy: { weekStart: "desc" },
    });
    res.json({ count: rewards.length, rewards: rewards.map(serializeReward) });
  } catch (err) {
    next(err);
  }
});

rewardsRouter.get("/eligibility", async (_req, res, next) => {
  try {
    const { weekStart, weekEnd } = getWeekRange();
    const { completedTasks } = await fetchCompletedCount(weekStart, weekEnd);
    const rewardBudget = completedTasks * REWARD_VALUE_PER_TASK;
    const eligible = await fetchEligibleItems(rewardBudget);
    res.json({
      weekStart,
      weekEnd,
      tasksCompleted: completedTasks,
      rewardValuePerTask: REWARD_VALUE_PER_TASK,
      rewardBudget,
      eligibleItemCount: eligible.count,
      eligibleItems: eligible.items,
    });
  } catch (err) {
    next(err);
  }
});

rewardsRouter.post("/generate-weekly", async (req, res, next) => {
  try {
    const { force } = GenerateBodySchema.parse(req.body ?? {});
    const { weekStart, weekEnd } = getWeekRange();
    const weekStartDate = ymdToDate(weekStart);
    const weekEndDate = ymdToDate(weekEnd);

    const existing = await prisma.weeklyReward.findUnique({
      where: { weekStart: weekStartDate },
    });
    if (existing && !force) {
      return res.json({
        weekStart,
        weekEnd,
        reward: serializeReward(existing),
        regenerated: false,
        reason: "already_generated",
      });
    }

    const { completedTasks } = await fetchCompletedCount(weekStart, weekEnd);
    const rewardBudget = completedTasks * REWARD_VALUE_PER_TASK;

    if (completedTasks <= 0) {
      return res.json({
        weekStart,
        weekEnd,
        reward: null,
        regenerated: false,
        reason: "no_completed_tasks",
        tasksCompleted: completedTasks,
        rewardBudget,
      });
    }

    const eligible = await fetchEligibleItems(rewardBudget);
    if (eligible.count === 0) {
      return res.json({
        weekStart,
        weekEnd,
        reward: null,
        regenerated: false,
        reason: "no_eligible_items",
        tasksCompleted: completedTasks,
        rewardBudget,
      });
    }

    const { item, weight } = pickWeighted(eligible.items);

    // If force=true and a reward exists, replace it (one-per-week invariant).
    if (existing && force) {
      await prisma.weeklyReward.delete({ where: { id: existing.id } });
    }

    const created = await prisma.weeklyReward.create({
      data: {
        wishlistItemId: item.id,
        wishlistItemNameSnapshot: item.name,
        wishlistItemPriceSnapshot: item.price,
        weekStart: weekStartDate,
        weekEnd: weekEndDate,
        tasksCompleted: completedTasks,
        rewardValuePerTask: REWARD_VALUE_PER_TASK,
        rewardBudget,
        selectionWeight: weight,
      },
    });

    res.status(201).json({
      weekStart,
      weekEnd,
      reward: serializeReward(created),
      regenerated: Boolean(existing && force),
    });
  } catch (err) {
    next(err);
  }
});
