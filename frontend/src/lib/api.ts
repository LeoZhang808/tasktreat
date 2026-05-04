// Thin fetch wrapper. The frontend always calls /api/... and Vite (or the
// production proxy/ingress) routes each prefix to the right service.
const BASE = (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? "/api";

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    ...init,
    headers: {
      "content-type": "application/json",
      accept: "application/json",
      ...(init?.headers ?? {}),
    },
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`${res.status} ${res.statusText}: ${text}`);
  }
  if (res.status === 204) return undefined as unknown as T;
  return (await res.json()) as T;
}

export const api = {
  get: <T>(path: string) => request<T>(path),
  post: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: "POST", body: body == null ? undefined : JSON.stringify(body) }),
  patch: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: "PATCH", body: body == null ? undefined : JSON.stringify(body) }),
  delete: <T>(path: string) => request<T>(path, { method: "DELETE" }),
};

// Domain types

export type TaskStatus = "BACKLOG" | "TODO" | "DOING" | "DONE";
export type TaskPriority = "LOW" | "MEDIUM" | "HIGH";

export interface Task {
  id: number;
  title: string;
  description: string | null;
  status: TaskStatus;
  priority: TaskPriority | null;
  createdAt: string;
  updatedAt: string;
  completedAt: string | null;
}

export interface WishlistItem {
  id: number;
  name: string;
  price: number;
  category: string | null;
  url: string | null;
  isPurchased: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface Reward {
  id: number;
  wishlistItemId: number;
  wishlistItemName: string;
  wishlistItemPrice: number;
  weekStart: string;
  weekEnd: string;
  tasksCompleted: number;
  rewardValuePerTask: number;
  rewardBudget: number;
  selectionWeight: number;
  selectedAt: string;
}

export interface EligibilitySummary {
  weekStart: string;
  weekEnd: string;
  tasksCompleted: number;
  rewardValuePerTask: number;
  rewardBudget: number;
  eligibleItemCount: number;
  eligibleItems: Array<Pick<WishlistItem, "id" | "name" | "price" | "category" | "url">>;
}

export interface GenerateResult {
  weekStart: string;
  weekEnd: string;
  reward: Reward | null;
  regenerated?: boolean;
  reason?: "already_generated" | "no_completed_tasks" | "no_eligible_items";
  tasksCompleted?: number;
  rewardBudget?: number;
}
