import { createServer } from "node:http";
import { resolve } from "node:path";
import { createServer as createViteServer } from "vite";
import { createDemoBattle } from "../../../packages/battle-sim/src/battle-sim.js";

const root = resolve(import.meta.dirname, "..");
let battle = createDemoBattle();
const vite = await createViteServer({ root, appType: "spa", server: { middlewareMode: true, hmr: false } });
const server = createServer((request, response) => { void handle(request, response); });
async function handle(request: import("node:http").IncomingMessage, response: import("node:http").ServerResponse): Promise<void> {
  const url = new URL(request.url ?? "/", "http://localhost");
  try {
    if (request.method === "GET" && url.pathname === "/api/state") return json(response, 200, battle.playerView());
    if (request.method === "POST" && url.pathname === "/api/tick") { battle.advanceTick(); return json(response, 200, battle.playerView()); }
    if (request.method === "POST" && url.pathname === "/api/reset") { battle = createDemoBattle(); return json(response, 200, battle.playerView()); }
    if (request.method === "POST" && url.pathname === "/api/select") { const body = await bodyJson(request); battle.select(typeof body.actorId === "string" ? body.actorId : null, typeof body.groupId === "string" ? body.groupId : null); return json(response, 200, battle.playerView()); }
    if (request.method === "POST" && url.pathname === "/api/move") { const body = await bodyJson(request), target = recordHex(body.target); const result = battle.issueIndividualCommand({ kind: "individual", issuerId: "player", type: "move", targetHex: target }); return json(response, result.accepted ? 200 : 409, { result, state: battle.playerView() }); }
    if (request.method === "POST" && url.pathname === "/api/attack") { const body = await bodyJson(request); const result = battle.issueIndividualCommand({ kind: "individual", issuerId: "player", type: "attack", targetActorId: String(body.targetActorId) }); return json(response, result.accepted ? 200 : 409, { result, state: battle.playerView() }); }
    if (request.method === "POST" && url.pathname === "/api/order") { const body = await bodyJson(request); const result = battle.issueFormationCommand({ kind: "formation", issuerId: "player", targetGroupId: String(body.targetGroupId), category: String(body.category) as never, type: String(body.type) as never, targetHex: body.targetHex === null || body.targetHex === undefined ? null : recordHex(body.targetHex), targetGroupIdToAttack: typeof body.targetGroupIdToAttack === "string" ? body.targetGroupIdToAttack : null, targetFacing: Number.isSafeInteger(body.targetFacing) ? body.targetFacing as number : null }); return json(response, result.accepted ? 200 : 409, { result, state: battle.playerView() }); }
    if (request.method === "POST" && url.pathname === "/api/preview") { const body = await bodyJson(request); const preview = battle.previewFormationCommand(String(body.groupId), String(body.type) as never, body.targetHex === null || body.targetHex === undefined ? null : recordHex(body.targetHex), Number.isSafeInteger(body.targetFacing) ? body.targetFacing as number : null); return json(response, preview === null ? 404 : 200, preview ?? { error: "group_not_found" }); }
    if (request.method === "POST" && url.pathname === "/api/individual-preview") { const body = await bodyJson(request); const preview = battle.previewIndividual(String(body.actorId)); return json(response, preview === null ? 404 : 200, preview ?? { error: "actor_not_available" }); }
    if (url.pathname.startsWith("/api/")) return json(response, 404, { error: "not_found" });
    vite.middlewares(request, response, (error?: unknown) => { if (error !== undefined) json(response, 500, { error: String(error) }); });
  } catch (error) { return json(response, 400, { error: error instanceof Error ? error.message : String(error) }); }
}
server.listen(Number(process.env.PORT ?? 4175), "0.0.0.0");

function send(response: import("node:http").ServerResponse, status: number, type: string, content: string): void { response.writeHead(status, { "content-type": `${type}; charset=utf-8`, "cache-control": "no-store" }); response.end(content); }
function json(response: import("node:http").ServerResponse, status: number, content: unknown): void { send(response, status, "application/json", JSON.stringify(content)); }
async function bodyJson(request: import("node:http").IncomingMessage): Promise<Record<string, unknown>> { const chunks: Buffer[] = []; for await (const chunk of request) chunks.push(Buffer.from(chunk)); const value: unknown = JSON.parse(Buffer.concat(chunks).toString("utf8") || "{}"); if (value === null || typeof value !== "object" || Array.isArray(value)) throw new Error("JSON object required."); return value as Record<string, unknown>; }
function recordHex(value: unknown): { q: number; r: number } { if (value === null || typeof value !== "object" || Array.isArray(value)) throw new Error("Hex required."); const item = value as Record<string, unknown>; if (!Number.isSafeInteger(item.q) || !Number.isSafeInteger(item.r)) throw new Error("Hex coordinates must be integers."); return { q: item.q as number, r: item.r as number }; }
