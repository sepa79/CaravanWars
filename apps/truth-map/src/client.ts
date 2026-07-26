import { translate, translateDocument } from "./i18n.js";

type Vec2 = readonly [number, number];

interface GraphNode {
  readonly id: string;
  readonly displayName: string;
  readonly kind: string;
  readonly position: Vec2;
}

interface RouteWaypoint {
  readonly id: string;
  readonly kind: string;
  readonly position: Vec2;
  readonly distanceFromStartKm: number;
}

interface GraphEdge {
  readonly id: string;
  readonly originNodeId: string;
  readonly targetNodeId: string;
  readonly distanceKm: number;
  readonly kind: string;
  readonly routeWaypoints: readonly RouteWaypoint[];
}

interface TerrainArea {
  readonly id: string;
  readonly displayName: string;
  readonly kind: string;
  readonly shape: string;
  readonly center: Vec2;
  readonly radius: Vec2;
  readonly polygon: readonly Vec2[];
}

interface Landmark {
  readonly id: string;
  readonly displayName: string;
  readonly kind: string;
  readonly position: Vec2;
  readonly visibilityClass: string;
}

interface RegionState {
  readonly id: string;
  readonly displayName: string;
  readonly nodes: readonly GraphNode[];
  readonly edges: readonly GraphEdge[];
  readonly terrainAreas: readonly TerrainArea[];
  readonly landmarks: readonly Landmark[];
}

interface PartyTravel {
  readonly edgeId: string;
  readonly originNodeId: string;
  readonly destinationNodeId: string;
  readonly distanceKm: number;
  readonly progressKm: number;
  readonly speedKmPerDay: number;
}

interface PartyState {
  readonly id: string;
  readonly displayName: string;
  readonly status: "idle" | "traveling";
  readonly currentNodeId: string | null;
  readonly position: Vec2;
  readonly knownRouteIds: readonly string[];
  readonly cargo: Readonly<Record<string, number>>;
  readonly travel: PartyTravel | null;
}

interface LocationState {
  readonly id: string;
  readonly displayName: string;
  readonly nodeId: string;
  readonly resources: Readonly<Record<string, number>>;
}

interface DebugState {
  readonly mode: "truth" | "party";
  readonly region: RegionState;
  readonly snapshot: {
    readonly clock: { readonly elapsedDays: number };
    readonly parties: readonly PartyState[];
    readonly locations: readonly LocationState[];
  };
}

interface MovePartyResponse {
  readonly result:
    | { readonly accepted: true }
    | { readonly accepted: false; readonly errorCode: string; readonly message: string };
  readonly state: DebugState;
}

interface MerchantStepResponse {
  readonly decision: {
    readonly action: "none" | "withdraw" | "travel" | "deposit";
    readonly reason: string;
    readonly commandResult: { readonly accepted: boolean } | null;
  };
  readonly state: DebugState;
}

interface EconomyDiagnostics {
  readonly truthView: true;
  readonly metrics: {
    readonly elapsedDays: number;
    readonly trades: number;
    readonly shortages: number;
    readonly activeTasks: number;
    readonly transportDistanceKm: number;
  };
  readonly recentDecisions: readonly { readonly actorId: string; readonly reason: string; readonly accepted: boolean | null }[];
  readonly calendar?: { readonly year: number; readonly dayOfYear: number; readonly season: string };
  readonly profiles?: { readonly instances: readonly { readonly profileId: string; readonly processStages: Readonly<Record<string, string>> }[] } | null;
  readonly winterReserves?: readonly { readonly hay: number; readonly seedGrain: number; readonly edibleGrain: number }[];
  readonly annualReports?: readonly { readonly year: number; readonly grossHarvest: number; readonly edibleSurplus: number; readonly spoilage: number }[];
  readonly populationDynamics?: { readonly settlements: readonly { readonly settlementId: string; readonly cohorts: { readonly children: number; readonly workingAdults: number; readonly elders: number }; readonly healthPermille: number; readonly nutritionPermille: number; readonly allocations: readonly { readonly sector: string; readonly workers: number }[] }[] } | null;
}

const canvas = requireElement<HTMLCanvasElement>("mapCanvas");
const context = requireCanvasContext(canvas);

