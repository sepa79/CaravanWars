# Hex Battle Slice v2

Hex Battle Slice v2 is a server-authoritative tactical event isolated from
regional travel. Singleplayer sends commands through the same battle boundary
that a remote client would use. The canonical ford-defense fixture places
Aulus and four autonomous retainers against five autonomous raiders.

## Agency, authority and perception

The player directly controls only the player character's move or attack intent.
Orders target a BattleGroup for which that character is commander; group AI
interprets them. Gameplay shows qualitative condition and allied group/order
information. Enemy health, morale, orders, cohesion, assignments and hidden
actors remain truth/debug data.

## Groups and formations

A group owns a stable id, commander, ordered member ids, banner/rally anchor,
formation, axial facing, cohesion, qualitative morale, current order and
member-slot assignments. The player may command a group without becoming an
AI-controlled formation member, preserving independent personal action.

Loose, line and close shield line slots are deterministic functions of anchor,
facing, formation and stable member-id order. Traversable ideals are valid.
Blocked ideals use deterministic adjacent fallbacks; if none exists they are
blocked. Preview and allied perception expose these states.

## Orders and delivery

The vocabulary is Follow me, Rally, Advance, Hold position, Change facing,
Close formation, Loose formation, Attack target group, Ordered withdrawal and
Act at discretion. Targeted orders require prepare, preview and confirm/cancel.

Lifecycle advances on ticks:

    issued -> propagating -> received -> interpreted -> executing

Terminal outcomes are unheard, refused, impossible and completed. During
propagation at least one living member must be within the issuer's physical
voice range. Otherwise the order becomes unheard. Broken groups may refuse.

## Simultaneous intent resolution

All living actors choose from the same tick-start state. Direct player movement
uses the same reservation set. Resolution is:

1. Choose one claimant per target by direct-player move, exact slot, formation,
   cohesion, then doctrine priority; actor id breaks ties.
2. Permit moves into cells vacated by accepted moves, including following
   chains.
3. Reject swaps and other movement cycles for every participant.
4. Duplicate-target losers and blocked dependencies hold.
5. Apply accepted positions atomically, then resolve attacks.

No fallback move is silently invented after a lost reservation. Corpses and
disabled actors remain blocking occupants; formation planning marks them
blocked.

## Doctrine, UI and scenario

Unordered allies cohere/hold and react only to adjacent danger. Ordered allies
move their anchor and seek stable slots. Raiders use the same group model with
advance doctrine rather than independent homing.

LMB selects; short RMB performs safe defaults; held RMB mirrors the canonical
side panel. The Canvas draws group membership, banner, facing, assignments,
target path and valid/fallback/blocked previews while retaining movement and
attack animations. The scenario supports rally, facing/formation changes,
holding the ford, independent player movement, advance and withdrawal.

## Save and replay

Snapshot version 2 stores seed, tick, order sequence, map, actor physical state
and group/order/formation state. Loading rebuilds derived assignments and
continues deterministically. It has no regional travel dependency.
