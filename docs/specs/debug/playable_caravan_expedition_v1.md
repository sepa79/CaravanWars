# Playable Caravan Expedition v1

Status: active.

The browser scenario is a server-owned `WorldSimulation` fixture on the Silesia graph. Its loop is contract offer, authorized acceptance, physical pickup, travel through the private Navigation Knowledge Graph, encounter decision, delivery and escrow settlement. The player panel reads an owner-filtered expedition view and journal; mutations are normal command envelopes. AI runs the identical loop without UI or extra authority.

Run `npm run dev:truth-map`, open the displayed URL, then use the **Playable Caravan Expedition** panel: accept, pick up, depart, advance time, choose an encounter response and deliver. Reset restores the deterministic fixture. The ordinary Party Map remains knowledge-filtered; the separately labelled TRUTH/DEBUG mode is the only full-truth view.

For headless verification run `npm run sim:expedition -- --years 3 --seeds 17,29,47`.