const partyName = requireElement<HTMLElement>("partyName");
const partyId = requireElement<HTMLElement>("partyId");
const partyStatus = requireElement<HTMLElement>("partyStatus");
const partyLocation = requireElement<HTMLElement>("partyLocation");
const partySpeed = requireElement<HTMLElement>("partySpeed");
const destination = requireElement<HTMLSelectElement>("destination");
const moveButton = requireElement<HTMLButtonElement>("moveButton");
const commandResult = requireElement<HTMLElement>("commandResult");
const clock = requireElement<HTMLElement>("clock");
const advanceSixHours = requireElement<HTMLButtonElement>("advanceSixHours");
const advanceDay = requireElement<HTMLButtonElement>("advanceDay");
const autoAdvance = requireElement<HTMLInputElement>("autoAdvance");
const resetButton = requireElement<HTMLButtonElement>("resetButton");
const regionName = requireElement<HTMLElement>("regionName");
const regionStats = requireElement<HTMLElement>("regionStats");
const mapMode = requireElement<HTMLSelectElement>("mapMode");
const mapScopeLabel = requireElement<HTMLElement>("mapScopeLabel");
const cargoFood = requireElement<HTMLElement>("cargoFood");
const localFood = requireElement<HTMLElement>("localFood");
const merchantStep = requireElement<HTMLButtonElement>("merchantStep");
const merchantResult = requireElement<HTMLElement>("merchantResult");
const economyDiagnostics = requireElement<HTMLElement>("economyDiagnostics");
const economyDay = requireElement<HTMLElement>("economyDay");
const economyTrades = requireElement<HTMLElement>("economyTrades");
const economyShortages = requireElement<HTMLElement>("economyShortages");
const economyTasks = requireElement<HTMLElement>("economyTasks");
const economyDistance = requireElement<HTMLElement>("economyDistance");
const economySeason = requireElement<HTMLElement>("economySeason");
const economyProfiles = requireElement<HTMLElement>("economyProfiles");
const economyReserves = requireElement<HTMLElement>("economyReserves");
const economyAnnualChart = requireElement<HTMLElement>("economyAnnualChart");
const economyPopulation = requireElement<HTMLElement>("economyPopulation");
const economyLabour = requireElement<HTMLElement>("economyLabour");
const economyDecisions = requireElement<HTMLOListElement>("economyDecisions");
const advanceEconomy = requireElement<HTMLButtonElement>("advanceEconomy");

let state: DebugState | null = null;
let requestInFlight = false;
let autoAdvanceTimer: number | null = null;

translateDocument();
window.addEventListener("resize", render);
moveButton.addEventListener("click", () => { void submitMove(); });
advanceSixHours.addEventListener("click", () => { void advanceTime(0.25); });
advanceDay.addEventListener("click", () => { void advanceTime(1); });
resetButton.addEventListener("click", () => { void resetSimulation(); });
mapMode.addEventListener("change", () => { void refreshState(); });
merchantStep.addEventListener("click", () => { void runMerchantStep(); });
advanceEconomy.addEventListener("click", () => { void advanceRegionalEconomy(); });
autoAdvance.addEventListener("change", updateAutoAdvance);

void refreshState();
window.setInterval(() => { void refreshState(false); }, 1_000);

async function refreshState(reportFailure = true): Promise<void> {
  try {
    state = await requestJson<DebugState>(viewUrl("/api/state"));
    updateView();
    await refreshEconomyDiagnostics();
  } catch (error: unknown) {
    if (reportFailure) showError(error);
  }
}

async function refreshEconomyDiagnostics(): Promise<void> {
  const truth = mapMode.value === "truth";
  economyDiagnostics.hidden = !truth;
  if (!truth) return;
  const diagnostics = await requestJson<EconomyDiagnostics>("/api/economy?view_mode=truth");
  renderEconomyDiagnostics(diagnostics);
}

async function advanceRegionalEconomy(): Promise<void> {
  try {
    const diagnostics = await postJson<EconomyDiagnostics>("/api/economy/advance?view_mode=truth", { days: 1 });
    renderEconomyDiagnostics(diagnostics);
  } catch (error: unknown) {
    showError(error);
  }
}

