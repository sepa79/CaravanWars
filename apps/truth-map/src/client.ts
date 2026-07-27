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
  readonly mapBounds: { readonly minimum: Vec2; readonly maximum: Vec2 };
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
  readonly navigationKnowledge?: {
    readonly approximateAreas: readonly { readonly knowledgeId: string; readonly center: Vec2; readonly radiusKm: number; readonly confidencePermille: number; readonly freshness: "fresh" | "stale" }[];
    readonly landmarkRelations: readonly { readonly knowledgeId: string; readonly relation: string; readonly confidencePermille: number; readonly freshness: "fresh" | "stale" }[];
  };
  readonly spatialTruth?: { readonly metrics: { readonly offRoadDistanceKm: number; readonly searchAreaCoveredKm2: number; readonly discoveries: number; readonly falseLeads: number; readonly hiddenSiteVisits: number }; readonly selectedOwnerGraph: { readonly ownerId: string; readonly nodes: readonly unknown[]; readonly edges: readonly unknown[]; readonly areas: readonly unknown[] } };
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
    readonly routeIncidents?: number;
    readonly successfulAmbushes?: number;
    readonly activeSecurityTasks?: number;
    readonly averageRouteRiskPermille?: number;
  };
  readonly recentDecisions: readonly { readonly actorId: string; readonly reason: string; readonly accepted: boolean | null }[];
  readonly calendar?: { readonly year: number; readonly dayOfYear: number; readonly season: string };
  readonly profiles?: { readonly instances: readonly { readonly profileId: string; readonly processStages: Readonly<Record<string, string>> }[] } | null;
  readonly winterReserves?: readonly { readonly hay: number; readonly seedGrain: number; readonly edibleGrain: number }[];
  readonly annualReports?: readonly { readonly year: number; readonly grossHarvest: number; readonly edibleSurplus: number; readonly spoilage: number }[];
  readonly populationDynamics?: { readonly settlements: readonly { readonly settlementId: string; readonly cohorts: { readonly children: number; readonly workingAdults: number; readonly elders: number }; readonly healthPermille: number; readonly nutritionPermille: number; readonly allocations: readonly { readonly sector: string; readonly workers: number }[] }[] } | null;
  readonly routeSecurity?: { readonly routes: readonly { readonly routeId: string; readonly riskPermille: number; readonly incidentCount: number; readonly patrolStrength: number }[]; readonly tasks: readonly { readonly taskId: string; readonly status: string }[] } | null;
}

interface ExpeditionState {
  readonly partyMap: DebugState;
  readonly party: PartyState;
  readonly expedition: null | {
    readonly characters: readonly { readonly characterId: string; readonly roles: readonly string[]; readonly healthPermille: number; readonly fatiguePermille: number; readonly condition: string }[];
    readonly contracts: readonly { readonly contractId: string; readonly status: string; readonly goodsId: string; readonly quantity: number; readonly deadlineElapsedDays: number; readonly paymentCoin: number }[];
    readonly encounter: null | { readonly encounterId: string; readonly routeId: string; readonly affordances: readonly string[] };
    readonly log: readonly { readonly logId: string; readonly elapsedDays: number; readonly text: string }[];
  };
}

const canvas = requireElement<HTMLCanvasElement>("mapCanvas");
const context = requireCanvasContext(canvas);

