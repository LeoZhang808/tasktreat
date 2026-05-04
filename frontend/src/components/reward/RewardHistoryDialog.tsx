import { useEffect, useState } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import type { Reward } from "@/lib/api";
import { formatPrice } from "@/lib/utils";

interface RewardHistoryDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  load: () => Promise<Reward[]>;
}

export function RewardHistoryDialog({ open, onOpenChange, load }: RewardHistoryDialogProps) {
  const [rewards, setRewards] = useState<Reward[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    let cancelled = false;
    setRewards(null);
    setError(null);
    load()
      .then((rs) => {
        if (!cancelled) setRewards(rs);
      })
      .catch((e: unknown) => {
        if (!cancelled) setError((e as Error).message);
      });
    return () => {
      cancelled = true;
    };
  }, [open, load]);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>Reward history</DialogTitle>
        </DialogHeader>
        {error && (
          <div className="rounded-md border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive">
            {error}
          </div>
        )}
        {!error && rewards == null && <p className="text-sm text-muted-foreground">Loading…</p>}
        {!error && rewards && rewards.length === 0 && (
          <p className="text-sm text-muted-foreground">No rewards generated yet.</p>
        )}
        {!error && rewards && rewards.length > 0 && (
          <div className="max-h-[60vh] overflow-y-auto">
            <table className="w-full text-sm">
              <thead className="text-left text-xs text-muted-foreground">
                <tr>
                  <th className="py-2 pr-2">Week</th>
                  <th className="py-2 pr-2">Treat</th>
                  <th className="py-2 pr-2">Price</th>
                  <th className="py-2 pr-2">Tasks</th>
                  <th className="py-2 pr-2">Budget</th>
                </tr>
              </thead>
              <tbody>
                {rewards.map((r) => (
                  <tr key={r.id} className="border-t">
                    <td className="py-2 pr-2 font-mono text-xs">
                      {r.weekStart} → {r.weekEnd}
                    </td>
                    <td className="py-2 pr-2">{r.wishlistItemName}</td>
                    <td className="py-2 pr-2 font-mono">{formatPrice(r.wishlistItemPrice)}</td>
                    <td className="py-2 pr-2">{r.tasksCompleted}</td>
                    <td className="py-2 pr-2 font-mono">{formatPrice(r.rewardBudget)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