function renderEconomyDiagnostics(diagnostics: EconomyDiagnostics): void {
  economyDay.textContent = diagnostics.metrics.elapsedDays.toFixed(2);
  economyTrades.textContent = String(diagnostics.metrics.trades);
  economyShortages.textContent = String(diagnostics.metrics.shortages);
  economyTasks.textContent = String(diagnostics.metrics.activeTasks);
  economyDistance.textContent = `${diagnostics.metrics.transportDistanceKm.toFixed(0)} km`;
  economySeason.textContent = diagnostics.calendar === undefined ? "—" : `${diagnostics.calendar.season}, Y${diagnostics.calendar.year} D${diagnostics.calendar.dayOfYear}`;
  economyProfiles.textContent = diagnostics.profiles?.instances.map((item) => `${item.profileId}: ${Object.values(item.processStages).join("/")}`).join("; ") ?? "—";
  const reserves = diagnostics.winterReserves ?? [];
  economyReserves.textContent = `hay ${reserves.reduce((sum, item) => sum + item.hay, 0)}, seed ${reserves.reduce((sum, item) => sum + item.seedGrain, 0)}, grain ${reserves.reduce((sum, item) => sum + item.edibleGrain, 0)}`;
  economyAnnualChart.textContent = diagnostics.annualReports?.map((item) => `Y${item.year} harvest ${item.grossHarvest} surplus ${item.edibleSurplus} spoilage ${item.spoilage}`).join(" | ") || "Annual production chart: no completed year";
  const population = diagnostics.populationDynamics?.settlements ?? [];
  economyPopulation.textContent = population.map((item) => `${item.settlementId}: ${item.cohorts.children + item.cohorts.workingAdults + item.cohorts.elders} h${item.healthPermille} n${item.nutritionPermille}`).join("; ") || "—";
  economyLabour.textContent = population.flatMap((item) => item.allocations.map((allocation) => `${item.settlementId}/${allocation.sector}:${allocation.workers}`)).join("; ") || "unallocated";
  economyDecisions.replaceChildren(...diagnostics.recentDecisions.slice(-6).map((decision) => {
    const item = document.createElement("li");
    item.textContent = `${decision.actorId}: ${decision.reason}${decision.accepted === false ? " [rejected]" : ""}`;
    return item;
  }));
}

async function submitMove(): Promise<void> {
  const currentState = state;
  const party = currentState?.snapshot.parties[0];
  if (currentState === null || currentState === undefined || party?.currentNodeId === null
    || party?.currentNodeId === undefined || destination.value.length === 0) return;

  try {
    const response = await postJson<MovePartyResponse>(viewUrl("/api/commands/move-party"), {
      party_id: party.id,
      from_node_id: party.currentNodeId,
      to_node_id: destination.value,
    });
    state = response.state;
    if (response.result.accepted) showMessage(translate("commandAccepted"), false);
    else showMessage(`${response.result.errorCode}: ${response.result.message}`, true);
    updateView();
  } catch (error: unknown) {
    showError(error);
  }
}

async function advanceTime(days: number): Promise<void> {
  if (requestInFlight) return;
  requestInFlight = true;
  try {
    state = await postJson<DebugState>(viewUrl("/api/time/advance"), { days });
    updateView();
  } catch (error: unknown) {
    showError(error);
  } finally {
    requestInFlight = false;
  }
}

async function resetSimulation(): Promise<void> {
  try {
    state = await postJson<DebugState>(viewUrl("/api/reset"), {});
    autoAdvance.checked = false;
    updateAutoAdvance();
    showMessage(translate("resetComplete"), false);
    updateView();
  } catch (error: unknown) {
    showError(error);
  }
}

async function runMerchantStep(): Promise<void> {
  try {
    const response = await postJson<MerchantStepResponse>(viewUrl("/api/ai/merchant-step"), {});
    state = response.state;
    merchantResult.textContent = response.decision.action === "none"
      ? `${translate("merchantNone")}: ${response.decision.reason}`
      : `${response.decision.action}: ${response.decision.reason}`;
    merchantResult.classList.toggle("error", response.decision.commandResult?.accepted === false);
    updateView();
  } catch (error: unknown) {
    showError(error);
  }
}

