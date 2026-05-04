import { useCallback, useEffect, useState } from "react";
import { api, type WishlistItem } from "@/lib/api";

interface ListResponse {
  count: number;
  items: WishlistItem[];
}

export interface CreateItemInput {
  name: string;
  price: number;
  category?: string | null;
  url?: string | null;
}

export interface UpdateItemInput {
  name?: string;
  price?: number;
  category?: string | null;
  url?: string | null;
  isPurchased?: boolean;
}

export function useWishlist() {
  const [items, setItems] = useState<WishlistItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await api.get<ListResponse>("/wishlist");
      setItems(data.items);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const create = useCallback(async (input: CreateItemInput) => {
    const i = await api.post<WishlistItem>("/wishlist", input);
    await refresh();
    return i;
  }, [refresh]);

  const update = useCallback(async (id: number, input: UpdateItemInput) => {
    const i = await api.patch<WishlistItem>(`/wishlist/${id}`, input);
    await refresh();
    return i;
  }, [refresh]);

  const remove = useCallback(async (id: number) => {
    await api.delete<void>(`/wishlist/${id}`);
    await refresh();
  }, [refresh]);

  const setPurchased = useCallback(async (id: number, isPurchased: boolean) => {
    const i = await api.patch<WishlistItem>(`/wishlist/${id}/purchased`, { isPurchased });
    await refresh();
    return i;
  }, [refresh]);

  return { items, loading, error, refresh, create, update, remove, setPurchased };
}
