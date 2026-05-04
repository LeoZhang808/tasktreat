import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { WishlistItem } from "@/lib/api";

export interface WishlistFormValues {
  name: string;
  price: number;
  category: string;
  url: string;
}

interface WishlistItemFormProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  initial?: WishlistItem | null;
  onSubmit: (values: WishlistFormValues) => Promise<void> | void;
}

export function WishlistItemForm({ open, onOpenChange, initial, onSubmit }: WishlistItemFormProps) {
  const [name, setName] = useState("");
  const [price, setPrice] = useState("");
  const [category, setCategory] = useState("");
  const [url, setUrl] = useState("");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (open) {
      setName(initial?.name ?? "");
      setPrice(initial ? String(initial.price) : "");
      setCategory(initial?.category ?? "");
      setUrl(initial?.url ?? "");
    }
  }, [open, initial]);

  const isEdit = Boolean(initial);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const priceNum = Number(price);
    if (!name.trim() || !Number.isFinite(priceNum) || priceNum <= 0) return;
    setSubmitting(true);
    try {
      await onSubmit({
        name: name.trim(),
        price: priceNum,
        category: category.trim(),
        url: url.trim(),
      });
      onOpenChange(false);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{isEdit ? "Edit wishlist item" : "Add wishlist item"}</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="wl-name">Name</Label>
            <Input id="wl-name" value={name} onChange={(e) => setName(e.target.value)} required autoFocus />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="wl-price">Price (USD)</Label>
              <Input
                id="wl-price"
                type="number"
                inputMode="decimal"
                step="0.01"
                min="0.01"
                value={price}
                onChange={(e) => setPrice(e.target.value)}
                required
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="wl-category">Category</Label>
              <Input id="wl-category" value={category} onChange={(e) => setCategory(e.target.value)} placeholder="Optional" />
            </div>
          </div>
          <div className="space-y-2">
            <Label htmlFor="wl-url">URL</Label>
            <Input id="wl-url" type="url" value={url} onChange={(e) => setUrl(e.target.value)} placeholder="Optional" />
          </div>
          <DialogFooter>
            <Button type="button" variant="ghost" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={submitting || !name.trim() || !price}>
              {submitting ? "Saving…" : isEdit ? "Save changes" : "Add item"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
