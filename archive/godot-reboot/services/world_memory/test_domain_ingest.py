from __future__ import annotations

import os
import sys
import tempfile
import unittest
from pathlib import Path


SERVICE_DIR = Path(__file__).resolve().parent
if str(SERVICE_DIR) not in sys.path:
    sys.path.insert(0, str(SERVICE_DIR))


class DomainIngestTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        os.environ["WORLD_MEMORY_DB_PATH"] = os.path.join(self.temp_dir.name, "world_memory.sqlite3")

        from cw_memory.db import init_db

        init_db()

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_goods_transfer_creates_per_entity_memory(self) -> None:
        from cw_memory.repository import ingest_domain_event, list_memory_entries, search_memory
        from cw_memory.schemas import DomainEventIn, WorldEventIn

        result = ingest_domain_event(
            DomainEventIn(
                world_event=WorldEventIn(
                    id="evt_transfer_001",
                    event_type="goods_transferred",
                    text="goods_transferred",
                    location_id="opole_stronghold",
                    occurred_at="day:1.000",
                    importance=0.7,
                    reliability=1.0,
                    tags=["simulation", "goods_transferred", "food", "opole_stronghold", "merchant_party_01"],
                    metadata={
                        "party_id": "merchant_party_01",
                        "location_id": "opole_stronghold",
                        "goods_id": "food",
                        "amount": 10,
                        "direction": "withdraw_from_location",
                    },
                )
            )
        )

        self.assertEqual(result["world_event"]["id"], "evt_transfer_001")
        self.assertEqual(len(result["memory_entries"]), 2)

        merchant_memory = list_memory_entries("merchant_party_01", limit=10)
        opole_memory = list_memory_entries("opole_stronghold", limit=10)

        self.assertEqual(len(merchant_memory), 1)
        self.assertEqual(len(opole_memory), 1)
        self.assertEqual(merchant_memory[0]["owner_kind"], "party")
        self.assertEqual(opole_memory[0]["owner_kind"], "location")
        self.assertEqual(merchant_memory[0]["source_event_id"], "evt_transfer_001")
        self.assertEqual(opole_memory[0]["source_event_id"], "evt_transfer_001")
        self.assertEqual(merchant_memory[0]["metadata"]["owner_goods_delta"], 10)
        self.assertEqual(opole_memory[0]["metadata"]["owner_goods_delta"], -10)

        search_results = search_memory("merchant_party_01", "food", limit=5)
        self.assertEqual(len(search_results), 1)
        self.assertEqual(search_results[0]["id"], merchant_memory[0]["id"])

    def test_deposit_transfer_reverses_owner_deltas(self) -> None:
        from cw_memory.repository import ingest_domain_event, list_memory_entries
        from cw_memory.schemas import DomainEventIn, WorldEventIn

        ingest_domain_event(
            DomainEventIn(
                world_event=WorldEventIn(
                    id="evt_transfer_002",
                    event_type="goods_transferred",
                    text="goods_transferred",
                    location_id="wroclaw_city",
                    occurred_at="day:3.000",
                    tags=["simulation", "goods_transferred", "food", "wroclaw_city", "merchant_party_01"],
                    metadata={
                        "party_id": "merchant_party_01",
                        "location_id": "wroclaw_city",
                        "goods_id": "food",
                        "amount": 10,
                        "direction": "deposit_to_location",
                    },
                )
            )
        )

        merchant_memory = list_memory_entries("merchant_party_01", limit=10)
        wroclaw_memory = list_memory_entries("wroclaw_city", limit=10)

        self.assertEqual(merchant_memory[0]["metadata"]["owner_goods_delta"], -10)
        self.assertEqual(wroclaw_memory[0]["metadata"]["owner_goods_delta"], 10)

    def test_location_need_creates_location_memory(self) -> None:
        from cw_memory.repository import ingest_domain_event, list_memory_entries
        from cw_memory.schemas import DomainEventIn, WorldEventIn

        ingest_domain_event(
            DomainEventIn(
                world_event=WorldEventIn(
                    id="evt_need_001",
                    event_type="location_need_declared",
                    text="Location Wroclaw needs food.",
                    location_id="wroclaw_city",
                    occurred_at="day:2.000",
                    importance=0.7,
                    reliability=1.0,
                    tags=["simulation", "location_need_declared", "wroclaw_city", "food"],
                    metadata={
                        "location_id": "wroclaw_city",
                        "manager_actor_id": "mayor_wroclaw",
                        "goods_id": "food",
                        "current_amount": 5,
                        "desired_amount": 80,
                        "needed_amount": 75,
                        "reason": "food_below_floor",
                    },
                )
            )
        )

        wroclaw_memory = list_memory_entries("wroclaw_city", limit=10)

        self.assertEqual(len(wroclaw_memory), 1)
        self.assertEqual(wroclaw_memory[0]["kind"], "need_ledger")
        self.assertEqual(wroclaw_memory[0]["source_event_id"], "evt_need_001")
        self.assertEqual(wroclaw_memory[0]["metadata"]["needed_amount"], 75)

    def test_mayor_supply_intent_creates_mayor_and_location_memory(self) -> None:
        from cw_memory.repository import ingest_domain_event, list_memory_entries
        from cw_memory.schemas import DomainEventIn, WorldEventIn

        result = ingest_domain_event(
            DomainEventIn(
                world_event=WorldEventIn(
                    id="evt_supply_intent_001",
                    event_type="mayor_supply_intent_declared",
                    text="Mayor declared supply intent.",
                    location_id="wroclaw_city",
                    occurred_at="day:2.500",
                    importance=0.6,
                    reliability=1.0,
                    tags=["simulation", "mayor_supply_intent_declared", "wroclaw_supply_party_01", "wroclaw_city", "food"],
                    metadata={
                        "party_id": "wroclaw_supply_party_01",
                        "location_id": "wroclaw_city",
                        "issued_by_actor_id": "mayor_wroclaw",
                        "manager_actor_id": "mayor_wroclaw",
                        "supply_party_id": "wroclaw_supply_party_01",
                        "supply_party_manager_actor_id": "quartermaster_wroclaw",
                        "goods_id": "food",
                        "amount": 40,
                        "status": "active",
                        "reason": "food_below_floor",
                        "occurred_day": 2.5,
                    },
                )
            )
        )

        self.assertEqual(len(result["memory_entries"]), 2)

        mayor_memory = list_memory_entries("mayor_wroclaw", limit=10)
        city_memory = list_memory_entries("wroclaw_city", limit=10)

        self.assertEqual(mayor_memory[0]["kind"], "mayor_supply_intent")
        self.assertEqual(city_memory[0]["kind"], "mayor_supply_intent")
        self.assertEqual(mayor_memory[0]["metadata"]["perspective"], "intent_owner")
        self.assertEqual(city_memory[0]["metadata"]["perspective"], "location")
        self.assertEqual(mayor_memory[0]["metadata"]["supply_party_id"], "wroclaw_supply_party_01")
        self.assertEqual(mayor_memory[0]["metadata"]["goods_id"], "food")
        self.assertEqual(mayor_memory[0]["metadata"]["status"], "active")

    def test_worldsim_observation_creates_owner_memory(self) -> None:
        from cw_memory.repository import ingest_domain_event, list_memory_entries
        from cw_memory.schemas import DomainEventIn, WorldEventIn

        ingest_domain_event(
            DomainEventIn(
                world_event=WorldEventIn(
                    id="evt_observation_001",
                    event_type="worldsim_location_observed",
                    text="Party observed Wroclaw.",
                    location_id="wroclaw",
                    occurred_at="day:1.000",
                    importance=0.5,
                    reliability=1.0,
                    tags=["simulation", "worldsim_location_observed", "player_party", "wroclaw_city"],
                    metadata={
                        "owner_id": "player_party",
                        "owner_kind": "party",
                        "observer_party_id": "player_party",
                        "node_id": "wroclaw",
                        "observed_location_id": "wroclaw_city",
                        "observed_resources": {"food": 120},
                        "observation_score": 4,
                    },
                )
            )
        )

        player_memory = list_memory_entries("player_party", limit=10)

        self.assertEqual(len(player_memory), 1)
        self.assertEqual(player_memory[0]["kind"], "location_observation")
        self.assertEqual(player_memory[0]["metadata"]["source"], "worldsim_observation")
        self.assertEqual(player_memory[0]["metadata"]["observed_location_id"], "wroclaw_city")

    def test_worldsim_route_waypoint_observation_creates_route_memory(self) -> None:
        from cw_memory.repository import ingest_domain_event, list_memory_entries
        from cw_memory.schemas import DomainEventIn, WorldEventIn

        ingest_domain_event(
            DomainEventIn(
                world_event=WorldEventIn(
                    id="evt_route_observation_001",
                    event_type="worldsim_route_waypoint_observed",
                    text="Party observed route waypoint old_willow_ford.",
                    location_id="opole",
                    occurred_at="day:1.000",
                    importance=0.5,
                    reliability=1.0,
                    tags=["simulation", "worldsim_route_waypoint_observed", "player_party", "opole"],
                    metadata={
                        "owner_id": "player_party",
                        "owner_kind": "party",
                        "observer_party_id": "player_party",
                        "edge_id": "wroclaw_opole",
                        "from_node_id": "wroclaw",
                        "to_node_id": "opole",
                        "waypoint_id": "wroclaw_opole_old_willow_ford",
                        "waypoint_kind": "ford",
                        "terrain_area_ids": ["odra_valley"],
                        "landmark_ids": ["old_willow_ford"],
                        "landmark_tags": ["odra", "ford", "crossing"],
                        "observation_score": 4,
                    },
                )
            )
        )

        player_memory = list_memory_entries("player_party", limit=10)

        self.assertEqual(len(player_memory), 1)
        self.assertEqual(player_memory[0]["kind"], "route_observation")
        self.assertEqual(player_memory[0]["metadata"]["source"], "worldsim_observation")
        self.assertEqual(player_memory[0]["metadata"]["waypoint_id"], "wroclaw_opole_old_willow_ford")
        self.assertEqual(player_memory[0]["metadata"]["terrain_area_ids"], ["odra_valley"])

    def test_party_order_assigned_creates_order_ledgers(self) -> None:
        from cw_memory.repository import ingest_domain_event, list_memory_entries
        from cw_memory.schemas import DomainEventIn, WorldEventIn

        result = ingest_domain_event(
            DomainEventIn(
                world_event=WorldEventIn(
                    id="evt_order_001",
                    event_type="party_order_assigned",
                    text="Supply party received procure_goods order.",
                    location_id="wroclaw_city",
                    occurred_at="day:4.000",
                    importance=0.6,
                    reliability=1.0,
                    tags=["simulation", "party_order_assigned", "wroclaw_supply_party_01", "wroclaw_city", "food"],
                    metadata={
                        "party_id": "wroclaw_supply_party_01",
                        "manager_actor_id": "quartermaster_wroclaw",
                        "issued_by_actor_id": "mayor_wroclaw",
                        "order_type": "procure_goods",
                        "target_location_id": "wroclaw_city",
                        "goods_id": "food",
                        "amount": 40,
                    },
                )
            )
        )

        self.assertEqual(len(result["memory_entries"]), 4)

        supply_memory = list_memory_entries("wroclaw_supply_party_01", limit=10)
        mayor_memory = list_memory_entries("mayor_wroclaw", limit=10)
        quartermaster_memory = list_memory_entries("quartermaster_wroclaw", limit=10)
        city_memory = list_memory_entries("wroclaw_city", limit=10)

        self.assertEqual(supply_memory[0]["kind"], "order_ledger")
        self.assertEqual(supply_memory[0]["owner_kind"], "party")
        self.assertEqual(supply_memory[0]["metadata"]["perspective"], "order_recipient")
        self.assertEqual(mayor_memory[0]["metadata"]["perspective"], "order_issuer")
        self.assertEqual(quartermaster_memory[0]["metadata"]["perspective"], "order_manager")
        self.assertEqual(city_memory[0]["metadata"]["perspective"], "order_target_location")
        self.assertEqual(supply_memory[0]["metadata"]["order_type"], "procure_goods")
        self.assertEqual(supply_memory[0]["metadata"]["amount"], 40)
        self.assertEqual(supply_memory[0]["metadata"]["status"], "active")

    def test_party_order_completed_creates_completed_order_ledgers(self) -> None:
        from cw_memory.repository import ingest_domain_event, list_memory_entries
        from cw_memory.schemas import DomainEventIn, WorldEventIn

        result = ingest_domain_event(
            DomainEventIn(
                world_event=WorldEventIn(
                    id="evt_order_completed_001",
                    event_type="party_order_completed",
                    text="Supply party completed procure_goods order.",
                    location_id="wroclaw_city",
                    occurred_at="day:8.000",
                    importance=0.6,
                    reliability=1.0,
                    tags=["simulation", "party_order_completed", "wroclaw_supply_party_01", "wroclaw_city", "food"],
                    metadata={
                        "party_id": "wroclaw_supply_party_01",
                        "manager_actor_id": "quartermaster_wroclaw",
                        "issued_by_actor_id": "mayor_wroclaw",
                        "order_type": "procure_goods",
                        "target_location_id": "wroclaw_city",
                        "goods_id": "food",
                        "amount": 40,
                        "delivered_amount": 40,
                        "status": "completed",
                    },
                )
            )
        )

        self.assertEqual(len(result["memory_entries"]), 4)

        mayor_memory = list_memory_entries("mayor_wroclaw", limit=10)
        city_memory = list_memory_entries("wroclaw_city", limit=10)

        self.assertEqual(mayor_memory[0]["kind"], "order_ledger")
        self.assertEqual(mayor_memory[0]["metadata"]["status"], "completed")
        self.assertEqual(mayor_memory[0]["metadata"]["delivered_amount"], 40)
        self.assertEqual(city_memory[0]["metadata"]["status"], "completed")

    def test_party_order_cancelled_creates_cancelled_order_ledgers(self) -> None:
        from cw_memory.repository import ingest_domain_event, list_memory_entries
        from cw_memory.schemas import DomainEventIn, WorldEventIn

        result = ingest_domain_event(
            DomainEventIn(
                world_event=WorldEventIn(
                    id="evt_order_cancelled_001",
                    event_type="party_order_cancelled",
                    text="Supply party order was cancelled.",
                    location_id="wroclaw_city",
                    occurred_at="day:6.000",
                    importance=0.6,
                    reliability=1.0,
                    tags=["simulation", "party_order_cancelled", "wroclaw_supply_party_01", "wroclaw_city", "food"],
                    metadata={
                        "party_id": "wroclaw_supply_party_01",
                        "manager_actor_id": "quartermaster_wroclaw",
                        "issued_by_actor_id": "mayor_wroclaw",
                        "order_type": "procure_goods",
                        "target_location_id": "wroclaw_city",
                        "goods_id": "food",
                        "amount": 40,
                        "status": "cancelled",
                        "cancel_reason": "city_stock_recovered",
                    },
                )
            )
        )

        self.assertEqual(len(result["memory_entries"]), 4)

        mayor_memory = list_memory_entries("mayor_wroclaw", limit=10)
        supply_memory = list_memory_entries("wroclaw_supply_party_01", limit=10)

        self.assertEqual(mayor_memory[0]["kind"], "order_ledger")
        self.assertEqual(mayor_memory[0]["metadata"]["status"], "cancelled")
        self.assertEqual(supply_memory[0]["metadata"]["cancel_reason"], "city_stock_recovered")

    def test_party_order_interrupted_creates_interrupted_order_ledgers(self) -> None:
        from cw_memory.repository import ingest_domain_event, list_memory_entries
        from cw_memory.schemas import DomainEventIn, WorldEventIn

        result = ingest_domain_event(
            DomainEventIn(
                world_event=WorldEventIn(
                    id="evt_order_interrupted_001",
                    event_type="party_order_interrupted",
                    text="Merchant party order was interrupted.",
                    location_id="raciborz",
                    occurred_at="day:6.000",
                    importance=0.7,
                    reliability=1.0,
                    tags=["simulation", "party_order_interrupted", "merchant_party_01", "raciborz"],
                    metadata={
                        "party_id": "merchant_party_01",
                        "manager_actor_id": "merchant_miroslaw",
                        "issued_by_actor_id": "merchant_miroslaw",
                        "order_type": "travel_to",
                        "target_node_id": "raciborz",
                        "status": "interrupted",
                        "interrupt_reason": "ambush_spotted",
                    },
                )
            )
        )

        self.assertEqual(len(result["memory_entries"]), 2)

        merchant_memory = list_memory_entries("merchant_party_01", limit=10)

        self.assertEqual(merchant_memory[0]["kind"], "order_ledger")
        self.assertEqual(merchant_memory[0]["metadata"]["status"], "interrupted")
        self.assertEqual(merchant_memory[0]["metadata"]["interrupt_reason"], "ambush_spotted")

    def test_party_travel_interrupted_creates_travel_ledger(self) -> None:
        from cw_memory.repository import ingest_domain_event, list_memory_entries
        from cw_memory.schemas import DomainEventIn, WorldEventIn

        result = ingest_domain_event(
            DomainEventIn(
                world_event=WorldEventIn(
                    id="evt_travel_interrupted_001",
                    event_type="party_travel_interrupted",
                    text="Merchant party travel was interrupted.",
                    location_id="raciborz",
                    occurred_at="day:6.000",
                    importance=0.7,
                    reliability=1.0,
                    tags=["simulation", "party_travel_interrupted", "merchant_party_01", "raciborz"],
                    metadata={
                        "party_id": "merchant_party_01",
                        "manager_actor_id": "merchant_miroslaw",
                        "issued_by_actor_id": "merchant_miroslaw",
                        "travel_state": "interrupted",
                        "from_node_id": "wroclaw",
                        "to_node_id": "raciborz",
                        "progress_km": 12.5,
                        "distance_km": 80.0,
                        "reason": "ambush_spotted",
                    },
                )
            )
        )

        self.assertEqual(len(result["memory_entries"]), 1)

        merchant_memory = list_memory_entries("merchant_party_01", limit=10)

        self.assertEqual(merchant_memory[0]["kind"], "travel_ledger")
        self.assertEqual(merchant_memory[0]["metadata"]["travel_state"], "interrupted")
        self.assertEqual(merchant_memory[0]["metadata"]["progress_km"], 12.5)

    def test_local_information_creates_party_memory(self) -> None:
        from cw_memory.repository import ingest_domain_event, list_memory_entries
        from cw_memory.schemas import DomainEventIn, WorldEventIn

        ingest_domain_event(
            DomainEventIn(
                world_event=WorldEventIn(
                    id="evt_local_info_001",
                    event_type="worldsim_local_information_received",
                    text="Supply party asked about food.",
                    location_id="wroclaw_city",
                    occurred_at="day:5.000",
                    importance=0.5,
                    reliability=1.0,
                    tags=["simulation", "worldsim_local_information_received", "wroclaw_supply_party_01", "food"],
                    metadata={
                        "party_id": "wroclaw_supply_party_01",
                        "location_id": "wroclaw_city",
                        "query_type": "goods_source",
                        "goods_id": "food",
                        "known_source_locations": [
                            {
                                "location_id": "opole_stronghold",
                                "node_id": "opole",
                                "goods_id": "food",
                                "observed_amount": 90,
                            }
                        ],
                    },
                )
            )
        )

        supply_memory = list_memory_entries("wroclaw_supply_party_01", limit=10)

        self.assertEqual(len(supply_memory), 1)
        self.assertEqual(supply_memory[0]["kind"], "local_information")
        self.assertEqual(supply_memory[0]["metadata"]["source"], "worldsim_local_information")
        self.assertEqual(supply_memory[0]["metadata"]["known_source_locations"][0]["location_id"], "opole_stronghold")

    def test_report_back_transfers_supply_memory_to_mayor(self) -> None:
        from cw_memory.repository import ingest_domain_event, list_memory_entries, transfer_memory
        from cw_memory.schemas import DomainEventIn, MemoryTransferIn, WorldEventIn

        ingest_domain_event(
            DomainEventIn(
                world_event=WorldEventIn(
                    id="evt_local_info_report_001",
                    event_type="worldsim_local_information_received",
                    text="Supply party asked about food.",
                    location_id="wroclaw_city",
                    occurred_at="day:6.000",
                    importance=0.5,
                    reliability=1.0,
                    tags=["simulation", "worldsim_local_information_received", "wroclaw_supply_party_01", "food"],
                    metadata={
                        "party_id": "wroclaw_supply_party_01",
                        "location_id": "wroclaw_city",
                        "query_type": "goods_source",
                        "goods_id": "food",
                        "known_source_locations": [
                            {
                                "location_id": "opole_stronghold",
                                "node_id": "opole",
                                "goods_id": "food",
                                "observed_amount": 90,
                            }
                        ],
                    },
                )
            )
        )

        transfer_result = transfer_memory(
            MemoryTransferIn(
                from_owner_id="wroclaw_supply_party_01",
                to_owner_id="mayor_wroclaw",
                to_owner_kind="actor",
                location_id="wroclaw_city",
                occurred_at="day:6.250",
                max_entries=3,
                trust=0.9,
                listener_interest_tags=["food", "wroclaw_city"],
                distortion_noise=0.02,
                notes="Supply party report back",
            )
        )

        mayor_memory = list_memory_entries("mayor_wroclaw", limit=10)

        self.assertEqual(len(transfer_result["created_entries"]), 1)
        self.assertEqual(len(mayor_memory), 1)
        self.assertEqual(mayor_memory[0]["source_owner_id"], "wroclaw_supply_party_01")
        self.assertEqual(mayor_memory[0]["metadata"]["query_type"], "goods_source")
        self.assertEqual(mayor_memory[0]["metadata"]["transfer_notes"], "Supply party report back")

    def test_worldsim_memory_reported_transfers_party_memory(self) -> None:
        from cw_memory.repository import ingest_domain_event, list_memory_entries
        from cw_memory.schemas import DomainEventIn, WorldEventIn

        ingest_domain_event(
            DomainEventIn(
                world_event=WorldEventIn(
                    id="evt_local_info_report_event_001",
                    event_type="worldsim_local_information_received",
                    text="Supply party asked about food.",
                    location_id="wroclaw_city",
                    occurred_at="day:7.000",
                    importance=0.5,
                    reliability=1.0,
                    tags=["simulation", "worldsim_local_information_received", "wroclaw_supply_party_01", "food"],
                    metadata={
                        "party_id": "wroclaw_supply_party_01",
                        "actor_id": "quartermaster_wroclaw",
                        "location_id": "wroclaw_city",
                        "query_type": "goods_source",
                        "goods_id": "food",
                        "known_source_locations": [
                            {
                                "location_id": "opole_stronghold",
                                "node_id": "opole",
                                "goods_id": "food",
                                "observed_amount": 90,
                            }
                        ],
                    },
                )
            )
        )

        result = ingest_domain_event(
            DomainEventIn(
                world_event=WorldEventIn(
                    id="evt_memory_reported_001",
                    event_type="worldsim_memory_reported",
                    text="Quartermaster reported memory to mayor.",
                    location_id="wroclaw_city",
                    occurred_at="day:7.100",
                    importance=0.5,
                    reliability=1.0,
                    tags=["simulation", "worldsim_memory_reported", "wroclaw_supply_party_01", "mayor_wroclaw", "food"],
                    metadata={
                        "party_id": "wroclaw_supply_party_01",
                        "actor_id": "quartermaster_wroclaw",
                        "from_owner_id": "wroclaw_supply_party_01",
                        "from_owner_kind": "party",
                        "to_owner_id": "mayor_wroclaw",
                        "to_owner_kind": "actor",
                        "recipient_actor_id": "mayor_wroclaw",
                        "location_id": "wroclaw_city",
                        "max_entries": 3,
                        "trust": 0.9,
                        "distortion_noise": 0.02,
                        "listener_interest_tags": ["food", "wroclaw_city"],
                        "notes": "Supply party report back",
                    },
                )
            )
        )

        mayor_memory = list_memory_entries("mayor_wroclaw", limit=10)

        self.assertEqual(len(result["memory_entries"]), 1)
        self.assertEqual(len(mayor_memory), 1)
        self.assertEqual(mayor_memory[0]["kind"], "heard_report")
        self.assertEqual(mayor_memory[0]["source_owner_id"], "wroclaw_supply_party_01")
        self.assertEqual(mayor_memory[0]["metadata"]["delivery_kind"], "report")
        self.assertEqual(mayor_memory[0]["metadata"]["transfer_notes"], "Supply party report back")
        self.assertEqual(mayor_memory[0]["metadata"]["known_source_locations"][0]["location_id"], "opole_stronghold")


if __name__ == "__main__":
    unittest.main()
