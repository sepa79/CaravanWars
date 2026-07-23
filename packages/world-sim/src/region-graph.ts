import { readFileSync } from "node:fs";

export type Vec2 = readonly [number, number];

export interface RegionGraphNode {
  readonly id: string;
  readonly displayName: string;
  readonly kind: string;
  readonly notes: string;
  readonly position: Vec2;
}

export interface RegionRouteWaypoint {
  readonly id: string;
  readonly kind: string;
  readonly position: Vec2;
  readonly distanceFromStartKm: number;
  readonly elevationM: number;
  readonly travelTimeModifier: number;
  readonly terrainAreaIds: readonly string[];
  readonly landmarkIds: readonly string[];
  readonly landmarkTags: readonly string[];
  readonly notes: string;
}

export interface RegionGraphEdge {
  readonly id: string;
  readonly originNodeId: string;
  readonly targetNodeId: string;
  readonly distanceKm: number;
  readonly kind: string;
  readonly waypointCoordinates: readonly Vec2[];
  readonly routeWaypoints: readonly RegionRouteWaypoint[];
}

export interface RegionTerrainArea {
  readonly id: string;
  readonly displayName: string;
  readonly kind: string;
  readonly shape: string;
  readonly center: Vec2;
  readonly radius: Vec2;
  readonly polygon: readonly Vec2[];
  readonly notes: string;
}

export interface RegionLandmark {
  readonly id: string;
  readonly displayName: string;
  readonly kind: string;
  readonly position: Vec2;
  readonly elevationM: number;
  readonly visibilityClass: string;
  readonly notes: string;
}

export interface RegionGraph {
  readonly id: string;
  readonly displayName: string;
  readonly description: string;
  readonly nodes: readonly RegionGraphNode[];
  readonly edges: readonly RegionGraphEdge[];
  readonly terrainAreas: readonly RegionTerrainArea[];
  readonly landmarks: readonly RegionLandmark[];
  readonly nodesById: ReadonlyMap<string, RegionGraphNode>;
  readonly edgesById: ReadonlyMap<string, RegionGraphEdge>;
  readonly terrainAreasById: ReadonlyMap<string, RegionTerrainArea>;
  readonly landmarksById: ReadonlyMap<string, RegionLandmark>;
}

type JsonRecord = Record<string, unknown>;

export class RegionGraphValidationError extends Error {
  readonly validationErrors: readonly string[];

  constructor(validationErrors: readonly string[]) {
    super(`Region graph validation failed:\n${validationErrors.join("\n")}`);
    this.name = "RegionGraphValidationError";
    this.validationErrors = [...validationErrors];
  }
}

export function loadRegionGraphFile(filePath: string): RegionGraph {
  const fileText = readFileSync(filePath, "utf8");
  let parsed: unknown;
  try {
    parsed = JSON.parse(fileText) as unknown;
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    throw new RegionGraphValidationError([`Region graph JSON is invalid: ${message}`]);
  }
  return parseRegionGraph(parsed);
}

export function parseRegionGraph(input: unknown): RegionGraph {
  const source = requireRecord(input, "region graph");
  const nodes = requireArray(source.nodes, "region graph.nodes").map((value, index) =>
    parseNode(value, `region graph.nodes[${index}]`),
  );
  const edges = requireArray(source.edges, "region graph.edges").map((value, index) =>
    parseEdge(value, `region graph.edges[${index}]`),
  );
  const terrainAreas = requireArray(source.terrain_areas, "region graph.terrain_areas").map(
    (value, index) => parseTerrainArea(value, `region graph.terrain_areas[${index}]`),
  );
  const landmarks = requireArray(source.landmarks, "region graph.landmarks").map((value, index) =>
    parseLandmark(value, `region graph.landmarks[${index}]`),
  );

  const validationErrors: string[] = [];
  const nodesById = indexByUniqueId("Node", nodes, validationErrors);
  const edgesById = indexByUniqueId("Edge", edges, validationErrors);
  const terrainAreasById = indexByUniqueId("Terrain area", terrainAreas, validationErrors);
  const landmarksById = indexByUniqueId("Landmark", landmarks, validationErrors);

  const id = requireString(source.id, "region graph.id");
  if (id.length === 0) validationErrors.push("Region graph id is empty.");

  validateEdges(edges, nodesById, terrainAreasById, landmarksById, validationErrors);
  validateTerrainAreas(terrainAreas, validationErrors);

  if (validationErrors.length > 0) throw new RegionGraphValidationError(validationErrors);

  return {
    id,
    displayName: requireString(source.display_name, "region graph.display_name"),
    description: optionalString(source.description, "region graph.description"),
    nodes,
    edges,
    terrainAreas,
    landmarks,
    nodesById,
    edgesById,
    terrainAreasById,
    landmarksById,
  };
}

