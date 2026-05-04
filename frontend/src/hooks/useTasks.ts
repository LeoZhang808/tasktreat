import { useCallback, useEffect, useState } from "react";
import { api, type Task, type TaskStatus, type TaskPriority } from "@/lib/api";

interface ListResponse {
  count: number;
  tasks: Task[];
}

export interface CreateTaskInput {
  title: string;
  description?: string | null;
  priority?: TaskPriority | null;
  status?: TaskStatus;
}

export interface UpdateTaskInput {
  title?: string;
  description?: string | null;
  priority?: TaskPriority | null;
}

export function useTasks() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await api.get<ListResponse>("/tasks");
      setTasks(data.tasks);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const create = useCallback(async (input: CreateTaskInput) => {
    const t = await api.post<Task>("/tasks", input);
    await refresh();
    return t;
  }, [refresh]);

  const update = useCallback(async (id: number, input: UpdateTaskInput) => {
    const t = await api.patch<Task>(`/tasks/${id}`, input);
    await refresh();
    return t;
  }, [refresh]);

  const remove = useCallback(async (id: number) => {
    await api.delete<void>(`/tasks/${id}`);
    await refresh();
  }, [refresh]);

  const setStatus = useCallback(async (id: number, status: TaskStatus) => {
    const t = await api.patch<Task>(`/tasks/${id}/status`, { status });
    await refresh();
    return t;
  }, [refresh]);

  return { tasks, loading, error, refresh, create, update, remove, setStatus };
}
