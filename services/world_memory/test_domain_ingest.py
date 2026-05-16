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


if __name__ == "__main__":
    unittest.main()
