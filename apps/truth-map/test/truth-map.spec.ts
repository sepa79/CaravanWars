import { expect, test } from "@playwright/test";

async function openPanel(page: import("@playwright/test").Page, name: string) { await page.locator(`.game-tabs [data-panel-target="${name}"]`).click(); }

test.beforeEach(async ({ request }) => {
  const response = await request.post("/api/reset?view_mode=party&party_id=player_party", { data: {} });
  expect(response.ok()).toBe(true);
});

test("defaults to the expedition Party Map", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("#mapScopeLabel")).toHaveText("Wiedza wybranej grupy");
  await expect(page.locator("#partyId")).toHaveText("player_expedition");
  await expect(page.locator("#partyLocation")).toHaveText("Wroclaw");
  await expect(page.locator("#mapCanvas")).toBeVisible();
  await expect(page.locator("#navigationKnowledge")).toContainText("PRIVATE NAVIGATION");
});

test("truth mode is explicit and exposes more than the selected party knows", async ({ page }) => {
  await page.goto("/");
  await openPanel(page, "diagnostics");
  await page.locator("#debugMapObserver").selectOption("truth");

  await expect(page.locator("#mapScopeLabel")).toHaveText("Pełna prawda regionu");
  await expect(page.locator("#regionStats")).not.toContainText("2 miejsc · 1 dróg");
  await expect(page.locator("#navigationKnowledge")).toContainText("TRUTH / DEBUG");
  const truth = await page.request.get("/api/state?view_mode=truth&party_id=player_party");
  expect(await truth.text()).toContain("black_pine_bandit_base");
  expect(await truth.text()).toContain("selectedOwnerGraph");
});

test("AI is autonomous and has no manual gameplay tab", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator('[data-panel-target="ai"]')).toHaveCount(0);
  await expect(page.locator("#merchantStep")).toHaveCount(0);
});

test("surfaces malformed host controls as explicit request failures", async ({ request }) => {
  const response = await request.post("/api/time/advance?view_mode=party&party_id=player_party", { data: { days: 0 } });

  expect(response.status()).toBe(400);
  await expect(response.json()).resolves.toEqual({
    error: "REQUEST_VALIDATION_ERROR",
    message: "days must be a finite positive number",
  });
});

test("unknown Party Map observer fails without falling back to truth", async ({ request }) => {
  const response = await request.get("/api/state?view_mode=party&party_id=missing");

  expect(response.status()).toBe(400);
  await expect(response.json()).resolves.toEqual({
    error: "REQUEST_VALIDATION_ERROR",
    message: "Party missing does not exist.",
  });
});

test("regional economy diagnostics require explicit truth mode and advance autonomously", async ({ page, request }) => {
  const hidden = await request.get("/api/economy?view_mode=party&party_id=player_party");
  expect(hidden.status()).toBe(400);
  const initial = await request.get("/api/economy?view_mode=truth");
  expect(initial.ok()).toBeTruthy();
  const initialBody = await initial.json();
  expect(initialBody.truthView).toBe(true);
  const advanced = await request.post("/api/economy/advance?view_mode=truth", { data: { days: 2 } });
  expect(advanced.ok()).toBeTruthy();
  expect((await advanced.json()).metrics.elapsedDays).toBeGreaterThan(initialBody.metrics.elapsedDays);
  await page.goto("/");
  await openPanel(page, "diagnostics");
  await expect(page.locator("#economyDiagnostics")).toBeVisible();
  await expect(page.locator("#economyDiagnostics")).toContainText("TRUTH / DEBUG");
  await expect(page.locator("#economySeason")).not.toHaveText("—");
  await expect(page.locator("#economyProfiles")).toContainText("_v1");
  await expect(page.locator("#economyPopulation")).toContainText("wroclaw");
  await expect(page.locator("#economyLabour")).toContainText("SECURITY TRUTH");
  await expect(page.locator("#spatialDiagnostics")).toContainText("off-road");
});

test("playable expedition completes contract through physical cargo, encounter decision and settlement", async ({ page }) => {
  await page.goto("/");
  await openPanel(page, "caravan");
  await expect(page.locator("#partyId")).toHaveText("player_expedition");
  await expect(page.locator("body")).not.toContainText("great_forest_bandit_base");
  await openPanel(page, "contract");
  await expect(page.locator("#expeditionContract")).toContainText("8 food");
  await page.locator("#acceptContract").click();
  await expect(page.locator("#expeditionStatus")).toContainText("accepted");
  await page.locator("#pickupContract").click();
  await expect(page.locator("#expeditionCargo")).toContainText("food 12");
  await page.locator("#departExpedition").click();
  await page.locator("#advanceExpedition").click();
  await expect(page.locator("#encounterPanel")).toBeVisible();
  await page.locator('[data-decision="negotiate"]').click();
  await expect(page.locator("#expeditionLog")).toContainText("negotiated_passage");
  const advance = await page.request.post("/api/expedition/advance", { data: { days: 5 } });
  expect(advance.ok()).toBe(true);
  await page.reload();
  await openPanel(page, "contract");
  await expect(page.locator("#deliverContract")).toBeEnabled();
  await page.locator("#deliverContract").click();
  await expect(page.locator("#expeditionStatus")).toContainText("completed");
  await expect(page.locator("#expeditionLog")).toContainText("received 25 coin");
});

