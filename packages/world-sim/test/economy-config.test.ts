import assert from "node:assert/strict";
import { resolve } from "node:path";
import test from "node:test";

import {
  loadGoodsCatalogFile,
  loadLocationEconomyConfigFile,
  loadPartyCargoConfigFile,
} from "../src/index.js";

test("loads the canonical goods, cargo, and location economy contracts", () => {
  const goods = loadGoodsCatalogFile(resolve("data/simulation/goods_catalog.json"));
  const cargo = loadPartyCargoConfigFile(resolve("data/simulation/party_cargo.json"));
  const locations = loadLocationEconomyConfigFile(
    resolve("data/simulation/location_economy.json"),
    goods,
  );

  assert.equal(goods.goodsById.get("food")?.bulkPerUnit, 1);
  assert.equal(goods.goodsById.get("coin")?.baseValue, 1);
  assert.equal(cargo.wagonCapacityBulk, 25);
  assert.deepEqual(
    locations.profiles.map((profile) => profile.locationId),
    ["wroclaw_city", "opole_stronghold", "nysa_monastery"],
  );
});