const partyName = requireElement<HTMLElement>("partyName");
const partyId = requireElement<HTMLElement>("partyId");
const partyStatus = requireElement<HTMLElement>("partyStatus");
const partyLocation = requireElement<HTMLElement>("partyLocation");
const partySpeed = requireElement<HTMLElement>("partySpeed");
const commandResult = requireElement<HTMLElement>("commandResult");
const mapContextMenu = requireElement<HTMLElement>("mapContextMenu");
const mapContextTitle = requireElement<HTMLElement>("mapContextTitle");
const moveToSelected = requireElement<HTMLButtonElement>("moveToSelected");
const clock = requireElement<HTMLElement>("clock");
const advanceSixHours = requireElement<HTMLButtonElement>("advanceSixHours");
const advanceDay = requireElement<HTMLButtonElement>("advanceDay");
const autoAdvance = requireElement<HTMLInputElement>("autoAdvance");
const resetButton = requireElement<HTMLButtonElement>("resetButton");
const regionName = requireElement<HTMLElement>("regionName");
const regionStats = requireElement<HTMLElement>("regionStats");
const debugMapObserver = requireElement<HTMLSelectElement>("debugMapObserver");
const mapScopeLabel = requireElement<HTMLElement>("mapScopeLabel");
const mapPanelMode = requireElement<HTMLElement>("mapPanelMode");
const mapPanelCoverage = requireElement<HTMLElement>("mapPanelCoverage");
const mapPanelPosition = requireElement<HTMLElement>("mapPanelPosition");
const mapPanelKnowledge = requireElement<HTMLElement>("mapPanelKnowledge");
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
const spatialDiagnostics = requireElement<HTMLElement>("spatialDiagnostics");
const navigationKnowledge = requireElement<HTMLElement>("navigationKnowledge");
const economyDecisions = requireElement<HTMLOListElement>("economyDecisions");
const advanceEconomy = requireElement<HTMLButtonElement>("advanceEconomy");
const expeditionContract = requireElement<HTMLElement>("expeditionContract");
const expeditionStatus = requireElement<HTMLElement>("expeditionStatus");
const expeditionCharacters = requireElement<HTMLElement>("expeditionCharacters");
const expeditionCargo = requireElement<HTMLElement>("expeditionCargo");
const expeditionDeadline = requireElement<HTMLElement>("expeditionDeadline");
const acceptContract = requireElement<HTMLButtonElement>("acceptContract");
const pickupContract = requireElement<HTMLButtonElement>("pickupContract");
const departExpedition = { disabled: false };
const exploreExpedition = requireElement<HTMLButtonElement>("exploreExpedition");
const deliverContract = requireElement<HTMLButtonElement>("deliverContract");
const encounterPanel = requireElement<HTMLDialogElement>("encounterPanel");
const encounterTitle = requireElement<HTMLElement>("encounterTitle");
const encounterSummary = requireElement<HTMLElement>("encounterSummary");
const encounterChoices = requireElement<HTMLElement>("encounterChoices");
const expeditionLog = requireElement<HTMLOListElement>("expeditionLog");
const apiStatus = requireElement<HTMLElement>("apiStatus");
const gameStageElement = document.querySelector<HTMLElement>(".game-stage");
if (gameStageElement === null) throw new Error("Missing .game-stage element.");
const gameStage: HTMLElement = gameStageElement;
const contextViews = [...document.querySelectorAll<HTMLElement>("[data-game-view]")];
const gameTabs = [...document.querySelectorAll<HTMLButtonElement>("[data-panel-target]")];
const journalPrevious = requireElement<HTMLButtonElement>("journalPrevious");
const journalNext = requireElement<HTMLButtonElement>("journalNext");
const journalPage = requireElement<HTMLElement>("journalPage");
const diagnosticPrevious = requireElement<HTMLButtonElement>("diagnosticPrevious");
const diagnosticNext = requireElement<HTMLButtonElement>("diagnosticNext");
const diagnosticPage = requireElement<HTMLElement>("diagnosticPage");
const diagnosticPages = [...document.querySelectorAll<HTMLElement>("[data-diagnostic-page]")];

let state: DebugState | null = null;
let requestInFlight = false;
let autoAdvanceTimer: number | null = null;
let expeditionState: ExpeditionState | null = null;
let expeditionCommandMessage = "";
let activeGameView = "map";
let journalPageIndex = 0;
let diagnosticPageIndex = 0;
let encounterReturnFocus: HTMLElement | null = null;
let encounterOutcome: null | { readonly decision: string; readonly outcome: string } = null;
let showingExpeditionMap = true;
let debugMapActive = false;
let lastMapRenderSignature = "";
let lastExpeditionRenderSignature = "";
let selectedMapNodeId: string | null = null;

