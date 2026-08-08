#!/usr/bin/env node
/**
 * export-graph.mjs — Postgres (source of truth) → docs/data/graph.json (published artifact).
 *
 *   npm i pg
 *   DATABASE_URL=postgresql://lore:lore_dev@localhost:5432/lore node tools/export-graph.mjs
 *
 * Re-run this after any content edit, then commit site/. That is the whole
 * publish pipeline: the database never has to be reachable from the internet.
 */
import { writeFile, mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import pg from "pg";

const OUT = resolve(process.cwd(), "docs/data/graph.json");
const client = new pg.Client({
  connectionString: process.env.DATABASE_URL || "postgresql://lore:lore_dev@localhost:5432/lore",
});

const q = async (sql, params = []) => (await client.query(sql, params)).rows;

async function main() {
  await client.connect();

  const branches = await q(`
    SELECT b.id, b.slug, b.name, b.lane_index AS lane, b.tier,
           COALESCE(b.color, '#8A93AD') AS color
    FROM timeline_branches b ORDER BY b.lane_index`);

  const games = await q(`
    SELECT g.id, g.title, EXTRACT(YEAR FROM g.release_date)::int AS year
    FROM games g WHERE g.is_remake_of IS NULL ORDER BY g.release_date`);

  const nodes = await q(`
    SELECT n.id, n.branch_id AS branch, n.kind, n.slug, n.title,
           n.summary, n.in_universe_order::float AS "order", n.tier,
           n.spoiler_level AS spoiler,
           COALESCE(
             (SELECT array_agg(ng.game_id ORDER BY ng.is_primary DESC)
              FROM node_games ng WHERE ng.node_id = n.id),
             '{}'
           ) AS games
    FROM timeline_nodes n
    ORDER BY n.in_universe_order`);

  const edges = await q(`
    SELECT e.from_node_id AS from, e.to_node_id AS to, e.kind, e.label, e.tier
    FROM timeline_edges e`);

  // Entities carry their appearance trail inline — the site never joins at runtime.
  const entities = await q(`
    SELECT en.id, en.kind, en.name, en.description,
           COALESCE(json_agg(
             json_build_object(
               'node', a.node_id,
               'role', a.role,
               'incarnation', i.name,
               'context', a.narrative_context
             ) ORDER BY n.in_universe_order
           ) FILTER (WHERE a.id IS NOT NULL), '[]') AS appearances
    FROM entities en
    LEFT JOIN entity_appearances a ON a.entity_id = en.id
    LEFT JOIN timeline_nodes n ON n.id = a.node_id
    LEFT JOIN entity_incarnations i ON i.id = a.incarnation_id
    GROUP BY en.id
    HAVING COUNT(a.id) > 0
    ORDER BY COUNT(a.id) DESC, en.name`);

  // Published theories become COMMUNITY_THEORY edges — one uniform graph, as designed.
  const theoryEdges = await q(`
    SELECT (c.payload->>'from_node')::uuid AS from,
           (c.payload->>'to_node')::uuid   AS to,
           COALESCE(c.payload->>'kind', 'REFERENCES') AS kind,
           t.title AS label,
           'COMMUNITY_THEORY'::text AS tier
    FROM theory_claims c
    JOIN theories t ON t.id = c.theory_id
    WHERE t.status = 'PUBLISHED'
      AND c.kind = 'PROPOSES_EDGE'
      AND c.payload ? 'from_node' AND c.payload ? 'to_node'`);

  const payload = {
    generated_at: new Date().toISOString(),
    branches, games, nodes,
    edges: [...edges, ...theoryEdges],
    entities,
  };

  await mkdir(dirname(OUT), { recursive: true });
  await writeFile(OUT, JSON.stringify(payload, null, 1));
  console.log(
    `wrote ${OUT}\n  ${nodes.length} nodes · ${payload.edges.length} edges · ` +
    `${entities.length} entities · ${branches.length} branches`
  );
}

main()
  .catch((e) => { console.error("export failed:", e.message); process.exitCode = 1; })
  .finally(() => client.end());
