import { useRef } from "react";
import { Trophy } from "lucide-react";
import { Separator } from "@/components/ui/separator";
import { TaskBoard } from "@/components/board/TaskBoard";
import { WishlistSection } from "@/components/wishlist/WishlistSection";
import { WeeklyTreatPanel, type WeeklyTreatPanelHandle } from "@/components/reward/WeeklyTreatPanel";

export function Dashboard() {
  const rewardRef = useRef<WeeklyTreatPanelHandle>(null);

  function refreshReward() {
    void rewardRef.current?.refresh();
  }

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b bg-card">
        <div className="container flex items-center justify-between py-6">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary text-primary-foreground">
              <Trophy className="h-5 w-5" />
            </div>
            <div>
              <h1 className="text-xl font-semibold tracking-tight">TaskTreat</h1>
              <p className="text-xs text-muted-foreground">Earn a weekly reward by completing tasks.</p>
            </div>
          </div>
        </div>
      </header>

      <main className="container space-y-10 py-8">
        <WeeklyTreatPanel ref={rewardRef} />
        <Separator />
        <TaskBoard onCompletedCountChange={refreshReward} />
        <Separator />
        <WishlistSection onChange={refreshReward} />
      </main>

      <footer className="border-t bg-card">
        <div className="container py-4 text-xs text-muted-foreground">
          TaskTreat — frontend on :5173, services on :4001 / :4002 / :4003.
        </div>
      </footer>
    </div>
  );
}