test("playable expedition failure path conserves loss and rejects incomplete delivery", async ({ page }) => {
  await page.goto("/");
  await openPanel(page, "contract");
  await page.locator("#acceptContract").click(); await page.locator("#pickupContract").click(); await page.locator("#departExpedition").click(); await page.locator("#advanceExpedition").click();
  await page.locator('[data-decision="surrender_cargo"]').click();
  await expect(page.locator("#expeditionCargo")).toContainText("food 6");
  await page.request.post("/api/expedition/advance", { data: { days: 5 } }); await page.reload(); await openPanel(page, "contract"); await page.locator("#deliverContract").click();
  await expect(page.locator("#expeditionStatus")).toContainText("INSUFFICIENT_GOODS");
});

test("fight presents its result and an explicit way to continue the journey", async ({ page }) => {
  await page.goto("/");
  await openPanel(page, "contract");
  await page.locator("#acceptContract").click();
  await page.locator("#pickupContract").click();
  await page.locator("#departExpedition").click();
  await page.locator("#advanceExpedition").click();
  await expect(page.locator("#encounterPanel")).toBeVisible();
  await page.locator('[data-decision="fight"]').click();
  await expect(page.locator("#encounterTitle")).toHaveText("Walka rozstrzygnięta");
  await expect(page.locator("#encounterSummary")).toContainText("fight:");
  await expect(page.locator('[data-encounter-continue="true"]')).toBeVisible();
  await page.locator('[data-encounter-continue="true"]').click();
  await expect(page.locator("#encounterPanel")).not.toBeVisible();
  await expect(page.locator("#expeditionLog")).toContainText("fight:");
});

test("playable API is current and contract loads without a 404 UI error", async ({ page, request }) => {
  const health = await request.get("/api/health");
  expect(health.ok()).toBe(true);
  await expect(health.json()).resolves.toMatchObject({ apiVersion: "viewport-game-ui-v1", expeditionEndpoint: "/api/expedition/state" });
  expect((await request.get("/api/expedition/state")).ok()).toBe(true);
  await page.goto("/");
  await expect(page.locator("#apiStatus")).toHaveText("Połączono");
  const contractTab = page.locator('[data-panel-target="contract"]').first(); await contractTab.focus(); await page.keyboard.press("Enter");
  await expect(page.locator("#expeditionContract")).toContainText("8 food");
  await expect(page.locator("#expeditionStatus")).not.toContainText("404");
});

test("leaving Debug restores the private expedition map", async ({ page }) => { await page.goto("/"); await openPanel(page, "diagnostics"); await page.locator("#debugMapObserver").selectOption("truth"); await expect(page.locator("#mapPanelMode")).toContainText("Developerski"); await openPanel(page, "map"); await expect(page.locator("#mapPanelMode")).toHaveText("Wiedza grupy"); await expect(page.locator("#partyId")).toHaveText("player_expedition"); });

test("polling keeps the expedition map, sidebar and permanent time controls stable", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/");
  await expect(page.locator("#apiStatus")).toHaveText("Połączono");
  await openPanel(page, "map");
  await expect(page.locator("#contextPanel")).toBeVisible();
  await expect(page.locator('#contextPanel [data-game-view="map"]')).toBeVisible();
  await expect(page.locator('[data-game-view="caravan"]')).not.toBeVisible();
  for (const id of ["advanceSixHours", "advanceDay", "autoAdvance"]) await expect(page.locator(`#${id}`)).toBeVisible();
  const canvasAttributeChanges = await page.evaluate(() => new Promise<number>((resolve) => {
    const canvas = document.querySelector("#mapCanvas");
    if (canvas === null) return resolve(-1);
    let changes = 0;
    const observer = new MutationObserver(() => { changes += 1; });
    observer.observe(canvas, { attributes: true, attributeFilter: ["width", "height"] });
    window.setTimeout(() => { observer.disconnect(); resolve(changes); }, 2200);
  }));
  expect(canvasAttributeChanges).toBe(0);
  await openPanel(page, "journal");
  for (const id of ["advanceSixHours", "advanceDay", "autoAdvance"]) await expect(page.locator(`#${id}`)).toBeVisible();
});

