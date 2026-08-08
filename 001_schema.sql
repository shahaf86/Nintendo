-- =============================================================================
-- Nintendo Universe Lore & Timeline — Core Schema
-- PostgreSQL 16
--
-- Design notes:
--   * The lore graph is a DAG, not a tree. Branch membership is stored
--     denormalized on nodes for fast layout; true connectivity lives in
--     timeline_edges and may cross branches.
--   * Canonicity is a *tier* carried by every assertion (node, edge, appearance,
--     relation), never a boolean and never a separate "theory" datastore.
--   * Everything that asserts something about the fiction carries a source_id.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS citext;

-- =============================================================================
-- 1. ENUMS
-- =============================================================================

CREATE TYPE canon_tier AS ENUM (
    'OFFICIAL_PRIMARY',     -- stated in-game: dialogue, cutscene, item text
    'OFFICIAL_SECONDARY',   -- Hyrule Historia, official guides, dev interviews
    'OFFICIAL_AMBIGUOUS',   -- officially stated but contradicted elsewhere
    'RETCONNED',            -- was official, superseded by later material
    'COMMUNITY_THEORY'      -- user-submitted, not official
);

CREATE TYPE node_kind AS ENUM (
    'GAME',          -- a game's main narrative occupies this slot
    'EVENT',         -- discrete in-universe event (Imprisoning War, Great Flood)
    'ERA',           -- span container (Era of the Hero of Time)
    'SPLIT',         -- divergence point; outgoing edges start new branches
    'CONVERGENCE',   -- branches merge / are reconciled
    'BACKSTORY'      -- pre-history with no playable representation
);

CREATE TYPE edge_kind AS ENUM (
    'CHRONOLOGICAL', -- simply "after"
    'CAUSAL',        -- A causes B
    'SPLIT_FROM',    -- branch origin
    'CONVERGES_INTO',
    'REINCARNATION', -- soul/lineage continuity across incarnations
    'SEALED_BY',
    'RETCONS',       -- B invalidates A
    'PARALLEL',      -- concurrent, different branch/region
    'REFERENCES'     -- soft nod, cameo, thematic echo
);

CREATE TYPE entity_kind AS ENUM (
    'CHARACTER','ARTIFACT','LOCATION','RACE','ORGANIZATION','CONCEPT','DEITY'
);

CREATE TYPE progress_status AS ENUM (
    'NOT_STARTED','IN_PROGRESS','COMPLETED','COMPLETED_100'
);

CREATE TYPE theory_status AS ENUM (
    'DRAFT','PUBLISHED','FLAGGED','ARCHIVED','PROMOTED_TO_CANON'
);

CREATE TYPE claim_kind AS ENUM (
    'PROPOSES_EDGE',        -- "this event caused that one"
    'DISPUTES_EDGE',
    'PROPOSES_PLACEMENT',   -- "this game sits here on the branch instead"
    'IDENTIFIES_ENTITY',    -- "the Hero's Shade IS the Hero of Time"
    'PROPOSES_RELATION',
    'FREEFORM'
);

-- =============================================================================
-- 2. SOURCES — every fictional assertion is attributable
-- =============================================================================

