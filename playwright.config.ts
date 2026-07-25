import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "apps/truth-map/test",
  outputDir: "/tmp/caravanwars-playwright-results",
  fullyParallel: false,
  workers: 1,
  use: {
    baseURL: "http://127.0.0.1:4174",
    viewport: { width: 1440, height: 900 },
  },
  webServer: {
    command: "npm run dev:truth-map",
    env: {
      ...process.env,
      PORT: "4174",
    },
    url: "http://127.0.0.1:4174/api/state?view_mode=party&party_id=player_party",
    reuseExistingServer: false,
    timeout: 30_000,
  },
});
