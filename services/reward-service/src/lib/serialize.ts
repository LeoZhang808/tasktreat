import type { WeeklyReward } from "../../prisma/generated/index.js";

function ymd(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export function serializeReward(r: WeeklyReward) {
  return {
    id: r.id,
    wishlistItemId: r.wishlistItemId,
    wishlistItemName: r.wishlistItemNameSnapshot,
    wishlistItemPrice: Number(r.wishlistItemPriceSnapshot),
    weekStart: ymd(r.weekStart),
    weekEnd: ymd(r.weekEnd),
    tasksCompleted: r.tasksCompleted,
    rewardValuePerTask: Number(r.rewardValuePerTask),
    rewardBudget: Number(r.rewardBudget),
    selectionWeight: Number(r.selectionWeight),
    selectedAt: r.selectedAt.toISOString(),
  };
}