translateDocument();
window.addEventListener("resize", render);
for (const tab of gameTabs) tab.addEventListener("click", () => { const target = tab.dataset.panelTarget; if (target !== undefined) void activateGameView(target); });
journalPrevious.addEventListener("click", () => { journalPageIndex = Math.max(0, journalPageIndex - 1); renderPlayableExpedition(); });
journalNext.addEventListener("click", () => { journalPageIndex += 1; renderPlayableExpedition(); });
diagnosticPrevious.addEventListener("click", () => { diagnosticPageIndex = Math.max(0, diagnosticPageIndex - 1); renderDiagnosticPage(); });
diagnosticNext.addEventListener("click", () => { diagnosticPageIndex = Math.min(diagnosticPages.length - 1, diagnosticPageIndex + 1); renderDiagnosticPage(); });
canvas.addEventListener("click", (event) => { selectMapNode(event); });
canvas.addEventListener("contextmenu", (event) => { event.preventDefault(); openMapContextMenu(event); });
moveToSelected.addEventListener("click", () => { mapContextMenu.hidden = true; void submitSelectedMove(); });
document.addEventListener("click", (event) => { if (!mapContextMenu.contains(event.target as Node) && event.target !== canvas) mapContextMenu.hidden = true; });
advanceSixHours.addEventListener("click", () => { void advancePlayableExpedition(0.25); });
advanceDay.addEventListener("click", () => { void advancePlayableExpedition(1); });
resetButton.addEventListener("click", () => { void resetSimulation(); });
debugMapObserver.addEventListener("change", () => { void refreshDebugMap(); });
advanceEconomy.addEventListener("click", () => { void advanceRegionalEconomy(); });
acceptContract.addEventListener("click", () => { void expeditionCommand("accept_caravan_contract", { commandId: "browser:accept", issuerActorId: "player_leader", contractId: "contract_wroclaw_opole_food", contractorPartyId: "player_expedition" }); });
pickupContract.addEventListener("click", () => { void expeditionCommand("pickup_caravan_contract", { commandId: "browser:pickup", issuerActorId: "player_leader", contractId: "contract_wroclaw_opole_food" }); });
exploreExpedition.addEventListener("click", () => { void expeditionCommand("search_area", { commandId: "browser:explore:forest-shortcut", issuerActorId: "player_leader", partyId: "player_expedition", areaKnowledgeId: "area:rumored_forest_shortcut", searchRadiusKm: 3, observationSkillPermille: 820 }); });
deliverContract.addEventListener("click", () => { void expeditionCommand("deliver_caravan_contract", { commandId: "browser:deliver", issuerActorId: "player_leader", contractId: "contract_wroclaw_opole_food" }); });
autoAdvance.addEventListener("change", updateAutoAdvance);

gameStage.dataset.activeView = activeGameView;
for (const candidate of contextViews) candidate.hidden = candidate.id !== "mapView" && candidate.dataset.gameView !== "map";
encounterPanel.addEventListener("cancel", (event) => { event.preventDefault(); });
void refreshState();
void loadDebugMapObservers();
window.setInterval(() => { void refreshState(false); }, 1_000);

async function refreshState(reportFailure = true): Promise<void> {
  try {
    const nextState = await requestJson<DebugState>(viewUrl("/api/state"));
    if (!debugMapActive) state = nextState;
    if (!showingExpeditionMap && !debugMapActive) updateView();
    await Promise.all([refreshEconomyDiagnostics(), refreshPlayableExpedition()]);
    setApiStatus("Połączono", false);
  } catch (error: unknown) {
    setApiStatus(error instanceof Error ? error.message : String(error), true);
    if (reportFailure) showError(error);
  }
}

