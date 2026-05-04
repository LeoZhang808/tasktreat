import { useCallback, useEffect, useState } from "react";
import { api, type EligibilitySummary, type GenerateResult, type Reward } from "@/lib/api";

interface CurrentResponse {
  weekStart: string;
  reward: Reward | null;
}

interface HistoryResponse {
  count: number;
  rewards: Reward[];
}

export function useRewards() {
  const [eligibility, setEligibility] = useState<EligibilitySummary | null>(null);
  const [current, setCurrent] = useState<Reward | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [generating, setGenerating] = useState(false);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [eligRes, curRes] = await Promise.all([
        api.get<EligibilitySummary>("/rewards/eligibility"),
        api.get<CurrentResponse>("/rewards/current"),
      ]);
      setEligibility(eligRes);
      setCurrent(curRes.reward);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const generate = useCallback(async (force = false): Promise<GenerateResult> => {
    setGenerating(true);
    try {
      const result = await api.post<GenerateResult>("/rewards/generate-weekly", { force });
      await refresh();
      return result;
    } finally {
      setGenerating(false);
    }
  }, [refresh]);

  const fetchHistory = useCallback(async (): Promise<Reward[]> => {
    const res = await api.get<HistoryResponse>("/rewards/history");
    return res.rewards;
  }, []);

  return { eligibility, current, loading, error, generating, refresh, generate, fetchHistory };
}
