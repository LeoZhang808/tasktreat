-- CreateEnum
CREATE TYPE "task"."TaskStatus" AS ENUM ('BACKLOG', 'TODO', 'DOING', 'DONE');

-- CreateEnum
CREATE TYPE "task"."TaskPriority" AS ENUM ('LOW', 'MEDIUM', 'HIGH');

-- CreateTable
CREATE TABLE "task"."tasks" (
    "id" SERIAL NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "status" "task"."TaskStatus" NOT NULL DEFAULT 'BACKLOG',
    "priority" "task"."TaskPriority",
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "completed_at" TIMESTAMP(3),

    CONSTRAINT "tasks_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "tasks_status_idx" ON "task"."tasks"("status");

-- CreateIndex
CREATE INDEX "tasks_completed_at_idx" ON "task"."tasks"("completed_at");