export function getNeighbors(graph: RegionGraph, nodeId: string): readonly string[] {
  const neighbors: string[] = [];
  for (const edge of graph.edges) {
    if (edge.originNodeId === nodeId) neighbors.push(edge.targetNodeId);
    else if (edge.targetNodeId === nodeId) neighbors.push(edge.originNodeId);
  }
  return neighbors;
}

export function getEdgeBetween(
  graph: RegionGraph,
  firstNodeId: string,
  secondNodeId: string,
): RegionGraphEdge | undefined {
  return graph.edges.find((edge) =>
    (edge.originNodeId === firstNodeId && edge.targetNodeId === secondNodeId)
    || (edge.originNodeId === secondNodeId && edge.targetNodeId === firstNodeId),
  );
}

function parseNode(input: unknown, path: string): RegionGraphNode {
  const source = requireRecord(input, path);
  return {
    id: requireString(source.id, `${path}.id`),
    displayName: requireString(source.display_name, `${path}.display_name`),
    kind: requireString(source.kind, `${path}.kind`),
    notes: optionalString(source.notes, `${path}.notes`),
    position: requireVec2(source.position, `${path}.position`),
  };
}

function parseEdge(input: unknown, path: string): RegionGraphEdge {
  const source = requireRecord(input, path);
  return {
    id: requireString(source.id, `${path}.id`),
    originNodeId: requireString(source.from, `${path}.from`),
    targetNodeId: requireString(source.to, `${path}.to`),
    distanceKm: requireNumber(source.distance_km, `${path}.distance_km`),
    kind: requireString(source.kind, `${path}.kind`),
    waypointCoordinates: optionalArray(source.waypoints, `${path}.waypoints`).map((value, index) =>
      requireVec2(value, `${path}.waypoints[${index}]`),
    ),
    routeWaypoints: optionalArray(source.geometry, `${path}.geometry`).map((value, index) =>
      parseRouteWaypoint(value, `${path}.geometry[${index}]`),
    ),
  };
}

function parseRouteWaypoint(input: unknown, path: string): RegionRouteWaypoint {
  const source = requireRecord(input, path);
  return {
    id: requireString(source.id, `${path}.id`),
    kind: requireString(source.kind, `${path}.kind`),
    position: requireVec2(source.position, `${path}.position`),
    distanceFromStartKm: requireNumber(source.distance_from_start_km, `${path}.distance_from_start_km`),
    elevationM: optionalNumber(source.elevation_m, `${path}.elevation_m`, 0),
    travelTimeModifier: optionalNumber(source.travel_time_modifier, `${path}.travel_time_modifier`, 1),
    terrainAreaIds: optionalStringArray(source.terrain_area_ids, `${path}.terrain_area_ids`),
    landmarkIds: optionalStringArray(source.landmark_ids, `${path}.landmark_ids`),
    landmarkTags: optionalStringArray(source.landmark_tags, `${path}.landmark_tags`),
    notes: optionalString(source.notes, `${path}.notes`),
  };
}

function parseTerrainArea(input: unknown, path: string): RegionTerrainArea {
  const source = requireRecord(input, path);
  return {
    id: requireString(source.id, `${path}.id`),
    displayName: requireString(source.display_name, `${path}.display_name`),
    kind: requireString(source.kind, `${path}.kind`),
    shape: requireString(source.shape, `${path}.shape`),
    center: optionalVec2(source.center, `${path}.center`, [0, 0]),
    radius: optionalVec2(source.radius, `${path}.radius`, [0, 0]),
    polygon: optionalArray(source.polygon, `${path}.polygon`).map((value, index) =>
      requireVec2(value, `${path}.polygon[${index}]`),
    ),
    notes: optionalString(source.notes, `${path}.notes`),
  };
}

function parseLandmark(input: unknown, path: string): RegionLandmark {
  const source = requireRecord(input, path);
  return {
    id: requireString(source.id, `${path}.id`),
    displayName: requireString(source.display_name, `${path}.display_name`),
    kind: requireString(source.kind, `${path}.kind`),
    position: requireVec2(source.position, `${path}.position`),
    elevationM: optionalNumber(source.elevation_m, `${path}.elevation_m`, 0),
    visibilityClass: optionalString(source.visibility_class, `${path}.visibility_class`, "local"),
    notes: optionalString(source.notes, `${path}.notes`),
  };
}

