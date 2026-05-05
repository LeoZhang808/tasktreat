-- CreateTable
CREATE TABLE "reward"."weekly_rewards" (
    "id" SERIAL NOT NULL,
    "wishlist_item_id" INTEGER NOT NULL,
    "wishlist_item_name_snapshot" TEXT NOT NULL,
    "wishlist_item_price_snapshot" DECIMAL(10,2) NOT NULL,
    "week_start" DATE NOT NULL,
    "week_end" DATE NOT NULL,
    "tasks_completed" INTEGER NOT NULL,
    "reward_value_per_task" DECIMAL(10,2) NOT NULL,
    "reward_budget" DECIMAL(10,2) NOT NULL,
    "selection_weight" DECIMAL(10,2) NOT NULL,
    "selected_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "weekly_rewards_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "weekly_rewards_week_start_idx" ON "reward"."weekly_rewards"("week_start");

-- CreateIndex
CREATE UNIQUE INDEX "weekly_rewards_week_start_key" ON "reward"."weekly_rewards"("week_start");
