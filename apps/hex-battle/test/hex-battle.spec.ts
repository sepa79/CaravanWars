import { expect, test, type Page } from "@playwright/test";

test("group selection, targeted Rally and Advance preview and animate coherently", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("#selfName")).toHaveText("Aulus");
  await page.locator('[data-group-id="retainers"]').click();
  await expect(page.locator("#selectedName")).toHaveText("Retainers");
  await expect(page.locator("#selectedInfo")).toContainText("Commander");
  await issueTargeted(page, "Movement", "Rally", { x: .42, y: .49 });
  await expect(page.locator('[data-group-id="retainers"]')).toContainText("Rally: issued");
  for (let tick = 0; tick < 5; tick += 1) await page.locator("#advance").click();
  await expect(page.locator('[data-group-id="retainers"]')).toContainText(/Rally: (executing|completed)/);
  await page.getByText("Movement", { exact: true }).click();
  await page.locator('[data-order="advance"]').click();
  await expect(page.locator("#selectedName")).toContainText("choose hex");
  const canvas = page.locator("#map"), box = await canvas.boundingBox();
  if (box === null) throw new Error("Battle map missing");
  await canvas.click({ position: { x: box.width * .58, y: box.height * .50 } });
  await expect(page.locator("#confirm-order")).toBeVisible();
  const previewPixels = await canvas.evaluate((element: HTMLCanvasElement) => {
    const context = element.getContext("2d")!;
    return Array.from(context.getImageData(0, 0, element.width, element.height).data).filter((value) => value > 180).length;
  });
  expect(previewPixels).toBeGreaterThan(100);
  await page.locator("#confirm-order").click();
  const before = await page.request.get("/api/state").then((response) => response.json());
  for (let tick = 0; tick < 8; tick += 1) await page.locator("#advance").click();
  const after = await page.request.get("/api/state").then((response) => response.json());
  expect(after.tick).toBe(before.tick + 8);
  expect(after.visible.filter((actor: { groupId: string }) => actor.groupId === "retainers").some((actor: { position: unknown }, index: number) => JSON.stringify(actor.position) !== JSON.stringify(before.visible.filter((item: { groupId: string }) => item.groupId === "retainers")[index]?.position))).toBe(true);
  expect(new Set(after.visible.map((actor: { position: { q: number; r: number } }) => `${actor.position.q},${actor.position.r}`)).size).toBe(after.visible.length);
  await expect(page.locator("#events")).toContainText("order_status");
});

for (const viewport of [{ name: "desktop", width: 1280, height: 800 }, { name: "mobile", width: 390, height: 844 }]) {
  test(`${viewport.name} viewport is locked and the authored stylesheet is loaded`, async ({ page }) => {
    await page.setViewportSize(viewport);
    await page.goto("/");
    await expect(page.locator("body")).toHaveCSS("background-color", "rgb(21, 19, 15)");
    await expect(page.locator(".shell")).toHaveCSS("display", "grid");
    expect(await page.evaluate(() => [...document.styleSheets].some((sheet) => sheet.href?.endsWith("/src/styles.css") && sheet.cssRules.length > 10))).toBe(true);
    const dimensions = await page.evaluate(() => ({ width: document.documentElement.scrollWidth, height: document.documentElement.scrollHeight, viewportWidth: innerWidth, viewportHeight: innerHeight }));
    expect(dimensions.width).toBeLessThanOrEqual(dimensions.viewportWidth);
    expect(dimensions.height).toBeLessThanOrEqual(dimensions.viewportHeight);
    await page.screenshot({ path: `test-results/hex-battle-${viewport.name}.png`, fullPage: true });
  });
}

async function issueTargeted(page: Page, category: string, order: string, point: { x: number; y: number }): Promise<void> {
  await page.getByText(category, { exact: true }).click();
  await page.locator(`[data-order="${order.toLowerCase()}"]`).click();
  const canvas = page.locator("#map"), box = await canvas.boundingBox();
  if (box === null) throw new Error("Battle map missing");
  await canvas.click({ position: { x: box.width * point.x, y: box.height * point.y } });
  await expect(page.locator("#confirm-order")).toBeVisible();
  await page.locator("#confirm-order").click();
}
