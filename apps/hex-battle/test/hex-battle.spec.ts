import { expect, test } from "@playwright/test";

test("player selects perceived actors and issues grouped orders without controlling allies", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("#selfName")).toHaveText("Aulus");
  await expect(page.locator("#tick")).toHaveText("0");
  const canvas = page.locator("#map"), box = await canvas.boundingBox();
  if (box === null) throw new Error("Map missing");
  await canvas.click({ position: { x: box.width * .30, y: box.height * .50 } });
  await expect(page.locator("#selectedName")).not.toHaveText("Wybierz heks lub postać");
  await page.locator("#advance").click();
  await expect(page.locator("#tick")).toHaveText("1");
  await expect(page.locator("body")).not.toHaveCSS("overflow-y", "auto");
});

test("battle UI remains viewport locked", async ({ page }) => {
  await page.goto("/");
  const dimensions = await page.evaluate(() => ({ width: document.documentElement.scrollWidth, height: document.documentElement.scrollHeight, viewportWidth: innerWidth, viewportHeight: innerHeight }));
  expect(dimensions.width).toBeLessThanOrEqual(dimensions.viewportWidth);
  expect(dimensions.height).toBeLessThanOrEqual(dimensions.viewportHeight);
});