test("map and roster are distinct and Debug can inspect every party map", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/");
  await openPanel(page, "map");
  await expect(page.locator('#contextPanel [data-game-view="map"]')).toBeVisible();
  await expect(page.locator('[data-game-view="caravan"]')).not.toBeVisible();
  await openPanel(page, "caravan");
  await expect(page.locator('#contextPanel [data-game-view="map"]')).not.toBeVisible();
  await expect(page.locator('[data-game-view="caravan"]')).toBeVisible();
  await expect(page.locator("#showExpeditionMap")).toHaveCount(0);
  await openPanel(page, "diagnostics");
  await expect(page.locator("#debugMapObserver option")).toHaveCount(4);
  await page.locator("#debugMapObserver").selectOption("black_pine_raiders");
  await expect(page.locator("#partyId")).toHaveText("black_pine_raiders");
  await page.locator("#debugMapObserver").selectOption("truth");
  await expect(page.locator("#mapPanelMode")).toContainText("Developerski");
});

test("captures desktop and small viewport game-shell inspection screenshots", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 }); await page.goto("/"); await openPanel(page, "contract"); await page.screenshot({ path: "/tmp/caravanwars-viewport-desktop.png" });
  await page.setViewportSize({ width: 390, height: 844 }); await openPanel(page, "map"); await page.screenshot({ path: "/tmp/caravanwars-viewport-mobile.png" });
});

const viewports = [{ width: 1920, height: 1080 }, { width: 1440, height: 900 }, { width: 1366, height: 768 }, { width: 1280, height: 720 }, { width: 390, height: 844 }];
for (const viewport of viewports) test(`game shell remains viewport-locked at ${viewport.width}x${viewport.height}`, async ({ page }) => {
  await page.setViewportSize(viewport);
  await page.goto("/");
  await expect(page.locator("#apiStatus")).toHaveText("Połączono");
  await assertViewportLocked(page);
  for (const panel of ["map", "caravan", "contract", "journal", "commands", "diagnostics"]) { await openPanel(page, panel); await assertViewportLocked(page); }
  await openPanel(page, "contract");
  await page.locator("#acceptContract").click(); await page.locator("#pickupContract").click(); await page.locator("#departExpedition").click(); await page.locator("#advanceExpedition").click();
  await expect(page.locator("#encounterPanel")).toBeVisible();
  await assertViewportLocked(page);
  await expect(page.locator("#encounterPanel")).toBeInViewport();
  await expect(page.locator("#encounterChoices button").first()).toBeFocused();
  await page.locator('[data-decision="negotiate"]').click();
  await expect(page.locator('[data-encounter-continue="true"]')).toBeVisible();
  await page.locator('[data-encounter-continue="true"]').click();
  await expect(page.locator("#encounterPanel")).not.toBeVisible();
  const resized = { width: Math.max(390, viewport.width - 173), height: Math.max(640, viewport.height - 91) };
  await page.setViewportSize(resized); await assertViewportLocked(page);
});

async function assertViewportLocked(page: import("@playwright/test").Page) {
  const geometry = await page.evaluate(() => ({ innerWidth, innerHeight, htmlWidth: document.documentElement.scrollWidth, htmlHeight: document.documentElement.scrollHeight, bodyWidth: document.body.scrollWidth, bodyHeight: document.body.scrollHeight, map: (() => { const rect = document.querySelector("#mapCanvas")!.getBoundingClientRect(); return { width: rect.width, height: rect.height }; })(), panels: [...document.querySelectorAll<HTMLElement>("[data-game-view]")].filter((element) => element.offsetParent !== null).map((element) => ({ name: element.dataset.gameView, clientHeight: element.clientHeight, scrollHeight: element.scrollHeight, overflowY: getComputedStyle(element).overflowY })), visible: [...document.querySelectorAll<HTMLElement>("button:not([hidden]), select:not([hidden]), dialog[open]")].filter((element) => element.offsetParent !== null || element instanceof HTMLDialogElement && element.open).map((element) => { const rect = element.getBoundingClientRect(); return { id: element.id || element.textContent?.trim().slice(0, 20), left: rect.left, top: rect.top, right: rect.right, bottom: rect.bottom }; }) }));
  expect(geometry.htmlHeight).toBeLessThanOrEqual(geometry.innerHeight); expect(geometry.bodyHeight).toBeLessThanOrEqual(geometry.innerHeight); expect(geometry.htmlWidth).toBeLessThanOrEqual(geometry.innerWidth); expect(geometry.bodyWidth).toBeLessThanOrEqual(geometry.innerWidth);
  if (geometry.map.width > 0) { expect(geometry.map.width).toBeGreaterThan(100); expect(geometry.map.height).toBeGreaterThan(100); expect(geometry.map.height).toBeLessThanOrEqual(geometry.innerHeight); }
  for (const panel of geometry.panels) { expect(panel.overflowY, panel.name).not.toMatch(/auto|scroll/); expect(panel.scrollHeight, panel.name).toBeLessThanOrEqual(panel.clientHeight + 1); }
  for (const item of geometry.visible) { expect(item.left, String(item.id)).toBeGreaterThanOrEqual(-0.5); expect(item.top, String(item.id)).toBeGreaterThanOrEqual(-0.5); expect(item.right, String(item.id)).toBeLessThanOrEqual(geometry.innerWidth + 0.5); expect(item.bottom, String(item.id)).toBeLessThanOrEqual(geometry.innerHeight + 0.5); }
}
