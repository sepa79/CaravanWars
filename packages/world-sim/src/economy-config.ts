import { readFileSync } from "node:fs";

export interface GoodsDefinition {
  readonly id: string;
  readonly displayName: string;
  readonly category: string;
  readonly bulkPerUnit: number;
  readonly baseValue: number;
  readonly perishable: boolean;
  readonly tags: readonly string[];
}

export interface GoodsCatalog {
  readonly goods: readonly GoodsDefinition[];
  readonly goodsById: ReadonlyMap<string, GoodsDefinition>;
}

export interface PartyCargoConfig {
  readonly footCapacityBulk: number;
  readonly horseCapacityBulk: number;
  readonly packAnimalCapacityBulk: number;
  readonly wagonCapacityBulk: number;
}

export interface LocationEconomyProfile {
  readonly locationId: string;
  readonly productionPerDay: Readonly<Record<string, number>>;
  readonly consumptionPerDay: Readonly<Record<string, number>>;
  readonly storageCaps: Readonly<Record<string, number>>;
}

export interface LocationEconomyConfig {
  readonly profiles: readonly LocationEconomyProfile[];
  readonly profilesByLocationId: ReadonlyMap<string, LocationEconomyProfile>;
}

type JsonRecord = Record<string, unknown>;

export class EconomyConfigValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "EconomyConfigValidationError";
  }
}

export function loadGoodsCatalogFile(filePath: string): GoodsCatalog {
  const root = readJsonRecord(filePath, "Goods catalog");
  requireSchemaVersionZero(root, "Goods catalog");
  const goods = requireArray(root.goods, "goods").map((value, index) => {
    const source = requireRecord(value, `goods[${index}]`);
    return {
      id: requireNonEmptyString(source.goods_id, `goods[${index}].goods_id`),
      displayName: requireNonEmptyString(source.display_name, `goods[${index}].display_name`),
      category: requireNonEmptyString(source.category, `goods[${index}].category`),
      bulkPerUnit: requirePositiveNumber(source.bulk_per_unit, `goods[${index}].bulk_per_unit`),
      baseValue: requireNonNegativeNumber(source.base_value, `goods[${index}].base_value`),
      perishable: requireBoolean(source.perishable, `goods[${index}].perishable`),
      tags: requireArray(source.tags, `goods[${index}].tags`).map((tag, tagIndex) =>
        requireNonEmptyString(tag, `goods[${index}].tags[${tagIndex}]`)),
    };
  });
  const goodsById = indexUnique(goods, "Goods");
  return { goods, goodsById };
}

export function loadPartyCargoConfigFile(filePath: string): PartyCargoConfig {
  const root = readJsonRecord(filePath, "Party cargo config");
  requireSchemaVersionZero(root, "Party cargo config");
  return {
    footCapacityBulk: requireNonNegativeNumber(root.foot_capacity_bulk, "foot_capacity_bulk"),
    horseCapacityBulk: requireNonNegativeNumber(root.horse_capacity_bulk, "horse_capacity_bulk"),
    packAnimalCapacityBulk: requireNonNegativeNumber(
      root.pack_animal_capacity_bulk,
      "pack_animal_capacity_bulk",
    ),
    wagonCapacityBulk: requireNonNegativeNumber(root.wagon_capacity_bulk, "wagon_capacity_bulk"),
  };
}

export function loadLocationEconomyConfigFile(
  filePath: string,
  goodsCatalog: GoodsCatalog,
): LocationEconomyConfig {
  const root = readJsonRecord(filePath, "Location economy config");
  requireSchemaVersionZero(root, "Location economy config");
  const profiles = requireArray(root.profiles, "profiles").map((value, index) => {
    const source = requireRecord(value, `profiles[${index}]`);
    const profile: LocationEconomyProfile = {
      locationId: requireNonEmptyString(source.location_id, `profiles[${index}].location_id`),
      productionPerDay: parseGoodsQuantities(
        source.production_per_day,
        `profiles[${index}].production_per_day`,
        goodsCatalog,
      ),
      consumptionPerDay: parseGoodsQuantities(
        source.consumption_per_day,
        `profiles[${index}].consumption_per_day`,
        goodsCatalog,
      ),
      storageCaps: parseGoodsQuantities(
        source.storage_caps,
        `profiles[${index}].storage_caps`,
        goodsCatalog,
      ),
    };
    for (const goodsId of [
      ...Object.keys(profile.productionPerDay),
      ...Object.keys(profile.consumptionPerDay),
    ]) {
      if (profile.storageCaps[goodsId] === undefined) {
        throw new EconomyConfigValidationError(
          `Profile ${profile.locationId} changes ${goodsId} without a storage cap.`,
        );
      }
    }
    return profile;
  });
  return { profiles, profilesByLocationId: indexUnique(profiles, "Location economy profile") };
}

function readJsonRecord(filePath: string, label: string): JsonRecord {
  let parsed: unknown;
  try {
    parsed = JSON.parse(readFileSync(filePath, "utf8")) as unknown;
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    throw new EconomyConfigValidationError(`${label} JSON is invalid: ${message}`);
  }
  return requireRecord(parsed, label);
}

function requireSchemaVersionZero(root: JsonRecord, label: string): void {
  if (root.schema_version !== 0) {
    throw new EconomyConfigValidationError(`${label} schema_version must be 0.`);
  }
}

function parseGoodsQuantities(
  value: unknown,
  path: string,
  goodsCatalog: GoodsCatalog,
): Readonly<Record<string, number>> {
  const source = requireRecord(value, path);
  const result: Record<string, number> = {};
  for (const [goodsId, amount] of Object.entries(source)) {
    if (!goodsCatalog.goodsById.has(goodsId)) {
      throw new EconomyConfigValidationError(`${path} references unknown goods ${goodsId}.`);
    }
    result[goodsId] = requireNonNegativeNumber(amount, `${path}.${goodsId}`);
  }
  return result;
}

function indexUnique<T extends { readonly id?: string; readonly locationId?: string }>(
  items: readonly T[],
  label: string,
): ReadonlyMap<string, T> {
  const result = new Map<string, T>();
  for (const item of items) {
    const id = item.id ?? item.locationId;
    if (id === undefined) throw new EconomyConfigValidationError(`${label} has no id.`);
    if (result.has(id)) throw new EconomyConfigValidationError(`${label} id is duplicated: ${id}.`);
    result.set(id, item);
  }
  return result;
}

function requireRecord(value: unknown, path: string): JsonRecord {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new EconomyConfigValidationError(`${path} must be an object.`);
  }
  return value as JsonRecord;
}

function requireArray(value: unknown, path: string): readonly unknown[] {
  if (!Array.isArray(value)) throw new EconomyConfigValidationError(`${path} must be an array.`);
  return value;
}

function requireNonEmptyString(value: unknown, path: string): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new EconomyConfigValidationError(`${path} must be a non-empty string.`);
  }
  return value;
}

function requirePositiveNumber(value: unknown, path: string): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) {
    throw new EconomyConfigValidationError(`${path} must be a finite positive number.`);
  }
  return value;
}

function requireNonNegativeNumber(value: unknown, path: string): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
    throw new EconomyConfigValidationError(`${path} must be a finite non-negative number.`);
  }
  return value;
}

function requireBoolean(value: unknown, path: string): boolean {
  if (typeof value !== "boolean") {
    throw new EconomyConfigValidationError(`${path} must be a boolean.`);
  }
  return value;
}
