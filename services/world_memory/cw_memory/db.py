from __future__ import annotations

import sqlite3
from pathlib import Path
from typing import Any


BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
DB_PATH = DATA_DIR / "world_memory.sqlite3"


def connect() -> sqlite3.Connection:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode = WAL")
    return conn


def row_to_dict(row: sqlite3.Row | None) -> dict[str, Any] | None:
    if row is None:
        return None
    return dict(row)


def rows_to_dicts(rows: list[sqlite3.Row]) -> list[dict[str, Any]]:
    return [dict(row) for row in rows]


def init_db() -> None:
    with connect() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS actors (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                kind TEXT NOT NULL,
                persona TEXT NOT NULL DEFAULT '',
                stats_json TEXT NOT NULL DEFAULT '{}',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS world_facts (
                id TEXT PRIMARY KEY,
                subject TEXT NOT NULL,
                predicate TEXT NOT NULL,
                object TEXT NOT NULL,
                truth_status TEXT NOT NULL DEFAULT 'true',
                reliability REAL NOT NULL DEFAULT 1.0,
                source TEXT NOT NULL DEFAULT 'simulation',
                valid_from TEXT,
                valid_to TEXT,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS actor_known_facts (
                actor_id TEXT NOT NULL REFERENCES actors(id) ON DELETE CASCADE,
                fact_id TEXT NOT NULL REFERENCES world_facts(id) ON DELETE CASCADE,
                belief_status TEXT NOT NULL DEFAULT 'believes',
                confidence REAL NOT NULL DEFAULT 0.5,
                learned_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                learned_from_actor_id TEXT REFERENCES actors(id) ON DELETE SET NULL,
                notes TEXT NOT NULL DEFAULT '',
                PRIMARY KEY (actor_id, fact_id)
            );

            CREATE TABLE IF NOT EXISTS relationships (
                actor_id TEXT NOT NULL REFERENCES actors(id) ON DELETE CASCADE,
                target_actor_id TEXT NOT NULL REFERENCES actors(id) ON DELETE CASCADE,
                trust INTEGER NOT NULL DEFAULT 0,
                fear INTEGER NOT NULL DEFAULT 0,
                respect INTEGER NOT NULL DEFAULT 0,
                notes TEXT NOT NULL DEFAULT '',
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (actor_id, target_actor_id)
            );

            CREATE TABLE IF NOT EXISTS conversations (
                id TEXT PRIMARY KEY,
                location_id TEXT NOT NULL DEFAULT '',
                started_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                ended_at TEXT,
                summary TEXT NOT NULL DEFAULT ''
            );

            CREATE TABLE IF NOT EXISTS conversation_participants (
                conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
                actor_id TEXT NOT NULL REFERENCES actors(id) ON DELETE CASCADE,
                role TEXT NOT NULL DEFAULT 'participant',
                PRIMARY KEY (conversation_id, actor_id)
            );

            CREATE TABLE IF NOT EXISTS conversation_turns (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
                speaker_actor_id TEXT NOT NULL REFERENCES actors(id) ON DELETE CASCADE,
                raw_intent TEXT NOT NULL DEFAULT '',
                rendered_line TEXT NOT NULL,
                tone TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS memory_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                actor_id TEXT REFERENCES actors(id) ON DELETE SET NULL,
                event_type TEXT NOT NULL,
                text TEXT NOT NULL,
                importance INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE VIRTUAL TABLE IF NOT EXISTS memory_search
            USING fts5(actor_id, event_type, text, content='memory_events', content_rowid='id');

            CREATE TRIGGER IF NOT EXISTS memory_events_ai AFTER INSERT ON memory_events BEGIN
                INSERT INTO memory_search(rowid, actor_id, event_type, text)
                VALUES (new.id, coalesce(new.actor_id, ''), new.event_type, new.text);
            END;

            CREATE TRIGGER IF NOT EXISTS memory_events_ad AFTER DELETE ON memory_events BEGIN
                INSERT INTO memory_search(memory_search, rowid, actor_id, event_type, text)
                VALUES ('delete', old.id, coalesce(old.actor_id, ''), old.event_type, old.text);
            END;

            CREATE TRIGGER IF NOT EXISTS memory_events_au AFTER UPDATE ON memory_events BEGIN
                INSERT INTO memory_search(memory_search, rowid, actor_id, event_type, text)
                VALUES ('delete', old.id, coalesce(old.actor_id, ''), old.event_type, old.text);
                INSERT INTO memory_search(rowid, actor_id, event_type, text)
                VALUES (new.id, coalesce(new.actor_id, ''), new.event_type, new.text);
            END;

            CREATE TABLE IF NOT EXISTS world_events (
                id TEXT PRIMARY KEY,
                event_type TEXT NOT NULL,
                text TEXT NOT NULL,
                location_id TEXT NOT NULL DEFAULT '',
                occurred_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                importance REAL NOT NULL DEFAULT 0.5,
                reliability REAL NOT NULL DEFAULT 1.0,
                tags_json TEXT NOT NULL DEFAULT '[]',
                metadata_json TEXT NOT NULL DEFAULT '{}',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS memory_entries (
                id TEXT PRIMARY KEY,
                owner_id TEXT NOT NULL,
                owner_kind TEXT NOT NULL DEFAULT 'actor',
                text TEXT NOT NULL,
                kind TEXT NOT NULL DEFAULT 'heard_rumor',
                source_owner_id TEXT,
                source_event_id TEXT REFERENCES world_events(id) ON DELETE SET NULL,
                heard_at_location_id TEXT NOT NULL DEFAULT '',
                heard_at_time TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                tags_json TEXT NOT NULL DEFAULT '[]',
                credibility REAL NOT NULL DEFAULT 0.5,
                salience REAL NOT NULL DEFAULT 0.5,
                freshness REAL NOT NULL DEFAULT 1.0,
                repeat_chance REAL NOT NULL DEFAULT 0.5,
                distortion REAL NOT NULL DEFAULT 0.0,
                hop_count INTEGER NOT NULL DEFAULT 0,
                source_chain_json TEXT NOT NULL DEFAULT '[]',
                metadata_json TEXT NOT NULL DEFAULT '{}',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE INDEX IF NOT EXISTS idx_memory_entries_owner ON memory_entries(owner_id, salience DESC);
            CREATE INDEX IF NOT EXISTS idx_memory_entries_tags ON memory_entries(tags_json);
            CREATE INDEX IF NOT EXISTS idx_world_events_time ON world_events(occurred_at DESC);

            CREATE TABLE IF NOT EXISTS memory_transfer_jobs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                from_owner_id TEXT NOT NULL,
                to_owner_id TEXT NOT NULL,
                location_id TEXT NOT NULL DEFAULT '',
                occurred_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                selected_entry_ids_json TEXT NOT NULL DEFAULT '[]',
                created_entry_ids_json TEXT NOT NULL DEFAULT '[]',
                status TEXT NOT NULL DEFAULT 'done',
                notes TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            """
        )