async function refreshPlayableExpedition(): Promise<void> {
  const nextExpeditionState = await requestJson<ExpeditionState>("/api/expedition/state");
  const changed = JSON.stringify(nextExpeditionState) !== JSON.stringify(expeditionState);
  expeditionState = nextExpeditionState;
  if (showingExpeditionMap && !debugMapActive) { state = expeditionState.partyMap; updateView(); }
  if (changed) renderPlayableExpedition();
}
function renderPlayableExpedition(): void { const current = expeditionState, contract = current?.expedition?.contracts[0]; if (current === null || current.expedition === null || contract === undefined) return; expeditionContract.textContent = `${contract.quantity} ${contract.goodsId}: Wrocław → Opole`; expeditionStatus.textContent = `Status: ${contract.status}`; expeditionDeadline.textContent = `dzień ${contract.deadlineElapsedDays}, zapłata ${contract.paymentCoin} coin`; expeditionCharacters.textContent = current.expedition.characters.map((item) => `${item.characterId} [${item.roles.join("/")}] h${item.healthPermille} f${item.fatiguePermille}`).join("; "); expeditionCargo.textContent = Object.entries(current.party.cargo).map(([id, amount]) => `${id} ${amount}`).join(", ") || "puste"; acceptContract.disabled = contract.status !== "offered"; pickupContract.disabled = contract.status !== "accepted"; departExpedition.disabled = contract.status !== "picked_up" || current.party.currentNodeId !== "wroclaw"; exploreExpedition.disabled = contract.status !== "picked_up" || current.party.currentNodeId !== "wroclaw"; deliverContract.disabled = contract.status !== "picked_up" || current.party.currentNodeId !== "opole"; const encounter = current.expedition.encounter; encounterChoices.replaceChildren(); if (encounter !== null) { encounterTitle.textContent = "Karawana zatrzymana"; encounterSummary.textContent = `Zagrożenie na ${encounter.routeId}. Wybór ma fizyczne konsekwencje.`; for (const decision of encounter.affordances) { const button = document.createElement("button"); button.textContent = decision; button.dataset.decision = decision; button.addEventListener("click", () => { void expeditionCommand("resolve_expedition_encounter", { commandId: `browser:encounter:${encounter.encounterId}:${decision}`, issuerActorId: "player_leader", encounterId: encounter.encounterId, decision }); }); encounterChoices.append(button); } openEncounterDialog(); } else if (encounterOutcome !== null) { encounterTitle.textContent = encounterOutcome.decision === "fight" ? "Walka rozstrzygnięta" : "Spotkanie rozstrzygnięte"; encounterSummary.textContent = `${encounterOutcome.decision}: ${encounterOutcome.outcome}. Możesz kontynuować podróż.`; const continueButton = document.createElement("button"); continueButton.className = "primary"; continueButton.textContent = "Kontynuuj podróż (+6 godzin)"; continueButton.dataset.encounterContinue = "true"; continueButton.addEventListener("click", () => { encounterOutcome = null; void advancePlayableExpedition(0.25); }); const journalButton = document.createElement("button"); journalButton.textContent = "Zobacz dziennik"; journalButton.addEventListener("click", () => { encounterOutcome = null; encounterPanel.close(); void activateGameView("journal"); }); encounterChoices.append(continueButton, journalButton); openEncounterDialog(); } else if (encounterPanel.open) { encounterPanel.close(); encounterReturnFocus?.focus(); encounterReturnFocus = null; } const pageSize = 4, pageCount = Math.max(1, Math.ceil(current.expedition.log.length / pageSize)); journalPageIndex = Math.min(journalPageIndex, pageCount - 1); const entries = current.expedition.log.slice().reverse().slice(journalPageIndex * pageSize, (journalPageIndex + 1) * pageSize); expeditionLog.replaceChildren(...entries.map((entry) => { const item = document.createElement("li"); item.textContent = `D${entry.elapsedDays.toFixed(2)} ${entry.text}`; return item; })); journalPage.textContent = `${journalPageIndex + 1} / ${pageCount}`; journalPrevious.disabled = journalPageIndex === 0; journalNext.disabled = journalPageIndex + 1 >= pageCount; }
function openEncounterDialog(): void { if (!encounterPanel.open) { encounterReturnFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null; encounterPanel.showModal(); } requestAnimationFrame(() => encounterChoices.querySelector<HTMLButtonElement>("button")?.focus()); }
async function expeditionCommand(commandType: string, command: Record<string, unknown>): Promise<void> { try { const response = await postJson<{ readonly result: { readonly result: { readonly accepted: boolean; readonly errorCode?: string; readonly message?: string; readonly outcome?: string } }; readonly state: ExpeditionState }>("/api/expedition/command", { commandType, command }); expeditionState = response.state; const result = response.result.result; expeditionCommandMessage = result.accepted ? "Komenda przyjęta" : `${result.errorCode}: ${result.message}`; if (commandType === "resolve_expedition_encounter" && result.accepted) encounterOutcome = { decision: String(command.decision), outcome: result.outcome ?? "zakończone" }; renderPlayableExpedition(); expeditionStatus.textContent += ` — ${expeditionCommandMessage}`; } catch (error) { showError(error); } }
async function advancePlayableExpedition(days: number): Promise<void> { expeditionState = await postJson<ExpeditionState>("/api/expedition/advance", { days }); renderPlayableExpedition(); }
async function expeditionAiStep(): Promise<void> { const response = await postJson<{ readonly state: ExpeditionState }>("/api/expedition/ai-step", {}); expeditionState = response.state; renderPlayableExpedition(); }