function updateAutoAdvance(): void {
  if (autoAdvanceTimer !== null) {
    window.clearInterval(autoAdvanceTimer);
    autoAdvanceTimer = null;
  }
  if (autoAdvance.checked) {
    autoAdvanceTimer = window.setInterval(() => { void advanceTime(1 / 24); }, 250);
  }
}

function updateView(): void {
  const currentState = state;
  if (currentState === null) return;
  const party = currentState.snapshot.parties[0];
  if (party === undefined) throw new Error("Debug state contains no party.");

  partyName.textContent = party.displayName;
  partyId.textContent = party.id;
  partyStatus.textContent = party.status === "idle" ? translate("idle") : translate("traveling");
  partyLocation.textContent = describeLocation(currentState.region, party);
  partySpeed.textContent = party.travel === null
    ? "—"
    : `${party.travel.speedKmPerDay.toFixed(1)} km/dzień`;
  cargoFood.textContent = String(party.cargo.food ?? 0);
  const localLocation = currentState.snapshot.locations.find((location) =>
    location.nodeId === party.currentNodeId);
  localFood.textContent = localLocation === undefined
    ? "—"
    : String(localLocation.resources.food ?? 0);
  clock.textContent = formatClock(currentState.snapshot.clock.elapsedDays);
  regionName.textContent = currentState.region.displayName;
  mapMode.value = currentState.mode;
  mapScopeLabel.textContent = currentState.mode === "truth"
    ? translate("authoritativeRegion")
    : translate("knownRegion");
  regionStats.textContent = `${currentState.region.nodes.length} miejsc · ${currentState.region.edges.length} dróg · ${currentState.region.landmarks.length} landmarki`;
  updateDestinations(currentState.region, party);
  render();
}

function updateDestinations(region: RegionState, party: PartyState): void {
  const previousValue = destination.value;
  destination.replaceChildren();
  if (party.status !== "idle" || party.currentNodeId === null) {
    const option = new Option(translate("traveling"), "");
    destination.add(option);
    destination.disabled = true;
    moveButton.disabled = true;
    return;
  }

  const routeTargets = region.edges.flatMap((edge) => {
    if (!party.knownRouteIds.includes(edge.id)) return [];
    if (edge.originNodeId === party.currentNodeId) return [edge.targetNodeId];
    if (edge.targetNodeId === party.currentNodeId) return [edge.originNodeId];
    return [];
  });
  for (const targetId of routeTargets) {
    const node = region.nodes.find((candidate) => candidate.id === targetId);
    if (node !== undefined) destination.add(new Option(node.displayName, node.id));
  }
  if ([...destination.options].some((option) => option.value === previousValue)) {
    destination.value = previousValue;
  }
  if (destination.options.length === 0) destination.add(new Option(translate("noDestination"), ""));
  destination.disabled = destination.options.length === 0 || destination.value.length === 0;
  moveButton.disabled = destination.disabled;
}

function describeLocation(region: RegionState, party: PartyState): string {
  if (party.currentNodeId !== null) {
    return region.nodes.find((node) => node.id === party.currentNodeId)?.displayName
      ?? party.currentNodeId;
  }
  if (party.travel !== null) {
    const destinationNode = region.nodes.find((node) => node.id === party.travel?.destinationNodeId);
    return `${party.travel.progressKm.toFixed(1)} / ${party.travel.distanceKm.toFixed(0)} km → ${destinationNode?.displayName ?? party.travel.destinationNodeId}`;
  }
  return translate("unknown");
}

function formatClock(elapsedDays: number): string {
  const completedDays = Math.floor(elapsedDays);
  const hours = Math.floor((elapsedDays - completedDays) * 24 + 1e-8);
  return `Dzień ${completedDays + 1}, ${String(hours).padStart(2, "0")}:00`;
}

