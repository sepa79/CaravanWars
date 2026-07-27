import { expect, test, type Page } from "@playwright/test";

test.beforeEach(async ({ request }) => { await request.post("/api/reset"); });

test("FORMATION Advance previews and executes the exact stable Retainers translation", async ({ page }) => {
  await page.goto("/");
  await page.locator('[data-group-id="retainers"]').click();
  await expect(page.locator("#selectionMode")).toHaveText("FORMATION");
  await expect(page.locator("#actionMode")).toHaveText("FORMATION ORDERS");
  await expect(page.locator("#selectedName")).toHaveText("Retainers");
  await expect(page.getByRole("button", { name: "Move", exact: true })).toHaveCount(0);

  await page.getByText("Movement", { exact: true }).click();
  await page.locator('[data-order="advance"]').click();
  const canvas = page.locator("#map"), target = await canvasPoint(page, { q: -1, r: 0 });
  await canvas.hover({ position: target });
  await expect(page.locator("#selectedInfo")).toContainText("GREEN placement at -1,0");
  for (const mapping of ["retainer_1→-1,-1", "retainer_2→-1,0", "retainer_3→-1,1", "retainer_4→-1,2"]) await expect(page.locator("#selectedInfo")).toContainText(mapping);
  await canvas.click({ position: target });
  await expect(page.locator("#targetSummary")).toContainText("GREEN whole placement");
  const beforeConfirm = await state(page);
  expect(group(beforeConfirm).currentOrder).toBeNull();
  await page.locator("#confirmTarget").click();
  const issued = await state(page);
  expect(group(issued).currentOrder).toBe("advance");
  expect(group(issued).orderStatus).toBe("issued");
  await page.locator("#advance").click();
  const executed = await state(page);
  expect(group(executed).banner).toEqual({ q: -1, r: 0 });
  expect(group(executed).orderStatus).toBe("completed");
  expect(positions(executed, ["retainer_1", "retainer_2", "retainer_3", "retainer_4"])).toEqual({ retainer_1: "-1,-1", retainer_2: "-1,0", retainer_3: "-1,1", retainer_4: "-1,2" });
  expect(group(executed).assignments.map((slot: { memberId: string }) => slot.memberId)).toEqual(["retainer_1", "retainer_2", "retainer_3", "retainer_4"]);
});

test("INDIVIDUAL Aulus exposes only legal personal targets and does not mutate formation state", async ({ page }) => {
  await page.goto("/");
  const canvas = page.locator("#map"), aulus = await canvasPoint(page, { q: -3, r: 1 });
  await canvas.click({ position: aulus });
  await expect(page.locator("#selectionMode")).toHaveText("INDIVIDUAL");
  await expect(page.locator("#actionMode")).toHaveText("INDIVIDUAL ACTIONS");
  await expect(page.locator("#selectedName")).toHaveText("Aulus");
  await expect(page.getByText("Movement", { exact: true })).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Move", exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "Attack", exact: true })).toBeVisible();
  const formationBefore = group(await state(page));
  await page.getByRole("button", { name: "Move", exact: true }).click();
  const target = await canvasPoint(page, { q: -3, r: 0 });
  await canvas.click({ position: target });
  await expect(page.locator("#targetSummary")).toContainText("Move Aulus → -3, 0");
  expect((await state(page)).self.position).toEqual({ q: -3, r: 1 });
  await page.locator("#confirmTarget").click();
  expect((await state(page)).self.position).toEqual({ q: -3, r: 1 });
  await page.locator("#advance").click();
  const after = await state(page);
  expect(after.self.position).toEqual({ q: -3, r: 0 });
  expect(group(after)).toEqual(formationBefore);
});

for (const viewport of [{ name: "desktop", width: 1280, height: 800 }, { name: "mobile", width: 390, height: 844 }]) test(`${viewport.name} viewport remains locked`, async ({ page }, testInfo) => {
  await page.setViewportSize(viewport); await page.goto("/");
  await expect(page.locator("body")).toHaveCSS("background-color", "rgb(21, 19, 15)");
  const dimensions = await page.evaluate(() => ({ width: document.documentElement.scrollWidth, height: document.documentElement.scrollHeight, viewportWidth: innerWidth, viewportHeight: innerHeight }));
  expect(dimensions.width).toBeLessThanOrEqual(dimensions.viewportWidth); expect(dimensions.height).toBeLessThanOrEqual(dimensions.viewportHeight);
  await page.screenshot({ path: testInfo.outputPath(`hex-battle-${viewport.name}.png`), fullPage: true });
});

async function canvasPoint(page: Page, hex: { q: number; r: number }): Promise<{ x: number; y: number }> { const box = await page.locator("#map").boundingBox(); if (box === null) throw new Error("Battle map missing"); const size = Math.min(box.width / (6 * 3.25), box.height / (6 * 2.25)); return { x: box.width / 2 + size * Math.sqrt(3) * (hex.q + hex.r / 2), y: box.height / 2 + size * 1.5 * hex.r }; }
async function state(page: Page): Promise<any> { return page.request.get("/api/state").then((response) => response.json()); }
function group(value: any): any { return value.alliedGroups.find((item: { groupId: string }) => item.groupId === "retainers"); }
function positions(value: any, ids: string[]): Record<string, string> { return Object.fromEntries(ids.map((id) => { const actor = value.visible.find((item: { actorId: string }) => item.actorId === id); return [id, `${actor.position.q},${actor.position.r}`]; })); }