async function refreshEconomyDiagnostics(): Promise<void> {
  const truth = activeGameView === "diagnostics" && debugMapObserver.value === "truth";
  if (!truth) return;
  const diagnostics = await requestJson<EconomyDiagnostics>("/api/economy?view_mode=truth");
  renderEconomyDiagnostics(diagnostics);
}

async function loadDebugMapObservers(): Promise<void> {
  const response = await requestJson<{ readonly observers: readonly { readonly id: string; readonly displayName: string }[] }>("/api/debug/map-observers");
  const selected = debugMapObserver.value || "truth";
  debugMapObserver.replaceChildren(...response.observers.map((observer) => new Option(observer.displayName, observer.id)));
  debugMapObserver.value = response.observers.some((observer) => observer.id === selected) ? selected : "truth";
}

async function refreshDebugMap(): Promise<void> {
  debugMapActive = true;
  showingExpeditionMap = false;
  state = await requestJson<DebugState>(`/api/debug/map?observer=${encodeURIComponent(debugMapObserver.value)}`);
  updateView();
  if (debugMapObserver.value === "truth") await refreshEconomyDiagnostics();
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
  economyTasks.textContent = `${diagnostics.metrics.activeTasks} logistics; ${diagnostics.metrics.activeSecurityTasks ?? 0} security`;
  economyDistance.textContent = `${diagnostics.metrics.transportDistanceKm.toFixed(0)} km`;
  economySeason.textContent = diagnostics.calendar === undefined ? "—" : `${diagnostics.calendar.season}, Y${diagnostics.calendar.year} D${diagnostics.calendar.dayOfYear}`;
  economyProfiles.textContent = diagnostics.profiles?.instances.map((item) => `${item.profileId}: ${Object.values(item.processStages).join("/")}`).join("; ") ?? "—";
  const reserves = diagnostics.winterReserves ?? [];
  economyReserves.textContent = `hay ${reserves.reduce((sum, item) => sum + item.hay, 0)}, seed ${reserves.reduce((sum, item) => sum + item.seedGrain, 0)}, grain ${reserves.reduce((sum, item) => sum + item.edibleGrain, 0)}`;
  economyAnnualChart.textContent = diagnostics.annualReports?.map((item) => `Y${item.year} harvest ${item.grossHarvest} surplus ${item.edibleSurplus} spoilage ${item.spoilage}`).join(" | ") || "Annual production chart: no completed year";
  const population = diagnostics.populationDynamics?.settlements ?? [];
  economyPopulation.textContent = population.map((item) => `${item.settlementId}: ${item.cohorts.children + item.cohorts.workingAdults + item.cohorts.elders} h${item.healthPermille} n${item.nutritionPermille}`).join("; ") || "—";
  economyLabour.textContent = population.flatMap((item) => item.allocations.map((allocation) => `${item.settlementId}/${allocation.sector}:${allocation.workers}`)).join("; ") || "unallocated";
  if (diagnostics.routeSecurity !== undefined && diagnostics.routeSecurity !== null) economyLabour.textContent += ` | SECURITY TRUTH: ${diagnostics.routeSecurity.routes.map((route) => `${route.routeId} risk ${route.riskPermille} incidents ${route.incidentCount} patrol ${route.patrolStrength}`).join("; ")}`;
  economyDecisions.replaceChildren(...diagnostics.recentDecisions.slice(-6).map((decision) => {
    const item = document.createElement("li");
    item.textContent = `${decision.actorId}: ${decision.reason}${decision.accepted === false ? " [rejected]" : ""}`;
    return item;
  }));
  renderDiagnosticPage();
}