function render(): void {
  const currentState = state;
  if (currentState === null) return;
  const bounds = canvas.getBoundingClientRect();
  const deviceScale = window.devicePixelRatio || 1;
  canvas.width = Math.max(1, Math.floor(bounds.width * deviceScale));
  canvas.height = Math.max(1, Math.floor(bounds.height * deviceScale));
  context.setTransform(deviceScale, 0, 0, deviceScale, 0, 0);
  context.clearRect(0, 0, bounds.width, bounds.height);

  const projection = createProjection(currentState.region, bounds.width, bounds.height);
  drawTerrain(currentState.region, projection);
  drawEdges(currentState.region, projection);
  drawLandmarks(currentState.region, projection);
  drawNodes(currentState.region, projection);
  for (const party of currentState.snapshot.parties) drawParty(party, projection);
}

type Projection = (point: Vec2) => Vec2;

function createProjection(region: RegionState, width: number, height: number): Projection {
  const points: Vec2[] = [
    ...region.nodes.map((node) => node.position),
    ...region.landmarks.map((landmark) => landmark.position),
    ...region.edges.flatMap((edge) => edge.routeWaypoints.map((waypoint) => waypoint.position)),
    ...region.terrainAreas.flatMap((area) => area.shape === "polygon"
      ? [...area.polygon]
      : [
          [area.center[0] - area.radius[0], area.center[1] - area.radius[1]] as Vec2,
          [area.center[0] + area.radius[0], area.center[1] + area.radius[1]] as Vec2,
        ]),
  ];
  const xs = points.map((point) => point[0]);
  const ys = points.map((point) => point[1]);
  const minimumX = Math.min(...xs);
  const maximumX = Math.max(...xs);
  const minimumY = Math.min(...ys);
  const maximumY = Math.max(...ys);
  const padding = 52;
  const scale = Math.min(
    (width - padding * 2) / Math.max(1, maximumX - minimumX),
    (height - padding * 2) / Math.max(1, maximumY - minimumY),
  );
  const contentWidth = (maximumX - minimumX) * scale;
  const contentHeight = (maximumY - minimumY) * scale;
  const offsetX = (width - contentWidth) / 2;
  const offsetY = (height - contentHeight) / 2;
  return (point: Vec2): Vec2 => [
    offsetX + (point[0] - minimumX) * scale,
    offsetY + (point[1] - minimumY) * scale,
  ];
}

function drawTerrain(region: RegionState, project: Projection): void {
  for (const area of region.terrainAreas) {
    context.save();
    context.beginPath();
    if (area.shape === "polygon") {
      tracePolygon(area.polygon, project);
    } else if (area.shape === "ellipse") {
      const center = project(area.center);
      const radiusPoint = project([area.center[0] + area.radius[0], area.center[1] + area.radius[1]]);
      context.ellipse(
        center[0],
        center[1],
        Math.abs(radiusPoint[0] - center[0]),
        Math.abs(radiusPoint[1] - center[1]),
        0,
        0,
        Math.PI * 2,
      );
    }
    context.fillStyle = terrainColor(area.kind);
    context.strokeStyle = "rgba(86, 70, 45, 0.38)";
    context.lineWidth = 1;
    context.fill();
    context.stroke();
    context.restore();
  }
}

function drawEdges(region: RegionState, project: Projection): void {
  for (const edge of region.edges) {
    const origin = region.nodes.find((node) => node.id === edge.originNodeId);
    const target = region.nodes.find((node) => node.id === edge.targetNodeId);
    if (origin === undefined || target === undefined) continue;
    const points = [origin.position, ...edge.routeWaypoints.map((waypoint) => waypoint.position), target.position];
    context.save();
    context.beginPath();
    traceLine(points, project);
    context.strokeStyle = edge.kind.includes("river") ? "#66848b" : "#7d6243";
    context.lineWidth = edge.kind.includes("major") ? 3 : 2;
    context.lineCap = "round";
    context.lineJoin = "round";
    context.stroke();
    for (const waypoint of edge.routeWaypoints) {
      const point = project(waypoint.position);
      context.beginPath();
      context.arc(point[0], point[1], 2.4, 0, Math.PI * 2);
      context.fillStyle = "#a68d67";
      context.fill();
    }
    context.restore();
  }
}

