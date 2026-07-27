import { defineConfig } from "@playwright/test";
export default defineConfig({ testDir: "apps/hex-battle/test", workers: 1, use: { baseURL: "http://127.0.0.1:4175", viewport: { width: 1280, height: 800 } }, webServer: { command: "npm run start:hex-battle", url: "http://127.0.0.1:4175/api/state", reuseExistingServer: false, timeout: 20_000 } });