CREATE TABLE sources (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    kind            text NOT NULL,   -- IN_GAME_TEXT | BOOK | INTERVIEW | MANUAL | FAN
    title           text NOT NULL,
    publisher       text,
    published_on    date,
    locator         text,            -- page number, timestamp, quest name
    url             text,
    excerpt         text,
    default_tier    canon_tier NOT NULL DEFAULT 'OFFICIAL_SECONDARY',
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_sources_title_trgm ON sources USING gin (title gin_trgm_ops);

-- =============================================================================
-- 3. CATALOG — real-world release metadata (kept separate from in-universe time)
-- =============================================================================

CREATE TABLE franchises (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug        text UNIQUE NOT NULL,          -- 'zelda', 'metroid', 'fire-emblem'
    name        text NOT NULL,
    description text,
    accent_color text                          -- drives canvas theming
);

CREATE TABLE games (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    franchise_id    uuid NOT NULL REFERENCES franchises(id) ON DELETE RESTRICT,
    slug            text UNIQUE NOT NULL,
    title           text NOT NULL,
    subtitle        text,
    release_date    date,
    platforms       text[] NOT NULL DEFAULT '{}',
    is_remake_of    uuid REFERENCES games(id),  -- OoT3D -> OoT: shares lore, not a node
    cover_art_url   text,
    synopsis        text,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_games_franchise ON games(franchise_id, release_date);

-- =============================================================================
-- 4. TIMELINE GRAPH
-- =============================================================================

-- A branch = a named lane on the canvas. Self-referencing for nested splits.
CREATE TABLE timeline_branches (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    franchise_id        uuid NOT NULL REFERENCES franchises(id) ON DELETE CASCADE,
    slug                text NOT NULL,
    name                text NOT NULL,          -- 'Fallen Hero', 'Child Era', 'Adult Era'
    parent_branch_id    uuid REFERENCES timeline_branches(id) ON DELETE CASCADE,
    split_from_node_id  uuid,                   -- FK added after timeline_nodes
    tier                canon_tier NOT NULL DEFAULT 'OFFICIAL_PRIMARY',
    lane_index          integer NOT NULL DEFAULT 0,   -- vertical stacking hint
    color               text,
    description         text,
    UNIQUE (franchise_id, slug)
);

CREATE TABLE timeline_nodes (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id           uuid NOT NULL REFERENCES timeline_branches(id) ON DELETE CASCADE,
    kind                node_kind NOT NULL,
    slug                text NOT NULL,
    title               text NOT NULL,
    summary             text,
    -- In-universe ordering. Numeric with gaps so nodes can be inserted between
    -- two existing ones without renumbering the branch.
    in_universe_order   numeric(14,4) NOT NULL,
    era_label           text,                   -- 'Era of Chaos', unquantified time
    tier                canon_tier NOT NULL DEFAULT 'OFFICIAL_PRIMARY',
    source_id           uuid REFERENCES sources(id),
    -- Layout: auto-computed by a job, but hand-overridable. Lore DAGs never
    -- auto-layout acceptably; pinned coordinates win.
    layout_x            double precision,
    layout_y            double precision,
    layout_pinned       boolean NOT NULL DEFAULT false,
    spoiler_level       smallint NOT NULL DEFAULT 0,  -- 0 = safe, 3 = ending reveal
    metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    UNIQUE (branch_id, slug)
);
CREATE INDEX idx_nodes_branch_order ON timeline_nodes(branch_id, in_universe_order);
CREATE INDEX idx_nodes_tier ON timeline_nodes(tier) WHERE tier <> 'COMMUNITY_THEORY';
CREATE INDEX idx_nodes_metadata ON timeline_nodes USING gin (metadata);

ALTER TABLE timeline_branches
    ADD CONSTRAINT fk_branch_split_node
    FOREIGN KEY (split_from_node_id) REFERENCES timeline_nodes(id) ON DELETE SET NULL;

-- A game may span several nodes (OoT: child era, adult era, the split itself),
-- and a node may involve several games (crossovers, shared events).
CREATE TABLE node_games (
    node_id     uuid NOT NULL REFERENCES timeline_nodes(id) ON DELETE CASCADE,
    game_id     uuid NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    coverage    text,          -- 'full' | 'prologue' | 'flashback' | 'epilogue'
    is_primary  boolean NOT NULL DEFAULT true,
    PRIMARY KEY (node_id, game_id)
);
CREATE INDEX idx_node_games_game ON node_games(game_id);

CREATE TABLE timeline_edges (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    from_node_id    uuid NOT NULL REFERENCES timeline_nodes(id) ON DELETE CASCADE,
    to_node_id      uuid NOT NULL REFERENCES timeline_nodes(id) ON DELETE CASCADE,
    kind            edge_kind NOT NULL DEFAULT 'CHRONOLOGICAL',
    label           text,
    tier            canon_tier NOT NULL DEFAULT 'OFFICIAL_PRIMARY',
    source_id       uuid REFERENCES sources(id),
    weight          smallint NOT NULL DEFAULT 1,   -- render thickness / confidence
    metadata        jsonb NOT NULL DEFAULT '{}'::jsonb,
    CHECK (from_node_id <> to_node_id),
    UNIQUE (from_node_id, to_node_id, kind)
);
CREATE INDEX idx_edges_from ON timeline_edges(from_node_id, tier);
CREATE INDEX idx_edges_to   ON timeline_edges(to_node_id, tier);

-- =============================================================================
-- 5. ENTITIES
--
-- Two-level identity model. `entities` is the archetype/lineage ("Link",
-- "The Triforce", "Samus Aran"). `entity_incarnations` is a specific instance
-- ("Hero of Time", "Hero of Winds"). Appearances hang off incarnations where
-- one exists. This is the single most important modeling decision for Zelda.
-- =============================================================================

CREATE TABLE entities (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    franchise_id    uuid REFERENCES franchises(id) ON DELETE SET NULL, -- NULL = cross-franchise
    kind            entity_kind NOT NULL,
    slug            text UNIQUE NOT NULL,
    name            text NOT NULL,
    aliases         text[] NOT NULL DEFAULT '{}',
    description     text,
    is_lineage      boolean NOT NULL DEFAULT false,  -- true => expect incarnations
    attributes      jsonb NOT NULL DEFAULT '{}'::jsonb, -- kind-specific fields
    canonical_image_url text,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_entities_kind ON entities(kind);
CREATE INDEX idx_entities_name_trgm ON entities USING gin (name gin_trgm_ops);
CREATE INDEX idx_entities_aliases ON entities USING gin (aliases);
CREATE INDEX idx_entities_attributes ON entities USING gin (attributes);

CREATE TABLE entity_incarnations (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id       uuid NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    slug            text NOT NULL,
    name            text NOT NULL,             -- 'Hero of Time'
    branch_id       uuid REFERENCES timeline_branches(id) ON DELETE SET NULL,
    first_node_id   uuid REFERENCES timeline_nodes(id) ON DELETE SET NULL,
    last_node_id    uuid REFERENCES timeline_nodes(id) ON DELETE SET NULL,
    tier            canon_tier NOT NULL DEFAULT 'OFFICIAL_PRIMARY',
    notes           text,
    UNIQUE (entity_id, slug)
);

-- Design evolution across releases (feature 2).
CREATE TABLE entity_variants (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id       uuid NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    incarnation_id  uuid REFERENCES entity_incarnations(id) ON DELETE SET NULL,
    game_id         uuid REFERENCES games(id) ON DELETE SET NULL,
    label           text NOT NULL,             -- 'Toon Link', 'Fierce Deity'
    art_style       text,
    image_url       text,
    design_notes    text,
    UNIQUE (entity_id, game_id, label)
);

CREATE TABLE entity_appearances (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         uuid NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    incarnation_id    uuid REFERENCES entity_incarnations(id) ON DELETE SET NULL,
    node_id           uuid NOT NULL REFERENCES timeline_nodes(id) ON DELETE CASCADE,
    game_id           uuid REFERENCES games(id) ON DELETE SET NULL,
    variant_id        uuid REFERENCES entity_variants(id) ON DELETE SET NULL,
    role              text,        -- 'protagonist' | 'antagonist' | 'mentioned'
    narrative_context text,
    significance      smallint NOT NULL DEFAULT 1,  -- 1..5, drives entity-path weight
    tier              canon_tier NOT NULL DEFAULT 'OFFICIAL_PRIMARY',
    source_id         uuid REFERENCES sources(id)
);
-- Expression must live in a unique INDEX; a UNIQUE table constraint cannot hold one.
CREATE UNIQUE INDEX uq_appearance_entity_node_incarnation
    ON entity_appearances (
        entity_id,
        node_id,
        COALESCE(incarnation_id, '00000000-0000-0000-0000-000000000000'::uuid)
    );
CREATE INDEX idx_appearances_node ON entity_appearances(node_id, tier);
CREATE INDEX idx_appearances_entity ON entity_appearances(entity_id, tier);

-- Reified, time-scoped triples: (subject) --predicate--> (object), valid over a
-- node range. Lets "Zelda is the reincarnation of Hylia" be true only in some
-- branches, and lets a theory assert a competing relation at a lower tier.
CREATE TABLE entity_relations (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_entity_id uuid NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    predicate         text NOT NULL,   -- 'wields' | 'reincarnation_of' | 'sealed_in'
    object_entity_id  uuid NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    valid_from_node   uuid REFERENCES timeline_nodes(id) ON DELETE SET NULL,
    valid_to_node     uuid REFERENCES timeline_nodes(id) ON DELETE SET NULL,
    branch_id         uuid REFERENCES timeline_branches(id) ON DELETE CASCADE,
    tier              canon_tier NOT NULL DEFAULT 'OFFICIAL_PRIMARY',
    source_id         uuid REFERENCES sources(id),
    notes             text
);
CREATE INDEX idx_relations_subject ON entity_relations(subject_entity_id, predicate);
CREATE INDEX idx_relations_object  ON entity_relations(object_entity_id, predicate);

-- =============================================================================
-- 6. USERS
-- =============================================================================

CREATE TABLE users (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    handle          citext UNIQUE,
    display_name    text,
    email           text UNIQUE,
    avatar_url      text,
    reputation      integer NOT NULL DEFAULT 0,
    spoiler_ceiling smallint NOT NULL DEFAULT 3,  -- global spoiler tolerance
    created_at      timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- 7. THEORY ENGINE
--
-- A theory is a proposed *overlay* on the graph: a set of structured claims the
-- client can apply to render "the timeline if this theory is true", plus prose.
-- =============================================================================

CREATE TABLE theories (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    franchise_id    uuid REFERENCES franchises(id) ON DELETE SET NULL,
    title           text NOT NULL,
    slug            text UNIQUE NOT NULL,
    body_md         text NOT NULL,
    status          theory_status NOT NULL DEFAULT 'DRAFT',
    score           integer NOT NULL DEFAULT 0,   -- denormalized, trigger-maintained
    vote_count      integer NOT NULL DEFAULT 0,
    spoiler_level   smallint NOT NULL DEFAULT 0,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_theories_ranking ON theories(franchise_id, status, score DESC);

CREATE TABLE theory_claims (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    theory_id       uuid NOT NULL REFERENCES theories(id) ON DELETE CASCADE,
    kind            claim_kind NOT NULL,
    -- Anchors: whichever are relevant to the claim kind.
    node_id         uuid REFERENCES timeline_nodes(id) ON DELETE CASCADE,
    edge_id         uuid REFERENCES timeline_edges(id) ON DELETE CASCADE,
    entity_id       uuid REFERENCES entities(id) ON DELETE CASCADE,
    -- Structured delta the renderer applies, e.g.
    -- {"from_node":"<uuid>","to_node":"<uuid>","kind":"CAUSAL","label":"..."}
    payload         jsonb NOT NULL DEFAULT '{}'::jsonb,
    confidence      smallint NOT NULL DEFAULT 3   -- author's own 1..5
);
CREATE INDEX idx_claims_theory ON theory_claims(theory_id);
CREATE INDEX idx_claims_node ON theory_claims(node_id);
CREATE INDEX idx_claims_entity ON theory_claims(entity_id);

CREATE TABLE theory_evidence (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    theory_id       uuid NOT NULL REFERENCES theories(id) ON DELETE CASCADE,
    claim_id        uuid REFERENCES theory_claims(id) ON DELETE CASCADE,
    source_id       uuid REFERENCES sources(id) ON DELETE SET NULL,
    node_id         uuid REFERENCES timeline_nodes(id) ON DELETE SET NULL,
    game_id         uuid REFERENCES games(id) ON DELETE SET NULL,
    quote           text,
    media_url       text,
    stance          text NOT NULL DEFAULT 'SUPPORTS'  -- SUPPORTS | CONTRADICTS
);

CREATE TABLE theory_votes (
    theory_id       uuid NOT NULL REFERENCES theories(id) ON DELETE CASCADE,
    user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    value           smallint NOT NULL CHECK (value IN (-1, 1)),
    created_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (theory_id, user_id)
);

CREATE OR REPLACE FUNCTION trg_theory_score() RETURNS trigger AS $$
BEGIN
    UPDATE theories t SET
        score = COALESCE((SELECT SUM(value) FROM theory_votes v WHERE v.theory_id = t.id), 0),
        vote_count = (SELECT COUNT(*) FROM theory_votes v WHERE v.theory_id = t.id)
    WHERE t.id = COALESCE(NEW.theory_id, OLD.theory_id);
    RETURN NULL;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER theory_votes_rescore
AFTER INSERT OR UPDATE OR DELETE ON theory_votes
FOR EACH ROW EXECUTE FUNCTION trg_theory_score();

-- =============================================================================
-- 8. "MY LORE JOURNEY" — progress
--
-- Only game-level progress is authoritative. Node discovery is DERIVED, so
-- adding a node to a game retroactively lights it up for everyone.
-- =============================================================================

CREATE TABLE user_game_progress (
    user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    game_id         uuid NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    status          progress_status NOT NULL DEFAULT 'NOT_STARTED',
    completed_at    timestamptz,
    rating          smallint CHECK (rating BETWEEN 1 AND 10),
    notes           text,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, game_id)
);
CREATE INDEX idx_progress_user_status ON user_game_progress(user_id, status);

-- Manual overrides: "I read the manga", "hide this node", "bookmark this".
CREATE TABLE user_node_overrides (
    user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    node_id         uuid NOT NULL REFERENCES timeline_nodes(id) ON DELETE CASCADE,
    forced_state    text NOT NULL,      -- DISCOVERED | HIDDEN | BOOKMARKED
    created_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, node_id, forced_state)
);

-- Derived discovery. Cheap enough to be a plain view at this graph size; swap to
-- MATERIALIZED + per-user refresh only if node counts pass ~10k.
CREATE VIEW v_user_discovered_nodes AS
SELECT DISTINCT
    p.user_id,
    ng.node_id
FROM user_game_progress p
JOIN node_games ng ON ng.game_id = p.game_id
WHERE p.status IN ('COMPLETED','COMPLETED_100')
UNION
SELECT o.user_id, o.node_id
FROM user_node_overrides o
WHERE o.forced_state = 'DISCOVERED';

