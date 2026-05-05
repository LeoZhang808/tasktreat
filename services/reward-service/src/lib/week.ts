// Monday-anchored ISO week helpers. All dates are treated in UTC so that
// week boundaries are stable regardless of where services run.

export interface WeekRange {
  weekStart: string; // YYYY-MM-DD (Monday)
  weekEnd: string;   // YYYY-MM-DD (Sunday)
}

function pad(n: number): string {
  return n.toString().padStart(2, "0");
}

function toYmd(d: Date): string {
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}

export function getWeekRange(reference: Date = new Date()): WeekRange {
  const d = new Date(Date.UTC(
    reference.getUTCFullYear(),
    reference.getUTCMonth(),
    reference.getUTCDate(),
  ));
  // getUTCDay: Sunday=0, Monday=1, ... Saturday=6
  const day = d.getUTCDay();
  // Days to subtract to land on Monday. If today is Sunday (0), go back 6.
  const offsetToMonday = day === 0 ? 6 : day - 1;
  const monday = new Date(d);
  monday.setUTCDate(d.getUTCDate() - offsetToMonday);
  const sunday = new Date(monday);
  sunday.setUTCDate(monday.getUTCDate() + 6);

  return { weekStart: toYmd(monday), weekEnd: toYmd(sunday) };
}

export function ymdToDate(ymd: string): Date {
  return new Date(`${ymd}T00:00:00.000Z`);
}
