import type { RegionGraph, RegionGraphEdge, RegionGraphNode, RegionTerrainArea, Vec2 } from "./region-graph.js";
import type { WorldMemoryEntryView, WorldMemoryOwnerView } from "./world-memory.js";

export const SPATIAL_TRAVEL_DUE = "SpatialTravelDue";
export const SPATIAL_SEARCH_DUE = "SpatialSearchDue";

export type SpatialTravelKind = "leave_road" | "known_target" | "known_coordinate" | "return_to_route";
export type NavigationKnowledgeKind = "node" | "landmark" | "edge" | "area" | "relation";

export interface UncertaintyCircle { readonly center: Vec2; readonly radiusKm: number }
export interface NavigationKnowledgeItem {
  readonly knowledgeId: string;
  readonly kind: NavigationKnowledgeKind;
  readonly worldObjectId: string | null;
  readonly estimatedPosition: Vec2 | null;
  readonly uncertainty: UncertaintyCircle | null;
  readonly relation: string | null;
  readonly confidencePermille: number;
  readonly provenanceEntryId: string;
  readonly freshness: "fresh" | "stale";
}

export interface NavigationKnowledgeGraph {
  readonly ownerId: string;
  readonly ownerKind: WorldMemoryOwnerView["ownerKind"];
  readonly nodes: readonly NavigationKnowledgeItem[];
  readonly landmarks: readonly NavigationKnowledgeItem[];
  readonly edges: readonly NavigationKnowledgeItem[];
  readonly areas: readonly NavigationKnowledgeItem[];
  readonly relations: readonly NavigationKnowledgeItem[];
}

export interface SpatialMovementConfig {
  readonly coordinateKmScale: number;
  readonly roadSpeedPermille: number;
  readonly trackSpeedPermille: number;
  readonly terrainSpeedPermille: Readonly<Record<string, number>>;
  readonly burdenSpeedFloorPermille: number;
  readonly winterSpeedPermille: number;
  readonly nightVisibilityPermille: number;
  readonly baseVisibilityKm: number;
  readonly maxSearchSteps: number;
}

export interface SpatialMetrics {
  readonly offRoadDistanceKm: number;
  readonly searchAreaCoveredKm2: number;
  readonly discoveries: number;
  readonly falseLeads: number;
  readonly hiddenSiteVisits: number;
}

export interface SpatialRuntimeSnapshot {
  readonly config: SpatialMovementConfig;
  readonly metrics: SpatialMetrics;
  readonly processedCommandIds: readonly { readonly commandId: string; readonly fingerprint: string; readonly result: SpatialCommandResult }[];
  readonly processedEventIds: readonly string[];
  readonly relocatedObjects: readonly { readonly worldObjectId: string; readonly position: Vec2 }[];
}

export interface SpatialTravelCommand {
  readonly commandId: string;
  readonly issuerActorId: string;
  readonly partyId: string;
  readonly kind: SpatialTravelKind;
  readonly targetKnowledgeId: string;
}

export interface SearchAreaCommand {
  readonly commandId: string;
  readonly issuerActorId: string;
  readonly partyId: string;
  readonly areaKnowledgeId: string;
  readonly searchRadiusKm: number;
  readonly observationSkillPermille: number;
}

export interface ObserveSurroundingsCommand {
  readonly commandId: string;
  readonly issuerActorId: string;
  readonly partyId: string;
  readonly observationSkillPermille: number;
}

export interface ReportNavigationKnowledgeCommand {
  readonly commandId: string;
  readonly issuerActorId: string;
  readonly reporterPartyId: string;
  readonly recipientOwnerId: string;
  readonly recipientOwnerKind: "actor" | "party";
  readonly sourceKnowledgeId: string;
  readonly knownDelayDays: number;
  readonly confidenceLossPermille: number;
  readonly distortionPermille: number;
}

export type SpatialCommandErrorCode = "PARTY_NOT_FOUND" | "PARTY_BUSY" | "NOT_AUTHORIZED" | "KNOWLEDGE_UNKNOWN" | "KNOWLEDGE_STALE" | "INVALID_COMMAND" | "SCHEDULING_FAILED" | "COMMAND_ID_CONFLICT";
export type SpatialCommandResult = { readonly accepted: true; readonly idempotentReplay: boolean; readonly scheduledEventId: string | null } | { readonly accepted: false; readonly idempotentReplay: boolean; readonly errorCode: SpatialCommandErrorCode; readonly message: string };

export interface SpatialTravelPlan {
  readonly commandId: string;
  readonly eventId: string;
  readonly partyId: string;
  readonly kind: SpatialTravelKind;
  readonly origin: Vec2;
  readonly destination: Vec2;
  readonly targetWorldObjectId: string | null;
  readonly distanceKm: number;
  readonly durationDays: number;
  readonly terrainAreaIds: readonly string[];
  readonly knowledgeEntryId: string;
}

