# Merchant memory AI v0

## Purpose

`Merchant memory AI v0` is the first merchant decision slice that follows the AI memory boundary.

It chooses food delivery actions from the merchant party's WorldMemory entries, not by scanning authoritative global location state.

## Owner / consumers

- Manager: `game/simulation/managers/MerchantMemoryAI.gd`
- Test: `game/tests/MerchantMemoryAITest.gd`
- Inputs: owner memory entries fetched by an orchestrator from WorldMemory.
- Commands submitted:
  - `TransferGoodsCommand`
  - `TravelIntentCommand`

## Inputs

`process(server, party_id, memory_entries)` receives:

- the authoritative server for command submission and validation,
- the merchant party id,
- memory entries owned by that merchant party.

The AI may inspect its own party state:

- current node,
- idle/travel state,
- cargo,
- cargo capacity.

It must not scan all locations or parties in `server.state` as knowledge.

## Memory used

V0 recognizes:

- `need_ledger` with `goods_id = food`, `location_id`, `node_id`, and `needed_amount`;
- `location_observation` with `node_id`, `observed_location_id`, and `observed_resources.food`.

## Behavior

If the merchant carries food:

- if it is at the remembered need node, deposit to the remembered need location;
- otherwise travel to the remembered need node.

If the merchant carries no food:

- find a remembered local food source at the current node;
- withdraw a bounded amount through `TransferGoodsCommand`;
- travel to the remembered need node through `TravelIntentCommand`.

If required memory is missing, do nothing with an explicit reason.

## LLM planning hook

Future LLM-assisted merchant decisions may rank opportunities, estimate risk, or choose negotiation intent from the same owner memory entries. The LLM still returns a proposal; command validation and physical state mutation stay in the authoritative simulation.

## Active TypeScript implementation

`packages/world-sim/src/merchant-memory-ai.ts` implements the food loop. Each
processing step submits at most one normal command: withdraw, travel, or
deposit. It filters entries by `ownerId`, may inspect only its own party
snapshot, and never receives the global location snapshot. Missing or foreign
memory returns an explicit no-action reason; stale observations may produce a
normal rejected command and are not repaired from hidden truth.