async function activateGameView(view: string): Promise<void> {
  activeGameView = view;
  gameStage.dataset.activeView = view;
  const sidebarView = view;
  for (const candidate of contextViews) candidate.hidden = candidate.id !== "mapView" && candidate.dataset.gameView !== sidebarView;
  for (const tab of gameTabs) tab.setAttribute("aria-selected", String(tab.dataset.panelTarget === view));
  if (view === "diagnostics") await refreshDebugMap();
  else if (debugMapActive) {
    debugMapActive = false;
    showingExpeditionMap = true;
    if (expeditionState !== null) { state = expeditionState.partyMap; updateView(); }
  }
  const active = contextViews.find((candidate) => candidate.dataset.gameView === sidebarView);
  if (view !== "map") (active?.querySelector<HTMLElement>("button:not(:disabled),select:not(:disabled),[tabindex]") ?? document.querySelector<HTMLElement>(`[data-panel-target="${view}"]`))?.focus();
  requestAnimationFrame(render);
}
function renderDiagnosticPage(): void { for (const page of diagnosticPages) page.hidden = Number(page.dataset.diagnosticPage) !== diagnosticPageIndex; diagnosticPage.textContent = `${diagnosticPageIndex + 1} / ${diagnosticPages.length}`; diagnosticPrevious.disabled = diagnosticPageIndex === 0; diagnosticNext.disabled = diagnosticPageIndex + 1 >= diagnosticPages.length; }
function setApiStatus(message: string, error: boolean): void { apiStatus.textContent = message; apiStatus.classList.toggle("error", error); }

async function submitSelectedMove(): Promise<void> {
  const currentState = state;
  const party = currentState?.snapshot.parties[0];
  const selectedNode = currentState?.region.nodes.find((node) => node.id === selectedMapNodeId);
  if (currentState === null || currentState === undefined || party?.currentNodeId === null
    || party?.currentNodeId === undefined || selectedNode === undefined) return;

  try {
    if (party.id === "player_expedition") {
      const response = await postJson<{ readonly result: { readonly result: MovePartyResponse["result"] }; readonly state: ExpeditionState }>("/api/expedition/command", { commandType: "move_party", command: { party_id: party.id, from_node_id: party.currentNodeId, to_node_id: selectedNode.id } });
      expeditionState = response.state;
      state = response.state.partyMap;
      if (response.result.result.accepted) showMessage(translate("commandAccepted"), false);
      else showMessage(`${response.result.result.errorCode}: ${response.result.result.message}`, true);
      renderPlayableExpedition();
      updateView();
      return;
    }
    const response = await postJson<MovePartyResponse>(viewUrl("/api/commands/move-party"), {
      party_id: party.id,
      from_node_id: party.currentNodeId,
      to_node_id: selectedNode.id,
    });
    state = response.state;
    if (response.result.accepted) showMessage(translate("commandAccepted"), false);
    else showMessage(`${response.result.errorCode}: ${response.result.message}`, true);
    updateView();
  } catch (error: unknown) {
    showError(error);
  }
}

