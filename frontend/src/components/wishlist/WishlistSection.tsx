import { useState } from "react";
import { ExternalLink, Pencil, Plus, Trash2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useWishlist } from "@/hooks/useWishlist";
import type { WishlistItem } from "@/lib/api";
import { formatDate, formatPrice } from "@/lib/utils";
import { WishlistItemForm, type WishlistFormValues } from "./WishlistItemForm";

interface WishlistSectionProps {
  onChange?: () => void;
}

export function WishlistSection({ onChange }: WishlistSectionProps) {
  const { items, loading, error, create, update, remove, setPurchased } = useWishlist();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<WishlistItem | null>(null);

  function openCreate() {
    setEditing(null);
    setDialogOpen(true);
  }

  function openEdit(item: WishlistItem) {
    setEditing(item);
    setDialogOpen(true);
  }

  async function handleSubmit(values: WishlistFormValues) {
    const payload = {
      name: values.name,
      price: values.price,
      category: values.category || null,
      url: values.url || null,
    };
    if (editing) {
      await update(editing.id, payload);
    } else {
      await create(payload);
    }
    onChange?.();
  }

  async function handleTogglePurchased(item: WishlistItem) {
    await setPurchased(item.id, !item.isPurchased);
    onChange?.();
  }

  async function handleDelete(item: WishlistItem) {
    await remove(item.id);
    onChange?.();
  }

  return (
    <section className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-semibold tracking-tight">Wishlist</h2>
          <p className="text-sm text-muted-foreground">
            Add things you want to buy. Unpurchased items within your weekly budget are eligible for the treat draw.
          </p>
        </div>
        <Button onClick={openCreate}>
          <Plus className="h-4 w-4" />
          Add item
        </Button>
      </div>

      {error && (
        <div className="rounded-md border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive">
          Failed to load wishlist: {error}
        </div>
      )}

      <div className="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-3">
        {loading && items.length === 0 && <p className="text-sm text-muted-foreground">Loading…</p>}
        {!loading && items.length === 0 && (
          <Card className="md:col-span-2 xl:col-span-3">
            <CardContent className="p-6 text-center text-sm text-muted-foreground">
              No wishlist items yet. Add one to make it eligible for a weekly treat.
            </CardContent>
          </Card>
        )}
        {items.map((item) => (
          <Card key={item.id} className={item.isPurchased ? "opacity-60" : undefined}>
            <CardHeader className="pb-2">
              <CardTitle className="flex items-start justify-between gap-2 text-base">
                <span className={item.isPurchased ? "line-through" : ""}>{item.name}</span>
                <span className="shrink-0 font-mono text-base">{formatPrice(item.price)}</span>
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                {item.category && <Badge variant="secondary">{item.category}</Badge>}
                <span>Added {formatDate(item.createdAt)}</span>
                {item.isPurchased && <Badge variant="outline">Purchased</Badge>}
              </div>
              {item.url && (
                <a
                  href={item.url}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex items-center gap-1 text-xs text-primary hover:underline"
                >
                  <ExternalLink className="h-3 w-3" />
                  Link
                </a>
              )}
              <div className="flex flex-wrap gap-2">
                <Button size="sm" variant="outline" onClick={() => handleTogglePurchased(item)}>
                  {item.isPurchased ? "Mark unpurchased" : "Mark purchased"}
                </Button>
                <Button size="sm" variant="ghost" onClick={() => openEdit(item)} aria-label="Edit item">
                  <Pencil className="h-4 w-4" />
                </Button>
                <Button size="sm" variant="ghost" onClick={() => handleDelete(item)} aria-label="Delete item">
                  <Trash2 className="h-4 w-4" />
                </Button>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      <WishlistItemForm
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        initial={editing}
        onSubmit={handleSubmit}
      />
    </section>
  );
}
