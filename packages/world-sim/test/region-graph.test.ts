import assert from "node:assert/strict";
import { resolve } from "node:path";
import test from "node:test";

import {
  RegionGraphValidationError,
  getEdgeBetween,
  getNeighbors,
  loadRegionGraphFile,
  parseRegionGraph,
} from "../src/index.js";

const SILESIA_PATH = resolve("data/regions/silesia.json");

test("loads the canonical Silesia graph with current authored geometry", () => {
  const graph = loadRegionGraphFile(SILESIA_PATH);

  assert.equal(graph.id, "silesia");
  assert.equal(graph.nodesById.size, 12);
  assert.equal(graph.edgesById.size, 19);
  assert.equal(graph.terrainAreasById.size, 3);
  assert.equal(graph.landmarksById.size, 7);
  assert.equal(graph.nodesById.get("black_pine_bandit_base")?.visibility, "hidden");
  assert.equal(graph.edgesById.get("great_forest_bandit_track")?.travelMode, "track");

  assert.ok(getNeighbors(graph, "wroclaw").includes("opole"));
  assert.equal(graph.landmarksById.get("sleza_massif")?.visibilityClass, "major");
  assert.equal(graph.terrainAreasById.get("odra_valley")?.polygon.length, 8);

  const wroclawOpole = getEdgeBetween(graph, "wroclaw", "opole");
  if (wroclawOpole === undefined) assert.fail("Expected Wroclaw-Opole edge.");
  assert.equal(wroclawOpole.routeWaypoints.length, 3);
  assert.deepEqual(wroclawOpole.routeWaypoints[0]?.terrainAreaIds, ["odra_valley"]);
  assert.deepEqual(wroclawOpole.routeWaypoints[0]?.landmarkIds, ["old_willow_ford"]);
});

test("rejects an edge that references a missing node", () => {
  const graph = loadRegionGraphFile(SILESIA_PATH);
  const input = toAuthoredShape(graph);
  input.edges[0] = { ...input.edges[0], to: "missing_city" };

  assert.throws(
    () => parseRegionGraph(input),
    (error: unknown) => error instanceof RegionGraphValidationError
      && error.validationErrors.includes("Edge prague_wroclaw references missing target node missing_city."),
  );
});

test("rejects duplicate ids instead of silently overwriting authored data", () => {
  const graph = loadRegionGraphFile(SILESIA_PATH);
  const input = toAuthoredShape(graph);
  input.nodes.push({ ...input.nodes[0] });

  assert.throws(
    () => parseRegionGraph(input),
    (error: unknown) => error instanceof RegionGraphValidationError
      && error.validationErrors.includes("Node id is duplicated: prague."),
  );
});

function toAuthoredShape(graph: ReturnType<typeof loadRegionGraphFile>): {
  id: string;
  display_name: string;
  description: string;
  nodes: Array<Record<string, unknown>>;
  edges: Array<Record<string, unknown>>;
  terrain_areas: Array<Record<string, unknown>>;
  landmarks: Array<Record<string, unknown>>;
} {
  return {
    id: graph.id,
    display_name: graph.displayName,
    description: graph.description,
    nodes: graph.nodes.map((node) => ({
      id: node.id,
      display_name: node.displayName,
      kind: node.kind,
      notes: node.notes,
      position: [...node.position],
    })),
    edges: graph.edges.map((edge) => ({
      id: edge.id,
      from: edge.originNodeId,
      to: edge.targetNodeId,
      distance_km: edge.distanceKm,
      kind: edge.kind,
      waypoints: edge.waypointCoordinates.map((point) => [...point]),
      geometry: edge.routeWaypoints.map((waypoint) => ({
        id: waypoint.id,
        kind: waypoint.kind,
        position: [...waypoint.position],
        distance_from_start_km: waypoint.distanceFromStartKm,
        elevation_m: waypoint.elevationM,
        travel_time_modifier: waypoint.travelTimeModifier,
        terrain_area_ids: [...waypoint.terrainAreaIds],
        landmark_ids: [...waypoint.landmarkIds],
        landmark_tags: [...waypoint.landmarkTags],
        notes: waypoint.notes,
      })),
    })),
    terrain_areas: graph.terrainAreas.map((area) => ({
      id: area.id,
      display_name: area.displayName,
      kind: area.kind,
      shape: area.shape,
      center: [...area.center],
      radius: [...area.radius],
      polygon: area.polygon.map((point) => [...point]),
      notes: area.notes,
    })),
    landmarks: graph.landmarks.map((landmark) => ({
      id: landmark.id,
      display_name: landmark.displayName,
      kind: landmark.kind,
      position: [...landmark.position],
      elevation_m: landmark.elevationM,
      visibility_class: landmark.visibilityClass,
      notes: landmark.notes,
    })),
  };
}