function selectMapNode(event: MouseEvent): void {
  const node = mapNodeAt(event);
  selectedMapNodeId = node?.id ?? null;
  mapContextMenu.hidden = true;
  commandResult.textContent = node === undefined ? "Nie wybrano miejsca." : `Wybrano: ${node.displayName}. Prawy przycisk otwiera dostępne działania.`;
  lastMapRenderSignature = "";
  render();
}

function openMapContextMenu(event: MouseEvent): void {
  const node = mapNodeAt(event) ?? state?.region.nodes.find((candidate) => candidate.id === selectedMapNodeId);
  if (node === undefined) { mapContextMenu.hidden = true; return; }
  selectedMapNodeId = node.id;
  const party = state?.snapshot.parties[0], adjacent = party?.currentNodeId !== null && party?.currentNodeId !== undefined && state?.region.edges.some((edge) => (edge.originNodeId === party.currentNodeId && edge.targetNodeId === node.id) || (edge.targetNodeId === party.currentNodeId && edge.originNodeId === node.id)) === true;
  moveToSelected.disabled = party?.status !== "idle" || party.currentNodeId === node.id || !adjacent || debugMapActive;
  mapContextTitle.textContent = node.displayName;
  moveToSelected.textContent = moveToSelected.disabled ? "Brak dostępnego ruchu" : `Wyrusz do ${node.displayName}`;
  mapContextMenu.style.left = `${Math.min(event.offsetX, Math.max(0, canvas.clientWidth - 190))}px`;
  mapContextMenu.style.top = `${Math.min(event.offsetY, Math.max(0, canvas.clientHeight - 90))}px`;
  mapContextMenu.hidden = false;
  lastMapRenderSignature = "";
  render();
}

