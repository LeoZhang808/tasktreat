import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "node:path";

// Vite proxies route prefixes to each microservice during local dev so the
// frontend code only has to know about /api/...
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  server: {
    port: 5173,
    proxy: {
      "/api/tasks": { target: "http://localhost:4001", changeOrigin: true },
      "/api/wishlist": { target: "http://localhost:4002", changeOrigin: true },
      "/api/rewards": { target: "http://localhost:4003", changeOrigin: true },
    },
  },
});
