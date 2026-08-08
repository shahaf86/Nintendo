# Nintendo Universe Lore & Timeline — database layer

Postgres 16 in Docker, schema and seed applied automatically on first boot.

## Layout

```
lore-platform/
├── docker-compose.yml
├── .env.example
├── db/
│   ├── init/
│   │   ├── 001_schema.sql   ← tables, enums, indexes, triggers, views
│   │   └── 002_seed.sql     ← Zelda slice: the OoT split, 3 branches, entities, 1 theory
│   └── queries.sql          ← reference queries (NOT run automatically)
└── README.md
```

## Run

```bash
cp .env.example .env          # optional; defaults work as-is
docker compose up -d
docker compose logs -f db     # watch the init scripts apply, then Ctrl-C
```

Files in `db/init/` execute in filename order, **only on the first boot of the
volume**. Editing them afterwards does nothing until you reset (below).

## Verify

```bash
# table count — expect 20
docker compose exec db psql -U lore -d lore -c "\dt"

# the three-way split, as stored
docker compose exec db psql -U lore -d lore -c "
SELECT b.name AS branch, n.in_universe_order AS ord, n.kind, n.title
FROM timeline_nodes n JOIN timeline_branches b ON b.id = n.branch_id
ORDER BY b.lane_index, n.in_universe_order;"

# derived progress: which nodes the demo user has unlocked
docker compose exec db psql -U lore -d lore -c "
SELECT n.title FROM v_user_discovered_nodes d
JOIN timeline_nodes n ON n.id = d.node_id
JOIN users u ON u.id = d.user_id WHERE u.handle = 'demo';"
```

The third query is the one worth staring at — the demo user never logged
Twilight Princess as complete, so its node stays dark, while Wind Waker's two
nodes light up from a single completed game. That is the whole progress feature,
with no per-node writes anywhere.

## Reset (destroys all data)

```bash
docker compose down -v && docker compose up -d
```

## Re-apply a single file without a reset

```bash
docker compose exec -T db psql -U lore -d lore -v ON_ERROR_STOP=1 < db/init/001_schema.sql
```

## Optional GUI

```bash
docker compose --profile tools up -d
```

pgAdmin at http://localhost:5050 — host `db`, port `5432`, user `lore`.

## Notes / caveats

- Credentials here are development-only. Do not carry `.env` into anything
  reachable from outside your machine.
- `db/init/` is a bootstrap mechanism, not a migration system. As soon as the
  schema starts changing, move to versioned migrations (node-pg-migrate,
  Prisma Migrate, or Flyway) — otherwise every schema tweak costs you the
  whole dataset.
- I could not execute this DDL to verify it (no Postgres in my environment), so
  treat the first `docker compose up` as the real test. Run with
  `ON_ERROR_STOP=1` as shown above if you want a hard failure rather than a
  partially-applied schema.