function mapNodeAt(event: MouseEvent): GraphNode | undefined {
  const currentState = state;
  if (currentState === null) return undefined;
  const projection = createProjection(currentState.region, canvas.clientWidth, canvas.clientHeight);
  return currentState.region.nodes.map((node) => ({ node, point: projection(node.position) })).filter(({ point }) => Math.hypot(point[0] - event.offsetX, point[1] - event.offsetY) <= 18).sort((left, right) => left.node.id.localeCompare(right.node.id))[0]?.node;
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
    await postJson<DebugState>(viewUrl("/api/reset"), {});
    autoAdvance.checked = false;
    updateAutoAdvance();
    encounterOutcome = null;
    journalPageIndex = 0;
    expeditionState = null;
    await refreshPlayableExpedition();
    if (activeGameView === "diagnostics") await refreshDebugMap();
    showMessage(translate("resetComplete"), false);
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
    autoAdvanceTimer = window.setInterval(() => { void advancePlayableExpedition(1 / 24); }, 250);
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
  clock.textContent = formatClock(currentState.snapshot.clock.elapsedDays);
  regionName.textContent = currentState.region.displayName;
  mapScopeLabel.textContent = currentState.mode === "truth"
    ? translate("authoritativeRegion")
    : translate("knownRegion");
  regionStats.textContent = `${currentState.region.nodes.length} miejsc · ${currentState.region.edges.length} dróg · ${currentState.region.landmarks.length} landmarki`;
  const areas = currentState.navigationKnowledge?.approximateAreas ?? [];
  const relations = currentState.navigationKnowledge?.landmarkRelations ?? [];
  navigationKnowledge.textContent = currentState.mode === "party"
    ? `PRIVATE NAVIGATION — uncertain areas ${areas.length}; landmark relations ${relations.map((item) => `${item.relation} (${item.confidencePermille}‰, ${item.freshness})`).join("; ") || "none"}`
    : "TRUTH / DEBUG — hidden locations and authoritative coordinates are visible";
  mapPanelMode.textContent = currentState.mode === "truth" ? "Developerski / pełna prawda" : "Wiedza grupy";
  mapPanelCoverage.textContent = `${currentState.region.nodes.length} miejsc, ${currentState.region.edges.length} dróg`;
  mapPanelPosition.textContent = describeLocation(currentState.region, party);
  mapPanelKnowledge.textContent = currentState.mode === "truth" ? "Pokazuje pełny stan świata, również obiekty nieznane drużynie." : `Mapa prywatna: ${areas.length} obszarów niepewnych i ${relations.length} relacji z landmarkami.`;
  const spatial = currentState.spatialTruth?.metrics;
  spatialDiagnostics.textContent = spatial === undefined ? "—" : `off-road ${spatial.offRoadDistanceKm.toFixed(1)} km; searched ${spatial.searchAreaCoveredKm2.toFixed(1)} km²; discoveries ${spatial.discoveries}; false leads ${spatial.falseLeads}; hidden visits ${spatial.hiddenSiteVisits}`;
  render();
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
  const renderSignature = JSON.stringify([currentState.region, currentState.snapshot.parties, currentState.navigationKnowledge?.approximateAreas, bounds.width, bounds.height, deviceScale]);
  if (renderSignature === lastMapRenderSignature) return;
  lastMapRenderSignature = renderSignature;
  canvas.width = Math.max(1, Math.floor(bounds.width * deviceScale));
  canvas.height = Math.max(1, Math.floor(bounds.height * deviceScale));
  context.setTransform(deviceScale, 0, 0, deviceScale, 0, 0);
  context.clearRect(0, 0, bounds.width, bounds.height);

  const projection = createProjection(currentState.region, bounds.width, bounds.height);
  drawTerrain(currentState.region, projection);
  drawUncertainty(currentState.navigationKnowledge?.approximateAreas ?? [], projection);
  drawEdges(currentState.region, projection);
  drawLandmarks(currentState.region, projection);
  drawNodes(currentState.region, projection);
  for (const party of currentState.snapshot.parties) drawParty(party, projection);
}

function drawUncertainty(areas: readonly { readonly center: Vec2; readonly radiusKm: number; readonly freshness: "fresh" | "stale" }[], project: Projection): void {
  for (const area of areas) {
    const center = project(area.center), radiusPoint = project([area.center[0] + area.radiusKm / 5, area.center[1]]);
    context.save(); context.beginPath(); context.arc(center[0], center[1], Math.abs(radiusPoint[0] - center[0]), 0, Math.PI * 2);
    context.setLineDash([6, 5]); context.strokeStyle = area.freshness === "stale" ? "rgba(145,91,60,.45)" : "rgba(45,91,120,.75)"; context.fillStyle = "rgba(70,120,145,.10)"; context.fill(); context.stroke(); context.restore();
  }
}

type Projection = (point: Vec2) => Vec2;

function createProjection(region: RegionState, width: number, height: number): Projection {
  const minimumX = region.mapBounds.minimum[0];
  const minimumY = region.mapBounds.minimum[1];
  const maximumX = region.mapBounds.maximum[0];
  const maximumY = region.mapBounds.maximum[1];
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
    if (node.id === selectedMapNodeId) { context.beginPath(); context.arc(point[0], point[1], radius + 10, 0, Math.PI * 2); context.strokeStyle = "#a43d2d"; context.lineWidth = 3; context.stroke(); }
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
    view_mode: "party",
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
