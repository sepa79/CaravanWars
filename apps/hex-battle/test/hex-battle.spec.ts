import { expect, test } from "@playwright/test";

test("player selects perceived actors and issues grouped orders without controlling allies", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("#selfName")).toHaveText("Aulus");
  await expect(page.locator("#tick")).toHaveText("0");
  const canvas = page.locator("#map"), box = await canvas.boundingBox();
  if (box === null) throw new Error("Map missing");
  await canvas.click({ position: { x: box.width * .30, y: box.height * .50 } });
  await expect(page.locator("#selectedName")).toHaveText("Wulf");
  await page.getByText("Ruch", { exact: true }).click();
  await page.getByRole("button", { name: "Naprzód" }).click();
  await expect(page.locator("#selectedName")).toContainText("wskaż cel");
  await canvas.click({ position: { x: box.width * .50, y: box.height * .50 } });
  await page.locator("#advance").click();
  await expect(page.locator("#tick")).toHaveText("1");
  const state = await page.request.get("/api/state").then((response) => response.json());
  expect(state.visible.find((actor: { actorId: string }) => actor.actorId === "ally_spear").position).not.toEqual({ q: -2, r: 0 });
  await expect(page.locator("body")).not.toHaveCSS("overflow-y", "auto");
});

test("battle UI remains viewport locked", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("body")).toHaveCSS("background-color", "rgb(21, 19, 15)");
  await expect(page.locator(".shell")).toHaveCSS("display", "grid");
  const dimensions = await page.evaluate(() => ({ width: document.documentElement.scrollWidth, height: document.documentElement.scrollHeight, viewportWidth: innerWidth, viewportHeight: innerHeight }));
  expect(dimensions.width).toBeLessThanOrEqual(dimensions.viewportWidth);
  expect(dimensions.height).toBeLessThanOrEqual(dimensions.viewportHeight);
});
