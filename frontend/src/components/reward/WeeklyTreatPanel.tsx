import { useImperativeHandle, useState, forwardRef } from "react";
import { Gift, RotateCw, Sparkles, History } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { useRewards } from "@/hooks/useRewards";
import { formatPrice } from "@/lib/utils";
import { RewardHistoryDialog } from "./RewardHistoryDialog";

export interface WeeklyTreatPanelHandle {
  refresh: () => Promise<void>;
}

const REASON_TEXT: Record<string, string> = {
  no_completed_tasks: "Complete a task this week to unlock a reward.",
  no_eligible_items: "No wishlist items fit this week's budget. Add cheaper items or complete more tasks.",
  already_generated: "A reward is already locked in for this week.",
};

export const WeeklyTreatPanel = forwardRef<WeeklyTreatPanelHandle>((_props, ref) => {
  const { eligibility, current, loading, error, generating, refresh, generate, fetchHistory } = useRewards();
  const [historyOpen, setHistoryOpen] = useState(false);
  const [generateMessage, setGenerateMessage] = useState<string | null>(null);

  useImperativeHandle(ref, () => ({ refresh }), [refresh]);

  async function handleGenerate(force = false) {
    setGenerateMessage(null);
    try {
      const result = await generate(force);
      if (result.reason && REASON_TEXT[result.reason]) {
        setGenerateMessage(REASON_TEXT[result.reason]);
      }
    } catch (e) {
      setGenerateMessage(`Failed: ${(e as Error).message}`);
    }
  }

  return (
    <section className="space-y-4">
      <div>
        <h2 className="text-2xl font-semibold tracking-tight">Weekly Treat</h2>
        <p className="text-sm text-muted-foreground">
          Earn $5 of reward budget for each task you complete this week. Generate a treat to randomly pick one eligible wishlist item.
        </p>
      </div>

      {error && (
        <div className="rounded-md border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive">
          {error}
        </div>
      )}

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Sparkles className="h-5 w-5" /> This week
            </CardTitle>
            <CardDescription>
              {eligibility ? `${eligibility.weekStart} → ${eligibility.weekEnd}` : "Loading week range…"}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
              <Stat label="Tasks completed" value={loading || !eligibility ? "—" : String(eligibility.tasksCompleted)} />
              <Stat label="Per-task value" value={loading || !eligibility ? "—" : formatPrice(eligibility.rewardValuePerTask)} />
              <Stat label="Weekly budget" value={loading || !eligibility ? "—" : formatPrice(eligibility.rewardBudget)} />
              <Stat label="Eligible items" value={loading || !eligibility ? "—" : String(eligibility.eligibleItemCount)} />
            </div>

            <Separator />

            <div className="flex flex-wrap items-center gap-2">
              <Button onClick={() => handleGenerate(false)} disabled={generating}>
                <Gift className="h-4 w-4" />
                {generating ? "Generating…" : "Generate Weekly Treat"}
              </Button>
              <Button variant="outline" onClick={refresh} disabled={loading}>
                <RotateCw className="h-4 w-4" />
                Refresh
              </Button>
              <Button variant="ghost" onClick={() => setHistoryOpen(true)}>
                <History className="h-4 w-4" />
                History
              </Button>
              {current && (
                <Button variant="ghost" onClick={() => handleGenerate(true)} disabled={generating}>
                  Re-roll (force)
                </Button>
              )}
            </div>

            {generateMessage && (
              <p className="text-sm text-muted-foreground">{generateMessage}</p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Gift className="h-5 w-5" /> This week's treat
            </CardTitle>
          </CardHeader>
          <CardContent>
            {!current && (
              <p className="text-sm text-muted-foreground">
                No treat selected yet. Click <span className="font-medium">Generate Weekly Treat</span> to pick one.
              </p>
            )}
            {current && (
              <div className="space-y-3">
                <div>
                  <div className="text-2xl font-semibold leading-tight">{current.wishlistItemName}</div>
                  <div className="font-mono text-lg">{formatPrice(current.wishlistItemPrice)}</div>
                </div>
                <div className="flex flex-wrap gap-2">
                  <Badge variant="secondary">Tasks: {current.tasksCompleted}</Badge>
                  <Badge variant="secondary">Budget: {formatPrice(current.rewardBudget)}</Badge>
                  <Badge variant="outline">Weight: {current.selectionWeight}</Badge>
                </div>
                <p className="text-xs text-muted-foreground">
                  Selected {new Date(current.selectedAt).toLocaleString()}.
                </p>
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      <RewardHistoryDialog open={historyOpen} onOpenChange={setHistoryOpen} load={fetchHistory} />
    </section>
  );
});
WeeklyTreatPanel.displayName = "WeeklyTreatPanel";

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-md border bg-card p-3">
      <div className="text-xs uppercase tracking-wide text-muted-foreground">{label}</div>
      <div className="mt-1 text-xl font-semibold">{value}</div>
    </div>
  );
}
