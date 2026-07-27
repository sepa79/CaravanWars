# Hex Battle Slice v1

This slice establishes the battle simulation boundary without coupling it to the regional travel implementation.

## Player agency

The player directly controls exactly one physical character. Allies and enemies are autonomous actors. The player may issue orders only through an explicit command relationship; an order changes an AI actor's intent, never transfers direct control.

## Information boundary

The gameplay view is a projection of the player character's current perception. It contains qualitative visible condition, bearing, last observation time and known allied orders. Exact health, morale and hidden actors exist only in the simulation truth snapshot used by tests/debugging.

## Orders

Orders are grouped into stable categories: Movement, Position, Formation, Combat, Retreat/Pursuit and Command. The side panel is the canonical action surface. Context actions mirror the same affordances: LMB selects, short RMB performs a safe default action, and held RMB opens the grouped menu.

The first slice models voice delivery and command authority. Later slices may add horns, standards, messengers, language, delayed propagation, misunderstood signals, formation membership and richer morale-based compliance without changing the command boundary.

## Geometry and time

The battlefield uses axial hex coordinates. One deterministic battle tick resolves one declared player intent and one autonomous intent for each living AI actor in stable actor-id order. Terrain occupancy and adjacency are physical constraints. This is deliberately isolated from the WorldClock integration until the tactical event cadence is specified.
