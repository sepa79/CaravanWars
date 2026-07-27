import { expect, test } from "@playwright/test";

test.beforeEach(async ({ request }) => {
  const response = await request.post("/api/reset?view_mode=party&party_id=player_party", { data: {} });
  expect(response.ok()).toBe(true);
});

test("defaults to a filtered Party Map and moves through the command boundary", async ({ page }) => {
  await page.goto("/");

  await expect(page.locator("#mapMode")).toHaveValue("party");
  await expect(page.locator("#mapScopeLabel")).toHaveText("Wiedza wybranej grupy");
  await expect(page.locator("#regionStats")).toContainText("2 miejsc · 1 dróg · 0 landmarki");
  const initialPartyState = await page.request.get("/api/state?view_mode=party&party_id=player_party");
  expect(await initialPartyState.text()).not.toContain("raciborz");
  await expect(page.locator("#partyId")).toHaveText("player_party");
  await expect(page.locator("#partyLocation")).toHaveText("Wroclaw");
  await expect(page.locator("#mapCanvas")).toBeVisible();
  await expect(page.locator("#navigationKnowledge")).toContainText("PRIVATE NAVIGATION");
  expect(await initialPartyState.text()).not.toContain("black_pine_bandit_base");

  await page.locator("#destination").selectOption("opole");
  await page.locator("#moveButton").click();
  await expect(page.locator("#partyStatus")).toHaveText("w podróży");
  await expect(page.locator("#commandResult")).toContainText("Komenda przyjęta");
  await expect(page.locator("#regionStats")).toContainText("2 landmarki");

  const advance = await page.request.post("/api/time/advance?view_mode=party&party_id=player_party", { data: { days: 4 } });
  expect(advance.ok()).toBe(true);
  await page.reload();
  await expect(page.locator("#partyStatus")).toHaveText("oczekuje");
  await expect(page.locator("#partyLocation")).toHaveText("Opole");
});

test("truth mode is explicit and exposes more than the selected party knows", async ({ page }) => {
  await page.goto("/");
  await page.locator("#mapMode").selectOption("truth");

  await expect(page.locator("#mapScopeLabel")).toHaveText("Pełna prawda regionu");
  await expect(page.locator("#regionStats")).not.toContainText("2 miejsc · 1 dróg");
  await expect(page.locator("#navigationKnowledge")).toContainText("TRUTH / DEBUG");
  const truth = await page.request.get("/api/state?view_mode=truth&party_id=player_party");
  expect(await truth.text()).toContain("black_pine_bandit_base");
  expect(await truth.text()).toContain("selectedOwnerGraph");
});

test("merchant AI carries physical food from remembered source to remembered need", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("#cargoFood")).toHaveText("0");
  await expect(page.locator("#localFood")).toHaveText("40");

  await page.locator("#merchantStep").click();
  await expect(page.locator("#merchantResult")).toContainText("withdraw: command_accepted");
  await expect(page.locator("#cargoFood")).toHaveText("10");
  await expect(page.locator("#localFood")).toHaveText("30");

  await page.locator("#merchantStep").click();
  await expect(page.locator("#merchantResult")).toContainText("travel: command_accepted");
  await expect(page.locator("#partyStatus")).toHaveText("w podróży");

  const advance = await page.request.post(
    "/api/time/advance?view_mode=party&party_id=player_party",
    { data: { days: 4 } },
  );
  expect(advance.ok()).toBe(true);
  await page.reload();
  await expect(page.locator("#partyLocation")).toHaveText("Opole");
  await expect(page.locator("#cargoFood")).toHaveText("10");
  await expect(page.locator("#localFood")).toHaveText("0");

  await page.locator("#merchantStep").click();
  await expect(page.locator("#merchantResult")).toContainText("deposit: command_accepted");
  await expect(page.locator("#cargoFood")).toHaveText("0");
  await expect(page.locator("#localFood")).toHaveText("10");
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
  await page.goto("/?view_mode=truth");
  await page.locator("#mapMode").selectOption("truth");
  await expect(page.locator("#economyDiagnostics")).toBeVisible();
  await expect(page.locator("#economyDiagnostics")).toContainText("TRUTH / DEBUG");
  await expect(page.locator("#economySeason")).not.toHaveText("—");
  await expect(page.locator("#economyProfiles")).toContainText("_v1");
  await expect(page.locator("#economyPopulation")).toContainText("wroclaw");
  await expect(page.locator("#economyLabour")).toContainText("SECURITY TRUTH");
  await expect(page.locator("#spatialDiagnostics")).toContainText("off-road");
});
