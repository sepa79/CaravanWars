# Server-Authoritative Model

## Rule

The authoritative simulation owns world state. Clients, AI agents, city controllers, patrol controllers, and caravan controllers submit commands. The simulation validates commands, advances time, and emits state updates.

Singleplayer uses the same model with a local server and local client.

## Controlled Actors

The command layer must support:
- player caravan or company,
- bandit band,
- city authority,
- city market,
- patrol,
- courier,
- AI merchant caravan,
- future human-controlled city or faction role.

## Command Shape

Commands should be explicit intent, not direct mutation.

Examples:
- `move_party`
- `enter_city`
- `buy_goods`
- `sell_goods`
- `hire_guard`
- `inspect_rumors`
- `dispatch_patrol`
- `post_contract`
- `attack_group`
- `negotiate_passage`

## Simulation State

The server owns:
- region graph state,
- parties, their composition, positions, and travel state,
- city inventories and prices,
- patrol routes and orders,
- known information per actor,
- time and event queue,
- travel progress,
- combat or encounter outcomes.

## Client State

The client receives only what the controlled actor can know:
- known routes,
- visible landmarks,
- remembered places,
- current city facts,
- rumors and timestamps,
- partial or stale market data.

## Design Consequence

Do not implement a special singleplayer-only gameplay API. If a local player can do something, an AI agent or remote player should eventually be able to issue the same command through the same interface.