function drawLandmarks(region: RegionState, project: Projection): void {
  context.save();
  context.font = "600 11px Inter, system-ui, sans-serif";
  context.fillStyle = "#75603f";
  for (const landmark of region.landmarks) {
    const point = project(landmark.position);
    context.beginPath();
    context.moveTo(point[0], point[1] - 7);
    context.lineTo(point[0] + 6, point[1] + 5);
    context.lineTo(point[0] - 6, point[1] + 5);
    context.closePath();
    context.fillStyle = landmark.visibilityClass === "major" ? "#7d4d32" : "#8f7651";
    context.fill();
    context.fillStyle = "#6c5b43";
    context.fillText(landmark.displayName, point[0] + 9, point[1] + 4);
  }
  context.restore();
}

function drawNodes(region: RegionState, project: Projection): void {
  context.save();
  context.font = "700 12px Inter, system-ui, sans-serif";
  for (const node of region.nodes) {
    const point = project(node.position);
    const radius = node.kind.includes("major") ? 7 : 5;
    context.beginPath();
    context.arc(point[0], point[1], radius + 3, 0, Math.PI * 2);
    context.fillStyle = "rgba(242, 228, 191, 0.9)";
    context.fill();
    context.beginPath();
    context.arc(point[0], point[1], radius, 0, Math.PI * 2);
    context.fillStyle = "#332a20";
    context.fill();
    context.fillStyle = "#332a20";
    context.fillText(node.displayName, point[0] + 10, point[1] - 8);
  }
  context.restore();
}

function drawParty(party: PartyState, project: Projection): void {
  const point = project(party.position);
  context.save();
  context.shadowColor = "rgba(112, 42, 24, 0.35)";
  context.shadowBlur = 14;
  context.beginPath();
  context.arc(point[0], point[1], 11, 0, Math.PI * 2);
  context.fillStyle = "#f0b44c";
  context.fill();
  context.shadowBlur = 0;
  context.beginPath();
  context.moveTo(point[0], point[1] - 7);
  context.lineTo(point[0] + 7, point[1] + 6);
  context.lineTo(point[0] - 7, point[1] + 6);
  context.closePath();
  context.fillStyle = "#4b241b";
  context.fill();
  context.restore();
}

function tracePolygon(points: readonly Vec2[], project: Projection): void {
  traceLine(points, project);
  context.closePath();
}

function traceLine(points: readonly Vec2[], project: Projection): void {
  points.forEach((point, index) => {
    const projected = project(point);
    if (index === 0) context.moveTo(projected[0], projected[1]);
    else context.lineTo(projected[0], projected[1]);
  });
}

function terrainColor(kind: string): string {
  if (kind.includes("forest")) return "rgba(86, 106, 71, 0.22)";
  if (kind.includes("river") || kind.includes("valley")) return "rgba(92, 132, 139, 0.18)";
  if (kind.includes("hill") || kind.includes("mount")) return "rgba(142, 105, 72, 0.18)";
  return "rgba(126, 112, 78, 0.12)";
}

async function requestJson<T>(url: string): Promise<T> {
  const response = await fetch(url, { headers: { accept: "application/json" } });
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
  return await response.json() as T;
}

function viewUrl(path: string): string {
  const parameters = new URLSearchParams({
    view_mode: mapMode.value,
    party_id: "player_party",
  });
  return `${path}?${parameters.toString()}`;
}

async function postJson<T>(url: string, body: unknown): Promise<T> {
  const response = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
  return await response.json() as T;
}

function showMessage(message: string, isError: boolean): void {
  commandResult.textContent = message;
  commandResult.classList.toggle("error", isError);
}

function showError(error: unknown): void {
  const detail = error instanceof Error ? error.message : String(error);
  showMessage(`${translate("requestFailed")} ${detail}`, true);
}

function requireElement<T extends HTMLElement>(id: string): T {
  const element = document.getElementById(id);
  if (element === null) throw new Error(`Missing required element #${id}.`);
  return element as T;
}

function requireCanvasContext(element: HTMLCanvasElement): CanvasRenderingContext2D {
  const canvasContext = element.getContext("2d");
  if (canvasContext === null) throw new Error("Canvas 2D context is unavailable.");
  return canvasContext;
}
