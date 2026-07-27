import { createServer } from "node:http";
import type { IncomingMessage, ServerResponse } from "node:http";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  WorldSimulation,
  WorldSimulationQueryError,
  MerchantMemoryAI,
  loadGoodsCatalogFile,
  loadLocationEconomyConfigFile,
  loadPartyCargoConfigFile,
  loadPartyTravelConfigFile,
  loadRegionGraphFile,
  createSeasonalRegionalEconomyFixture,
} from "@caravan-wars/world-sim";
import type {
  MerchantMemoryEntry,
  MovePartyCommand,
  PartySeed,
  RegionGraph,
  WorldEconomySeed,
} from "@caravan-wars/world-sim";
import { createServer as createViteServer } from "vite";

const SERVER_PORT = parseServerPort(process.env.PORT);
const MAX_BODY_BYTES = 64 * 1024;
const sourceDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(sourceDirectory, "../../..");
const applicationRoot = resolve(repositoryRoot, "apps/truth-map");

const graph = loadRegionGraphFile(resolve(repositoryRoot, "data/regions/silesia.json"));
const travelConfig = loadPartyTravelConfigFile(
  resolve(repositoryRoot, "data/simulation/party_travel.json"),
);
const goodsCatalog = loadGoodsCatalogFile(
  resolve(repositoryRoot, "data/simulation/goods_catalog.json"),
);
const partySeed: PartySeed = {
  id: "player_party",
  displayName: "Karawana gracza",
  managerActorId: "player_caravan_leader",
  nodeId: "wroclaw",
  composition: {
    footCount: 8,
    horseCount: 2,
    wagonCount: 1,
    packAnimalCount: 1,
    guardCount: 2,
  },
  knownRouteIds: ["wroclaw_opole"],
  cargo: {},
};
const economySeed: WorldEconomySeed = {
  goodsCatalog,
  partyCargoConfig: loadPartyCargoConfigFile(
    resolve(repositoryRoot, "data/simulation/party_cargo.json"),
  ),
  locationEconomyConfig: loadLocationEconomyConfigFile(
    resolve(repositoryRoot, "data/simulation/location_economy.json"),
    goodsCatalog,
  ),
  locations: [
    {
      id: "wroclaw_city",
      displayName: "Wrocław",
      managerActorId: "mayor_wroclaw",
      nodeId: "wroclaw",
      resources: { food: 40, grain: 20, coin: 0, tools: 0, horses: 0 },
    },
    {
      id: "opole_stronghold",
      displayName: "Opole",
      managerActorId: "castellan_opole",
      nodeId: "opole",
      resources: { food: 0, coin: 0, horses: 0, iron: 0, tools: 0 },
    },
    {
      id: "nysa_monastery",
      displayName: "Nysa",
      managerActorId: "abbot_nysa",
      nodeId: "nysa",
      resources: { food: 0, coin: 0, horses: 0, wax: 0 },
    },
  ],
};
const merchantMemory: readonly MerchantMemoryEntry[] = [
  {
    kind: "location_observation",
    ownerId: "player_party",
    nodeId: "wroclaw",
    observedLocationId: "wroclaw_city",
    observedResources: { food: 40 },
  },
  {
    kind: "need_ledger",
    ownerId: "player_party",
    goodsId: "food",
    locationId: "opole_stronghold",
    nodeId: "opole",
    neededAmount: 10,
  },
];
const merchantAi = new MerchantMemoryAI();
const simulation = new WorldSimulation(graph, travelConfig, [partySeed], economySeed);
let regionalEconomy = createSeasonalRegionalEconomyFixture(graph, travelConfig);

const vite = await createViteServer({
  root: applicationRoot,
  appType: "spa",
  server: { middlewareMode: true, hmr: false },
});

const server = createServer((request, response) => {
  void handleRequest(request, response).catch((error: unknown) => {
    const message = error instanceof Error ? error.message : String(error);
    const isRequestError = error instanceof RequestValidationError
      || error instanceof WorldSimulationQueryError;
    const statusCode = isRequestError ? 400 : 500;
    const errorCode = isRequestError
      ? "REQUEST_VALIDATION_ERROR"
      : "INTERNAL_SERVER_ERROR";
    writeJson(response, statusCode, { error: errorCode, message });
  });
});

async function handleRequest(request: IncomingMessage, response: ServerResponse): Promise<void> {
  const method = request.method ?? "GET";
  const requestUrl = new URL(request.url ?? "/", `http://${request.headers.host ?? "localhost"}`);

  if (method === "GET" && requestUrl.pathname === "/api/state") {
    writeJson(response, 200, createClientState(requestUrl, graph, simulation));
    return;
  }
  if (method === "GET" && requestUrl.pathname === "/api/economy") {
    requireTruthDiagnostics(requestUrl);
    writeJson(response, 200, regionalEconomy.runner.diagnostics());
    return;
  }
  if (method === "POST" && requestUrl.pathname === "/api/economy/advance") {
    requireTruthDiagnostics(requestUrl);
    const days = parseRegionalDaysRequest(await readJsonBody(request));
    regionalEconomy.runner.runDays(days);
    writeJson(response, 200, regionalEconomy.runner.diagnostics());
    return;
  }
  if (method === "POST" && requestUrl.pathname === "/api/commands/move-party") {
    const command = parseMovePartyCommand(await readJsonBody(request));
    writeJson(response, 200, {
      result: simulation.submitCommand({ commandType: "move_party", command }).result,
      state: createClientState(requestUrl, graph, simulation),
    });
    return;
  }
  if (method === "POST" && requestUrl.pathname === "/api/time/advance") {
    const days = parseAdvanceTimeRequest(await readJsonBody(request));
    simulation.advanceDays(days);
    writeJson(response, 200, createClientState(requestUrl, graph, simulation));
    return;
  }
  if (method === "POST" && requestUrl.pathname === "/api/ai/merchant-step") {
    parseEmptyObjectRequest(await readJsonBody(request), "merchant AI step request");
    writeJson(response, 200, {
      decision: merchantAi.process(simulation, "player_party", merchantMemory),
      state: createClientState(requestUrl, graph, simulation),
    });
    return;
  }
  if (method === "POST" && requestUrl.pathname === "/api/reset") {
    parseEmptyObjectRequest(await readJsonBody(request), "reset request");
    simulation.reset();
    regionalEconomy = createSeasonalRegionalEconomyFixture(graph, travelConfig);
    writeJson(response, 200, createClientState(requestUrl, graph, simulation));
    return;
  }
  if (requestUrl.pathname.startsWith("/api/")) {
    writeJson(response, 404, { error: "API_ROUTE_NOT_FOUND", message: requestUrl.pathname });
    return;
  }

  vite.middlewares(request, response, (error?: unknown) => {
    if (error === undefined) return;
    const message = error instanceof Error ? error.message : String(error);
    writeJson(response, 500, { error: "VITE_MIDDLEWARE_ERROR", message });
  });
}

