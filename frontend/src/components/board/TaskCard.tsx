import { Pencil, Trash2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import type { Task, TaskStatus } from "@/lib/api";
import { formatDate } from "@/lib/utils";

interface TaskCardProps {
  task: Task;
  onMove: (status: TaskStatus) => void;
  onEdit: () => void;
  onDelete: () => void;
}

const PRIORITY_VARIANT: Record<NonNullable<Task["priority"]>, "default" | "secondary" | "destructive" | "outline"> = {
  LOW: "outline",
  MEDIUM: "secondary",
  HIGH: "destructive",
};

const NEXT_BUTTONS: Record<TaskStatus, Array<{ to: TaskStatus; label: string; variant?: "default" | "outline" }>> = {
  BACKLOG: [{ to: "TODO", label: "Move to Todo", variant: "default" }],
  TODO: [
    { to: "BACKLOG", label: "Backlog", variant: "outline" },
    { to: "DOING", label: "Move to Doing", variant: "default" },
  ],
  DOING: [
    { to: "TODO", label: "Back to Todo", variant: "outline" },
    { to: "DONE", label: "Mark Done", variant: "default" },
  ],
  DONE: [{ to: "DOING", label: "Back to Doing", variant: "outline" }],
};

export function TaskCard({ task, onMove, onEdit, onDelete }: TaskCardProps) {
  const moves = NEXT_BUTTONS[task.status];
  return (
    <Card className="hover:shadow-md transition-shadow">
      <CardContent className="p-4 space-y-3">
        <div className="flex items-start justify-between gap-2">
          <h4 className="font-semibold leading-tight">{task.title}</h4>
          {task.priority && (
            <Badge variant={PRIORITY_VARIANT[task.priority]} className="shrink-0">
              {task.priority}
            </Badge>
          )}
        </div>
        {task.description && (
          <p className="text-sm text-muted-foreground line-clamp-3">{task.description}</p>
        )}
        <div className="flex flex-wrap gap-x-3 gap-y-1 text-xs text-muted-foreground">
          <span>Created {formatDate(task.createdAt)}</span>
          {task.completedAt && <span>Done {formatDate(task.completedAt)}</span>}
        </div>
        <div className="flex flex-wrap gap-2 pt-1">
          {moves.map((m) => (
            <Button
              key={m.to}
              size="sm"
              variant={m.variant ?? "default"}
              onClick={() => onMove(m.to)}
            >
              {m.label}
            </Button>
          ))}
          <Button size="sm" variant="ghost" onClick={onEdit} aria-label="Edit task">
            <Pencil className="h-4 w-4" />
          </Button>
          <Button size="sm" variant="ghost" onClick={onDelete} aria-label="Delete task">
            <Trash2 className="h-4 w-4" />
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
