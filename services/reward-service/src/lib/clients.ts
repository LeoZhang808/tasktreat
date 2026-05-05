// Typed wrappers around inter-service HTTP calls.
// Uses the Node 20 global fetch — no extra HTTP library required.

const TASK_SERVICE_URL = process.env.TASK_SERVICE_URL ?? "http://localhost:4001";
const WISHLIST_SERVICE_URL = process.env.WISHLIST_SERVICE_URL ?? "http://localhost:4002";

export interface CompletedCountResponse {
  weekStart: string;
  weekEnd: string;
  completedTasks: number;
}

export interface EligibleItem {
  id: number;
  name: string;
  price: number;
  category: string | null;
  url: string | null;
}

export interface EligibleItemsResponse {
  maxPrice: number;
  count: number;
  items: EligibleItem[];
}

async function getJson<T>(url: string): Promise<T> {
  const res = await fetch(url, { headers: { accept: "application/json" } });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`upstream ${res.status} ${res.statusText} from ${url}: ${body}`);
  }
  return (await res.json()) as T;
}

export async function fetchCompletedCount(
  weekStart: string,
  weekEnd: string,
): Promise<CompletedCountResponse> {
  const url = `${TASK_SERVICE_URL}/internal/tasks/completed-count?weekStart=${weekStart}&weekEnd=${weekEnd}`;
  return getJson<CompletedCountResponse>(url);
}

export async function fetchEligibleItems(maxPrice: number): Promise<EligibleItemsResponse> {
  const url = `${WISHLIST_SERVICE_URL}/internal/wishlist/eligible?maxPrice=${maxPrice}`;
  return getJson<EligibleItemsResponse>(url);
}