export interface SpatialSearchPlan {
  readonly commandId: string;
  readonly eventId: string;
  readonly partyId: string;
  readonly center: Vec2;
  readonly radiusKm: number;
  readonly path: readonly Vec2[];
  readonly distanceKm: number;
  readonly durationDays: number;
  readonly observationSkillPermille: number;
  readonly knowledgeEntryId: string;
}

export class ContinuousSpace {
  readonly #config: SpatialMovementConfig;
  #metrics: SpatialMetrics;
  readonly #processedCommands = new Map<string, { readonly commandId: string; readonly fingerprint: string; readonly result: SpatialCommandResult }>();
  readonly #processedEvents = new Set<string>();
  readonly #relocatedObjects = new Map<string, Vec2>();

  constructor(snapshot: SpatialRuntimeSnapshot) {
    validateConfig(snapshot.config);
    this.#config = structuredClone(snapshot.config);
    this.#metrics = structuredClone(snapshot.metrics);
    for (const item of snapshot.processedCommandIds) this.#processedCommands.set(item.commandId, structuredClone(item));
    for (const id of snapshot.processedEventIds) this.#processedEvents.add(id);
    for (const item of snapshot.relocatedObjects) { validateVec2(item.position, item.worldObjectId); this.#relocatedObjects.set(item.worldObjectId, [...item.position]); }
  }

  static create(config: SpatialMovementConfig): ContinuousSpace {
    return new ContinuousSpace({ config, metrics: { offRoadDistanceKm: 0, searchAreaCoveredKm2: 0, discoveries: 0, falseLeads: 0, hiddenSiteVisits: 0 }, processedCommandIds: [], processedEventIds: [], relocatedObjects: [] });
  }

  replay(command: { readonly commandId: string }): SpatialCommandResult | null {
    const existing = this.#processedCommands.get(command.commandId); if (existing === undefined) return null;
    return existing.fingerprint === fingerprint(command) ? { ...existing.result, idempotentReplay: true } : rejected("COMMAND_ID_CONFLICT", `Spatial command ${command.commandId} has another payload.`);
  }

  record(command: { readonly commandId: string }, result: SpatialCommandResult): SpatialCommandResult {
    this.#processedCommands.set(command.commandId, { commandId: command.commandId, fingerprint: fingerprint(command), result: structuredClone(result) }); return result;
  }

  recordEvent(eventId: string): boolean { if (this.#processedEvents.has(eventId)) return false; this.#processedEvents.add(eventId); return true; }
  addTravel(distanceKm: number, hiddenVisit: boolean): void { this.#metrics = { ...this.#metrics, offRoadDistanceKm: this.#metrics.offRoadDistanceKm + distanceKm, hiddenSiteVisits: this.#metrics.hiddenSiteVisits + (hiddenVisit ? 1 : 0) }; }
  addSearch(radiusKm: number, discovered: boolean): void { this.#metrics = { ...this.#metrics, searchAreaCoveredKm2: this.#metrics.searchAreaCoveredKm2 + Math.PI * radiusKm * radiusKm, discoveries: this.#metrics.discoveries + (discovered ? 1 : 0), falseLeads: this.#metrics.falseLeads + (discovered ? 0 : 1) }; }
  relocate(worldObjectId: string, position: Vec2): void { validateVec2(position, worldObjectId); this.#relocatedObjects.set(worldObjectId, [...position]); }
  truthPosition(graph: RegionGraph, worldObjectId: string): Vec2 | null { return this.#relocatedObjects.get(worldObjectId) ?? graph.nodesById.get(worldObjectId)?.position ?? graph.landmarksById.get(worldObjectId)?.position ?? null; }
  config(): SpatialMovementConfig { return structuredClone(this.#config); }
  metrics(): SpatialMetrics { return structuredClone(this.#metrics); }
  snapshot(): SpatialRuntimeSnapshot { return { config: structuredClone(this.#config), metrics: this.metrics(), processedCommandIds: [...this.#processedCommands.values()].map((item) => structuredClone(item)), processedEventIds: [...this.#processedEvents], relocatedObjects: [...this.#relocatedObjects].map(([worldObjectId, position]) => ({ worldObjectId, position: [...position] })) }; }
}

export function buildNavigationKnowledgeGraph(view: WorldMemoryOwnerView): NavigationKnowledgeGraph {
  const items = view.entries.flatMap(parseKnowledgeEntry);
  const unique = new Map<string, NavigationKnowledgeItem>();
  for (const item of items) unique.set(item.knowledgeId, item);
  const values = [...unique.values()].sort((a, b) => a.knowledgeId < b.knowledgeId ? -1 : a.knowledgeId > b.knowledgeId ? 1 : 0);
  return { ownerId: view.ownerId, ownerKind: view.ownerKind, nodes: values.filter((item) => item.kind === "node"), landmarks: values.filter((item) => item.kind === "landmark"), edges: values.filter((item) => item.kind === "edge"), areas: values.filter((item) => item.kind === "area"), relations: values.filter((item) => item.kind === "relation") };
}

export function navigationItem(graph: NavigationKnowledgeGraph, knowledgeId: string): NavigationKnowledgeItem | null {
  return [...graph.nodes, ...graph.landmarks, ...graph.edges, ...graph.areas, ...graph.relations].find((item) => item.knowledgeId === knowledgeId) ?? null;
}

export function distance(a: Vec2, b: Vec2, coordinateKmScale = 1): number { validateVec2(a, "a"); validateVec2(b, "b"); if (!Number.isFinite(coordinateKmScale) || coordinateKmScale <= 0) throw new Error("coordinateKmScale must be positive."); return Math.hypot(b[0] - a[0], b[1] - a[1]) * coordinateKmScale; }
export function interpolate(a: Vec2, b: Vec2, ratio: number): Vec2 { if (!Number.isFinite(ratio)) throw new Error("Interpolation ratio must be finite."); const t = Math.max(0, Math.min(1, ratio)); return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]; }
export function pointInUncertainty(point: Vec2, area: UncertaintyCircle): boolean { return distance(point, area.center) <= area.radiusKm; }
export function terrainAt(graph: RegionGraph, point: Vec2): readonly RegionTerrainArea[] { return graph.terrainAreas.filter((area) => area.shape === "ellipse" ? ellipseContains(area, point) : polygonContains(area.polygon, point)); }
export function deterministicSearchPath(center: Vec2, radiusKm: number, steps: number): readonly Vec2[] { if (!Number.isFinite(radiusKm) || radiusKm <= 0 || !Number.isSafeInteger(steps) || steps < 4) throw new Error("Search radius/steps are invalid."); return Array.from({ length: steps }, (_, index) => { const ring = (index + 1) / steps * radiusKm, angle = index * Math.PI * (3 - Math.sqrt(5)); return [center[0] + Math.cos(angle) * ring, center[1] + Math.sin(angle) * ring] as Vec2; }); }
export function polylineDistance(path: readonly Vec2[], scale = 1): number { return path.slice(1).reduce((sum, point, index) => sum + distance(path[index]!, point, scale), 0); }
export function distanceToPolyline(point: Vec2, path: readonly Vec2[], scale = 1): number {
  if (path.length === 0) throw new Error("Polyline must contain a point.");
  if (path.length === 1) return distance(point, path[0]!, scale);
  let closest = Number.POSITIVE_INFINITY;
  for (let index = 1; index < path.length; index += 1) {
    const a = path[index - 1]!, b = path[index]!, dx = b[0] - a[0], dy = b[1] - a[1], denominator = dx * dx + dy * dy;
    const ratio = denominator === 0 ? 0 : Math.max(0, Math.min(1, ((point[0] - a[0]) * dx + (point[1] - a[1]) * dy) / denominator));
    closest = Math.min(closest, distance(point, [a[0] + dx * ratio, a[1] + dy * ratio], scale));
  }
  return closest;
}
export function pointAlongPolyline(path: readonly Vec2[], progressKm: number, scale = 1): Vec2 {
  if (path.length === 0 || !Number.isFinite(progressKm) || progressKm < 0) throw new Error("Polyline progress is invalid.");
  if (path.length === 1) return [...path[0]!];
  let remaining = progressKm;
  for (let index = 1; index < path.length; index += 1) {
    const from = path[index - 1]!, to = path[index]!, segmentKm = distance(from, to, scale);
    if (remaining <= segmentKm) return interpolate(from, to, segmentKm === 0 ? 1 : remaining / segmentKm);
    remaining -= segmentKm;
  }
  return [...path.at(-1)!];
}

export function spatialSpeedKmPerDay(baseSpeed: number, config: SpatialMovementConfig, terrainKinds: readonly string[], burdenPermille: number, healthPermille: number, winter: boolean, visibilityPermille: number, travelMode: "road" | "track" | "offroad"): number {
  const mode = travelMode === "road" ? config.roadSpeedPermille : travelMode === "track" ? config.trackSpeedPermille : 1000;
  const terrain = terrainKinds.reduce((lowest, kind) => Math.min(lowest, config.terrainSpeedPermille[kind] ?? 1000), 1000);
  const burden = Math.max(config.burdenSpeedFloorPermille, 1000 - Math.max(0, Math.min(1000, burdenPermille)) / 2);
  const result = baseSpeed * mode * terrain * burden * Math.max(100, healthPermille) * (winter ? config.winterSpeedPermille : 1000) * Math.max(100, visibilityPermille) / 1e18;
  return Math.max(0.1, result);
}

export function detectionSucceeds(seed: string, distanceKm: number, visibilityKm: number, skillPermille: number, concealmentPermille: number): boolean {
  if (distanceKm > visibilityKm) return false;
  const chance = Math.max(0, Math.min(1000, skillPermille + Math.round((1 - distanceKm / Math.max(visibilityKm, 0.001)) * 400) - concealmentPermille));
  return stableRoll(seed) < chance;
}

export function edgePolyline(graph: RegionGraph, edge: RegionGraphEdge): readonly Vec2[] { return [graph.nodesById.get(edge.originNodeId)!.position, ...edge.routeWaypoints.map((item) => item.position), graph.nodesById.get(edge.targetNodeId)!.position]; }
export function publicNodeKnowledge(node: RegionGraphNode, entryId: string): NavigationKnowledgeItem { return { knowledgeId: `node:${node.id}`, kind: "node", worldObjectId: node.id, estimatedPosition: [...node.position], uncertainty: null, relation: null, confidencePermille: 1000, provenanceEntryId: entryId, freshness: "fresh" }; }

function parseKnowledgeEntry(entry: WorldMemoryEntryView): readonly NavigationKnowledgeItem[] {
  if (!entry.kind.startsWith("navigation_")) return [];
  const payload = entry.payload, kind = payload.knowledgeKind;
  if (typeof payload.knowledgeId !== "string" || !["node", "landmark", "edge", "area", "relation"].includes(String(kind))) return [];
  const position = parseVec2(payload.estimatedPosition), center = parseVec2(payload.uncertaintyCenter);
  const radius = typeof payload.uncertaintyRadiusKm === "number" && Number.isFinite(payload.uncertaintyRadiusKm) && payload.uncertaintyRadiusKm > 0 ? payload.uncertaintyRadiusKm : null;
  const confidence = typeof payload.confidencePermille === "number" && Number.isSafeInteger(payload.confidencePermille) ? Math.max(0, Math.min(1000, payload.confidencePermille)) : 0;
  return [{ knowledgeId: payload.knowledgeId, kind: kind as NavigationKnowledgeKind, worldObjectId: typeof payload.worldObjectId === "string" ? payload.worldObjectId : null, estimatedPosition: position, uncertainty: center !== null && radius !== null ? { center, radiusKm: radius } : null, relation: typeof payload.relation === "string" ? payload.relation : null, confidencePermille: confidence, provenanceEntryId: entry.entryId, freshness: entry.freshness }];
}
function parseVec2(value: unknown): Vec2 | null { return Array.isArray(value) && value.length === 2 && value.every((item) => typeof item === "number" && Number.isFinite(item)) ? [value[0] as number, value[1] as number] : null; }
function ellipseContains(area: RegionTerrainArea, point: Vec2): boolean { const dx = (point[0] - area.center[0]) / area.radius[0], dy = (point[1] - area.center[1]) / area.radius[1]; return dx * dx + dy * dy <= 1; }
function polygonContains(polygon: readonly Vec2[], point: Vec2): boolean { let inside = false; for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) { const a = polygon[i]!, b = polygon[j]!; if ((a[1] > point[1]) !== (b[1] > point[1]) && point[0] < (b[0] - a[0]) * (point[1] - a[1]) / (b[1] - a[1]) + a[0]) inside = !inside; } return inside; }
function validateConfig(config: SpatialMovementConfig): void { for (const [key, value] of Object.entries(config)) if (key !== "terrainSpeedPermille" && (typeof value !== "number" || !Number.isFinite(value) || value <= 0)) throw new Error(`Invalid spatial config ${key}.`); for (const [kind, value] of Object.entries(config.terrainSpeedPermille)) if (kind.length === 0 || !Number.isSafeInteger(value) || value <= 0 || value > 2000) throw new Error("Invalid terrain speed config."); }
function validateVec2(value: Vec2, label: string): void { if (value.length !== 2 || value.some((item) => !Number.isFinite(item))) throw new Error(`Invalid coordinate ${label}.`); }
function stableRoll(value: string): number { let hash = 2166136261; for (let index = 0; index < value.length; index += 1) { hash ^= value.charCodeAt(index); hash = Math.imul(hash, 16777619); } return (hash >>> 0) % 1000; }
function rejected(errorCode: SpatialCommandErrorCode, message: string): SpatialCommandResult { return { accepted: false, idempotentReplay: false, errorCode, message }; }
function fingerprint(value: unknown): string { return JSON.stringify(sort(value)); }
function sort(value: unknown): unknown { if (Array.isArray(value)) return value.map(sort); if (value !== null && typeof value === "object") return Object.fromEntries(Object.entries(value).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0).map(([key, item]) => [key, sort(item)])); return value; }