function validateEdges(
  edges: readonly RegionGraphEdge[],
  nodesById: ReadonlyMap<string, RegionGraphNode>,
  terrainAreasById: ReadonlyMap<string, RegionTerrainArea>,
  landmarksById: ReadonlyMap<string, RegionLandmark>,
  errors: string[],
): void {
  for (const edge of edges) {
    if (!nodesById.has(edge.originNodeId)) {
      errors.push(`Edge ${edge.id} references missing origin node ${edge.originNodeId}.`);
    }
    if (!nodesById.has(edge.targetNodeId)) {
      errors.push(`Edge ${edge.id} references missing target node ${edge.targetNodeId}.`);
    }
    if (edge.distanceKm <= 0) errors.push(`Edge ${edge.id} has non-positive distance.`);

    let previousDistance = -1;
    for (const waypoint of edge.routeWaypoints) {
      if (waypoint.id.length === 0) errors.push(`Edge ${edge.id} has route waypoint with empty id.`);
      if (waypoint.distanceFromStartKm <= 0) {
        errors.push(`Route waypoint ${waypoint.id} on edge ${edge.id} has non-positive distance_from_start_km.`);
      }
      if (waypoint.distanceFromStartKm >= edge.distanceKm) {
        errors.push(`Route waypoint ${waypoint.id} on edge ${edge.id} is beyond edge distance.`);
      }
      if (waypoint.distanceFromStartKm <= previousDistance) {
        errors.push(`Route waypoint ${waypoint.id} on edge ${edge.id} is not ordered by distance.`);
      }
      if (waypoint.travelTimeModifier <= 0) {
        errors.push(`Route waypoint ${waypoint.id} on edge ${edge.id} has non-positive travel_time_modifier.`);
      }
      for (const terrainAreaId of waypoint.terrainAreaIds) {
        if (!terrainAreasById.has(terrainAreaId)) {
          errors.push(`Route waypoint ${waypoint.id} on edge ${edge.id} references missing terrain area ${terrainAreaId}.`);
        }
      }
      for (const landmarkId of waypoint.landmarkIds) {
        if (!landmarksById.has(landmarkId)) {
          errors.push(`Route waypoint ${waypoint.id} on edge ${edge.id} references missing landmark ${landmarkId}.`);
        }
      }
      previousDistance = waypoint.distanceFromStartKm;
    }
  }
}

function validateTerrainAreas(terrainAreas: readonly RegionTerrainArea[], errors: string[]): void {
  for (const area of terrainAreas) {
    if (area.shape === "polygon" && area.polygon.length < 3) {
      errors.push(`Terrain area ${area.id} polygon has fewer than 3 points.`);
    }
    if (area.shape === "ellipse" && (area.radius[0] <= 0 || area.radius[1] <= 0)) {
      errors.push(`Terrain area ${area.id} ellipse has non-positive radius.`);
    }
  }
}

function indexByUniqueId<T extends { readonly id: string }>(
  label: string,
  items: readonly T[],
  errors: string[],
): ReadonlyMap<string, T> {
  const index = new Map<string, T>();
  for (const item of items) {
    if (item.id.length === 0) errors.push(`${label} has empty id.`);
    if (index.has(item.id)) errors.push(`${label} id is duplicated: ${item.id}.`);
    else index.set(item.id, item);
  }
  return index;
}

function requireRecord(value: unknown, path: string): JsonRecord {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new RegionGraphValidationError([`${path} must be an object.`]);
  }
  return value as JsonRecord;
}

function requireArray(value: unknown, path: string): readonly unknown[] {
  if (!Array.isArray(value)) throw new RegionGraphValidationError([`${path} must be an array.`]);
  return value;
}

function optionalArray(value: unknown, path: string): readonly unknown[] {
  return value === undefined ? [] : requireArray(value, path);
}

function requireString(value: unknown, path: string): string {
  if (typeof value !== "string") throw new RegionGraphValidationError([`${path} must be a string.`]);
  return value;
}

function optionalString(value: unknown, path: string, defaultValue = ""): string {
  return value === undefined ? defaultValue : requireString(value, path);
}

function requireNumber(value: unknown, path: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new RegionGraphValidationError([`${path} must be a finite number.`]);
  }
  return value;
}

function optionalNumber(value: unknown, path: string, defaultValue: number): number {
  return value === undefined ? defaultValue : requireNumber(value, path);
}

function requireVec2(value: unknown, path: string): Vec2 {
  const items = requireArray(value, path);
  if (items.length !== 2) throw new RegionGraphValidationError([`${path} must contain exactly two numbers.`]);
  return [requireNumber(items[0], `${path}[0]`), requireNumber(items[1], `${path}[1]`)];
}

function optionalVec2(value: unknown, path: string, defaultValue: Vec2): Vec2 {
  return value === undefined ? defaultValue : requireVec2(value, path);
}

function optionalStringArray(value: unknown, path: string): readonly string[] {
  return optionalArray(value, path).map((item, index) => requireString(item, `${path}[${index}]`));
}