function requireTruthDiagnostics(requestUrl: URL): void {
  if (requestUrl.searchParams.get("view_mode") !== "truth") {
    throw new RequestValidationError("regional economy diagnostics require explicit truth view");
  }
}

function parseRegionalDaysRequest(value: unknown): number {
  const source = requireRecord(value, "regional economy advance request");
  if (!Number.isSafeInteger(source.days) || (source.days as number) < 1 || (source.days as number) > 30) {
    throw new RequestValidationError("regional economy days must be an integer from 1 to 30");
  }
  return source.days as number;
}

function createDebugState(regionGraph: RegionGraph, world: WorldSimulation): object {
  return {
    mode: "truth",
    region: {
      id: regionGraph.id,
      displayName: regionGraph.displayName,
      description: regionGraph.description,
      nodes: regionGraph.nodes,
      edges: regionGraph.edges,
      terrainAreas: regionGraph.terrainAreas,
      landmarks: regionGraph.landmarks,
    },
    snapshot: world.snapshot(),
    spatialTruth: {
      ...world.spatialTruthSnapshot(),
      selectedOwnerGraph: world.navigationKnowledgeGraph("player_party", "party"),
    },
  };
}

function createClientState(
  requestUrl: URL,
  regionGraph: RegionGraph,
  world: WorldSimulation,
): object {
  const mode = requestUrl.searchParams.get("view_mode");
  if (mode === "truth") return createDebugState(regionGraph, world);
  if (mode === "party") {
    const partyId = requestUrl.searchParams.get("party_id");
    if (partyId === null || partyId.length === 0) {
      throw new RequestValidationError("party_id is required for party view");
    }
    return world.partyMapSnapshot(partyId);
  }
  throw new RequestValidationError("view_mode must be either party or truth");
}

function parseServerPort(value: string | undefined): number {
  if (value === undefined) return 4173;
  const port = Number(value);
  if (!Number.isSafeInteger(port) || port < 1 || port > 65_535) {
    throw new Error(`PORT must be an integer between 1 and 65535; received ${value}.`);
  }
  return port;
}

async function readJsonBody(request: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  let receivedBytes = 0;
  for await (const chunk of request) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(String(chunk));
    receivedBytes += buffer.byteLength;
    if (receivedBytes > MAX_BODY_BYTES) throw new RequestValidationError("REQUEST_BODY_TOO_LARGE");
    chunks.push(buffer);
  }
  const text = Buffer.concat(chunks).toString("utf8");
  try {
    return JSON.parse(text) as unknown;
  } catch {
    throw new RequestValidationError("REQUEST_BODY_INVALID_JSON");
  }
}

function parseMovePartyCommand(value: unknown): MovePartyCommand {
  const source = requireRecord(value, "move party command");
  return {
    party_id: requireString(source.party_id, "party_id"),
    from_node_id: requireString(source.from_node_id, "from_node_id"),
    to_node_id: requireString(source.to_node_id, "to_node_id"),
  };
}

function parseAdvanceTimeRequest(value: unknown): number {
  const source = requireRecord(value, "advance time request");
  if (typeof source.days !== "number" || !Number.isFinite(source.days) || source.days <= 0) {
    throw new RequestValidationError("days must be a finite positive number");
  }
  return source.days;
}

function parseEmptyObjectRequest(value: unknown, label: string): void {
  const source = requireRecord(value, label);
  if (Object.keys(source).length > 0) {
    throw new RequestValidationError(`${label} must be an empty object`);
  }
}

function requireRecord(value: unknown, label: string): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new RequestValidationError(`${label} must be an object`);
  }
  return value as Record<string, unknown>;
}

function requireString(value: unknown, fieldName: string): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new RequestValidationError(`${fieldName} must be a non-empty string`);
  }
  return value;
}

function writeJson(response: ServerResponse, statusCode: number, payload: unknown): void {
  if (response.headersSent) return;
  const body = JSON.stringify(payload);
  response.writeHead(statusCode, {
    "cache-control": "no-store",
    "content-length": Buffer.byteLength(body),
    "content-type": "application/json; charset=utf-8",
  });
  response.end(body);
}

class RequestValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "RequestValidationError";
  }
}

server.listen(SERVER_PORT, "0.0.0.0", () => {
  console.log(`CaravanWars Truth Map: http://0.0.0.0:${SERVER_PORT}`);
});

async function shutdown(): Promise<void> {
  server.close();
  await vite.close();
}

process.once("SIGINT", () => { void shutdown(); });
process.once("SIGTERM", () => { void shutdown(); });
