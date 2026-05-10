import "dotenv/config";
import express, { type ErrorRequestHandler } from "express";
import cors from "cors";
import { pinoHttp } from "pino-http";
import { ZodError } from "zod";
import { tasksRouter } from "./routes/tasks.js";
import { internalRouter } from "./routes/internal.js";

const app = express();
const PORT = Number(process.env.PORT ?? 4001);

app.use(cors());
app.use(express.json());
app.use(pinoHttp());

app.get("/health", (_req, res) => {
  res.json({ status: "ok", service: "task-service" });
});

app.use("/api/tasks", tasksRouter);
app.use("/internal", internalRouter);

const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  if (err instanceof ZodError) {
    return res.status(400).json({ error: "validation_error", issues: err.issues });
  }
  console.error(err);
  res.status(500).json({ error: "internal_error", message: (err as Error).message });
};
app.use(errorHandler);

app.get("/version", (_req, res) => {
  res.json({ service: "task-service", version: process.env.APP_VERSION ?? "dev" });
});

const server = app.listen(PORT, () => {
  console.log(`task-service listening on :${PORT}`);
});

// Graceful shutdown: stop accepting new connections, let in-flight requests
// drain, then exit. Paired with the pod preStop sleep + terminationGracePeriod,
// this is what keeps a canary rollout zero-downtime.
function shutdown(signal: string) {
  console.log(`task-service received ${signal}, draining...`);
  server.close((err) => {
    if (err) {
      console.error("server.close error", err);
      process.exit(1);
    }
    process.exit(0);
  });
  // Hard cap so we never exceed the pod terminationGracePeriodSeconds.
  setTimeout(() => process.exit(0), 25_000).unref();
}
process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
