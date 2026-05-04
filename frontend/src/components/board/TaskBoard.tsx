import { useMemo, useState } from "react";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useTasks } from "@/hooks/useTasks";
import type { Task, TaskStatus } from "@/lib/api";
import { TaskCard } from "./TaskCard";
import { TaskFormDialog, type TaskFormValues } from "./TaskFormDialog";

const COLUMNS: Array<{ status: TaskStatus; title: string }> = [
  { status: "BACKLOG", title: "Backlog" },
  { status: "TODO", title: "Todo" },
  { status: "DOING", title: "Doing" },
  { status: "DONE", title: "Done" },
];

interface TaskBoardProps {
  onCompletedCountChange?: () => void;
}

export function TaskBoard({ onCompletedCountChange }: TaskBoardProps) {
  const { tasks, loading, error, create, update, remove, setStatus } = useTasks();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<Task | null>(null);

  const grouped = useMemo(() => {
    const map: Record<TaskStatus, Task[]> = { BACKLOG: [], TODO: [], DOING: [], DONE: [] };
    for (const t of tasks) map[t.status].push(t);
    return map;
  }, [tasks]);

  function openCreate() {
    setEditing(null);
    setDialogOpen(true);
  }

  function openEdit(task: Task) {
    setEditing(task);
    setDialogOpen(true);
  }

  async function handleSubmit(values: TaskFormValues) {
    const payload = {
      title: values.title,
      description: values.description || null,
      priority: values.priority === "NONE" ? null : values.priority,
    };
    if (editing) {
      await update(editing.id, payload);
    } else {
      await create(payload);
    }
  }

  async function handleMove(task: Task, status: TaskStatus) {
    await setStatus(task.id, status);
    if (status === "DONE" || task.status === "DONE") {
      onCompletedCountChange?.();
    }
  }

  return (
    <section className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-semibold tracking-tight">Task Board</h2>
          <p className="text-sm text-muted-foreground">
            Move tasks across columns. Hitting <span className="font-medium">Done</span> stamps a completion time and bumps your weekly reward budget.
          </p>
        </div>
        <Button onClick={openCreate}>
          <Plus className="h-4 w-4" />
          New task
        </Button>
      </div>

      {error && (
        <div className="rounded-md border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive">
          Failed to load tasks: {error}
        </div>
      )}

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
        {COLUMNS.map((col) => (
          <Card key={col.status} className="bg-muted/30">
            <CardHeader className="pb-3">
              <CardTitle className="flex items-center justify-between text-base">
                <span>{col.title}</span>
                <span className="rounded-full bg-background px-2 py-0.5 text-xs text-muted-foreground">
                  {grouped[col.status].length}
                </span>
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              {loading && grouped[col.status].length === 0 && (
                <p className="text-sm text-muted-foreground">Loading…</p>
              )}
              {!loading && grouped[col.status].length === 0 && (
                <p className="text-sm text-muted-foreground">No tasks</p>
              )}
              {grouped[col.status].map((task) => (
                <TaskCard
                  key={task.id}
                  task={task}
                  onMove={(status) => handleMove(task, status)}
                  onEdit={() => openEdit(task)}
                  onDelete={() => remove(task.id)}
                />
              ))}
            </CardContent>
          </Card>
        ))}
      </div>

      <TaskFormDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        initial={editing}
        onSubmit={handleSubmit}
      />
    </section>
  );
}
