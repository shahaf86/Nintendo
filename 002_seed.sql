-- =============================================================================
-- 002_seed.sql — minimal but structurally complete slice of the Zelda timeline.
-- Purpose: exercise every hard part of the schema (a split into three branches,
-- one game spanning multiple nodes, a lineage with two incarnations, a theory
-- overlay). Enough to render a real canvas in step 3.
-- =============================================================================

BEGIN;

-- ---------- Franchise & sources ----------
INSERT INTO franchises (id, slug, name, description, accent_color) VALUES
  ('11111111-0000-0000-0000-000000000001', 'zelda', 'The Legend of Zelda',
   'Cyclical conflict between the bearers of the Triforce.', '#2E7D32');

INSERT INTO sources (id, kind, title, publisher, published_on, default_tier) VALUES
  ('22222222-0000-0000-0000-000000000001', 'BOOK', 'Hyrule Historia', 'Dark Horse', '2013-01-29', 'OFFICIAL_SECONDARY'),
  ('22222222-0000-0000-0000-000000000002', 'IN_GAME_TEXT', 'Ocarina of Time — ending sequence', 'Nintendo', '1998-11-21', 'OFFICIAL_PRIMARY'),
  ('22222222-0000-0000-0000-000000000003', 'IN_GAME_TEXT', 'Twilight Princess — Hero''s Shade dialogue', 'Nintendo', '2006-11-19', 'OFFICIAL_PRIMARY');

-- ---------- Games ----------
INSERT INTO games (id, franchise_id, slug, title, release_date, platforms) VALUES
  ('33333333-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'skyward-sword',    'Skyward Sword',        '2011-11-18', '{Wii}'),
  ('33333333-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000001', 'ocarina-of-time',  'Ocarina of Time',      '1998-11-21', '{N64}'),
  ('33333333-0000-0000-0000-000000000003', '11111111-0000-0000-0000-000000000001', 'majoras-mask',     'Majora''s Mask',       '2000-04-27', '{N64}'),
  ('33333333-0000-0000-0000-000000000004', '11111111-0000-0000-0000-000000000001', 'twilight-princess','Twilight Princess',    '2006-11-19', '{GameCube,Wii}'),
  ('33333333-0000-0000-0000-000000000005', '11111111-0000-0000-0000-000000000001', 'wind-waker',       'The Wind Waker',       '2002-12-13', '{GameCube}'),
  ('33333333-0000-0000-0000-000000000006', '11111111-0000-0000-0000-000000000001', 'a-link-to-the-past','A Link to the Past',  '1991-11-21', '{SNES}');

-- ---------- Branches: the trunk, then the three-way split ----------
INSERT INTO timeline_branches (id, franchise_id, slug, name, parent_branch_id, tier, lane_index, color) VALUES
  ('44444444-0000-0000-0000-000000000000', '11111111-0000-0000-0000-000000000001', 'trunk',       'Founding Era',        NULL, 'OFFICIAL_PRIMARY',   0, '#455A64'),
  ('44444444-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'child-era',   'Child Era',           '44444444-0000-0000-0000-000000000000', 'OFFICIAL_SECONDARY', -1, '#1976D2'),
  ('44444444-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000001', 'adult-era',   'Adult Era',           '44444444-0000-0000-0000-000000000000', 'OFFICIAL_SECONDARY',  0, '#0097A7'),
  ('44444444-0000-0000-0000-000000000003', '11111111-0000-0000-0000-000000000001', 'fallen-hero', 'Fallen Hero Timeline','44444444-0000-0000-0000-000000000000', 'OFFICIAL_SECONDARY',  1, '#C62828');

-- ---------- Nodes ----------
-- Note OoT occupies THREE nodes: its child-era play, the split, and the adult aftermath.
INSERT INTO timeline_nodes (id, branch_id, kind, slug, title, summary, in_universe_order, tier, source_id, spoiler_level) VALUES
  ('55555555-0000-0000-0000-000000000001', '44444444-0000-0000-0000-000000000000', 'BACKSTORY', 'demise-curse',   'Demise''s Curse',              'The cycle of hatred is bound to the bloodlines of the hero and the goddess.', 100.0000, 'OFFICIAL_PRIMARY',  NULL, 1),
  ('55555555-0000-0000-0000-000000000002', '44444444-0000-0000-0000-000000000000', 'GAME',      'skyward-sword',  'Skyward Sword',                'The first hero, the forging of the Master Sword.',                            200.0000, 'OFFICIAL_PRIMARY',  NULL, 0),
  ('55555555-0000-0000-0000-000000000003', '44444444-0000-0000-0000-000000000000', 'GAME',      'oot-child',      'Ocarina of Time (Child Era)',  'Link draws the Master Sword and is sealed for seven years.',                   300.0000, 'OFFICIAL_PRIMARY',  NULL, 1),
  ('55555555-0000-0000-0000-000000000004', '44444444-0000-0000-0000-000000000000', 'SPLIT',     'oot-split',      'The Ocarina Split',            'Zelda sends Link back; the defeated-hero branch diverges from the victory.',   400.0000, 'OFFICIAL_SECONDARY','22222222-0000-0000-0000-000000000001', 3),
  ('55555555-0000-0000-0000-000000000005', '44444444-0000-0000-0000-000000000001', 'GAME',      'majoras-mask',   'Majora''s Mask',               'The returned child Link searches for a lost companion in Termina.',           500.0000, 'OFFICIAL_PRIMARY',  NULL, 0),
  ('55555555-0000-0000-0000-000000000006', '44444444-0000-0000-0000-000000000001', 'GAME',      'twilight-princess','Twilight Princess',          'Centuries later; the Hero''s Shade passes on the techniques of his era.',      600.0000, 'OFFICIAL_PRIMARY',  '22222222-0000-0000-0000-000000000003', 2),
  ('55555555-0000-0000-0000-000000000007', '44444444-0000-0000-0000-000000000002', 'EVENT',     'great-flood',    'The Great Flood',              'With no hero to answer, the gods drown Hyrule.',                               500.0000, 'OFFICIAL_PRIMARY',  NULL, 2),
  ('55555555-0000-0000-0000-000000000008', '44444444-0000-0000-0000-000000000002', 'GAME',      'wind-waker',      'The Wind Waker',              'The Great Sea; a new hero without the blood of the old one.',                  600.0000, 'OFFICIAL_PRIMARY',  NULL, 0),
  ('55555555-0000-0000-0000-000000000009', '44444444-0000-0000-0000-000000000003', 'EVENT',     'imprisoning-war','The Imprisoning War',          'The hero falls; the Sages seal Ganon in the Sacred Realm.',                    500.0000, 'OFFICIAL_SECONDARY','22222222-0000-0000-0000-000000000001', 2),
  ('55555555-0000-0000-0000-00000000000a', '44444444-0000-0000-0000-000000000003', 'GAME',      'alttp',           'A Link to the Past',          'The seal weakens; Agahnim moves to break it.',                                 600.0000, 'OFFICIAL_PRIMARY',  NULL, 0);

-- ---------- Node ↔ Game ----------
INSERT INTO node_games (node_id, game_id, coverage, is_primary) VALUES
  ('55555555-0000-0000-0000-000000000002', '33333333-0000-0000-0000-000000000001', 'full',     true),
  ('55555555-0000-0000-0000-000000000003', '33333333-0000-0000-0000-000000000002', 'full',     true),
  ('55555555-0000-0000-0000-000000000004', '33333333-0000-0000-0000-000000000002', 'epilogue', true),
  ('55555555-0000-0000-0000-000000000005', '33333333-0000-0000-0000-000000000003', 'full',     true),
  ('55555555-0000-0000-0000-000000000006', '33333333-0000-0000-0000-000000000004', 'full',     true),
  ('55555555-0000-0000-0000-000000000007', '33333333-0000-0000-0000-000000000005', 'prologue', false),
  ('55555555-0000-0000-0000-000000000008', '33333333-0000-0000-0000-000000000005', 'full',     true),
  ('55555555-0000-0000-0000-00000000000a', '33333333-0000-0000-0000-000000000006', 'full',     true);

-- ---------- Edges ----------
INSERT INTO timeline_edges (from_node_id, to_node_id, kind, label, tier, source_id) VALUES
  ('55555555-0000-0000-0000-000000000001', '55555555-0000-0000-0000-000000000002', 'CAUSAL',        'sets the cycle in motion',  'OFFICIAL_PRIMARY',   NULL),
  ('55555555-0000-0000-0000-000000000002', '55555555-0000-0000-0000-000000000003', 'CHRONOLOGICAL',  NULL,                       'OFFICIAL_PRIMARY',   NULL),
  ('55555555-0000-0000-0000-000000000003', '55555555-0000-0000-0000-000000000004', 'CHRONOLOGICAL',  NULL,                       'OFFICIAL_PRIMARY',   '22222222-0000-0000-0000-000000000002'),
  ('55555555-0000-0000-0000-000000000004', '55555555-0000-0000-0000-000000000005', 'SPLIT_FROM',     'hero returned to childhood','OFFICIAL_SECONDARY','22222222-0000-0000-0000-000000000001'),
  ('55555555-0000-0000-0000-000000000004', '55555555-0000-0000-0000-000000000007', 'SPLIT_FROM',     'hero departed, adult era',  'OFFICIAL_SECONDARY','22222222-0000-0000-0000-000000000001'),
  ('55555555-0000-0000-0000-000000000004', '55555555-0000-0000-0000-000000000009', 'SPLIT_FROM',     'hero defeated',             'OFFICIAL_SECONDARY','22222222-0000-0000-0000-000000000001'),
  ('55555555-0000-0000-0000-000000000005', '55555555-0000-0000-0000-000000000006', 'CHRONOLOGICAL',  'centuries later',           'OFFICIAL_PRIMARY',   NULL),
  ('55555555-0000-0000-0000-000000000007', '55555555-0000-0000-0000-000000000008', 'CAUSAL',         NULL,                        'OFFICIAL_PRIMARY',   NULL),
  ('55555555-0000-0000-0000-000000000009', '55555555-0000-0000-0000-00000000000a', 'CHRONOLOGICAL',  NULL,                        'OFFICIAL_SECONDARY', NULL),
  -- cross-branch, non-chronological: exactly the case a pure tree cannot express
  ('55555555-0000-0000-0000-000000000003', '55555555-0000-0000-0000-000000000006', 'REINCARNATION',  'the Hero''s Shade',         'OFFICIAL_PRIMARY',   '22222222-0000-0000-0000-000000000003');

-- ---------- Entities, incarnations, appearances ----------
INSERT INTO entities (id, franchise_id, kind, slug, name, aliases, is_lineage, description) VALUES
  ('66666666-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'CHARACTER', 'link',      'Link',      '{Hero of Hyrule}',              true,  'Recurring bearer of the Triforce of Courage.'),
  ('66666666-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000001', 'CHARACTER', 'zelda',     'Zelda',     '{Princess Zelda,Sheik,Tetra}',  true,  'Recurring bearer of the Triforce of Wisdom.'),
  ('66666666-0000-0000-0000-000000000003', '11111111-0000-0000-0000-000000000001', 'CHARACTER', 'ganondorf', 'Ganondorf', '{Ganon,Demon King}',            true,  'Recurring bearer of the Triforce of Power.'),
  ('66666666-0000-0000-0000-000000000004', '11111111-0000-0000-0000-000000000001', 'ARTIFACT',  'triforce',  'The Triforce','{}',                          false, 'Relic of the three goddesses; grants the wish of its toucher.'),
  ('66666666-0000-0000-0000-000000000005', '11111111-0000-0000-0000-000000000001', 'ARTIFACT',  'master-sword','Master Sword','{Blade of Evil''s Bane}',   false, 'The sword that seals the darkness.');

INSERT INTO entity_incarnations (id, entity_id, slug, name, branch_id, first_node_id, tier) VALUES
  ('77777777-0000-0000-0000-000000000001', '66666666-0000-0000-0000-000000000001', 'hero-of-time',  'Hero of Time',  '44444444-0000-0000-0000-000000000000', '55555555-0000-0000-0000-000000000003', 'OFFICIAL_PRIMARY'),
  ('77777777-0000-0000-0000-000000000002', '66666666-0000-0000-0000-000000000001', 'hero-of-winds', 'Hero of Winds', '44444444-0000-0000-0000-000000000002', '55555555-0000-0000-0000-000000000008', 'OFFICIAL_PRIMARY');

INSERT INTO entity_variants (id, entity_id, incarnation_id, game_id, label, art_style) VALUES
  ('88888888-0000-0000-0000-000000000001', '66666666-0000-0000-0000-000000000001', '77777777-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000002', 'Ocarina Link', 'low-poly realism'),
  ('88888888-0000-0000-0000-000000000002', '66666666-0000-0000-0000-000000000001', '77777777-0000-0000-0000-000000000002', '33333333-0000-0000-0000-000000000005', 'Toon Link',    'cel-shaded');

INSERT INTO entity_appearances (entity_id, incarnation_id, node_id, game_id, variant_id, role, significance, tier) VALUES
  ('66666666-0000-0000-0000-000000000001', '77777777-0000-0000-0000-000000000001', '55555555-0000-0000-0000-000000000003', '33333333-0000-0000-0000-000000000002', '88888888-0000-0000-0000-000000000001', 'protagonist', 5, 'OFFICIAL_PRIMARY'),
  ('66666666-0000-0000-0000-000000000001', '77777777-0000-0000-0000-000000000001', '55555555-0000-0000-0000-000000000005', '33333333-0000-0000-0000-000000000003', NULL, 'protagonist', 5, 'OFFICIAL_PRIMARY'),
  ('66666666-0000-0000-0000-000000000001', '77777777-0000-0000-0000-000000000001', '55555555-0000-0000-0000-000000000006', '33333333-0000-0000-0000-000000000004', NULL, 'mentor',      3, 'OFFICIAL_PRIMARY'),
  ('66666666-0000-0000-0000-000000000001', '77777777-0000-0000-0000-000000000002', '55555555-0000-0000-0000-000000000008', '33333333-0000-0000-0000-000000000005', '88888888-0000-0000-0000-000000000002', 'protagonist', 5, 'OFFICIAL_PRIMARY'),
  ('66666666-0000-0000-0000-000000000004', NULL, '55555555-0000-0000-0000-000000000003', '33333333-0000-0000-0000-000000000002', NULL, 'macguffin', 4, 'OFFICIAL_PRIMARY'),
  ('66666666-0000-0000-0000-000000000004', NULL, '55555555-0000-0000-0000-000000000009', NULL, NULL, 'macguffin', 4, 'OFFICIAL_SECONDARY'),
  ('66666666-0000-0000-0000-000000000005', NULL, '55555555-0000-0000-0000-000000000002', '33333333-0000-0000-0000-000000000001', NULL, 'origin',    5, 'OFFICIAL_PRIMARY');

INSERT INTO entity_relations (subject_entity_id, predicate, object_entity_id, valid_from_node, branch_id, tier, source_id) VALUES
  ('66666666-0000-0000-0000-000000000001', 'wields',           '66666666-0000-0000-0000-000000000005', '55555555-0000-0000-0000-000000000003', '44444444-0000-0000-0000-000000000000', 'OFFICIAL_PRIMARY', NULL),
  ('66666666-0000-0000-0000-000000000003', 'sealed_in',        '66666666-0000-0000-0000-000000000004', '55555555-0000-0000-0000-000000000009', '44444444-0000-0000-0000-000000000003', 'OFFICIAL_SECONDARY', '22222222-0000-0000-0000-000000000001');

-- ---------- A user, progress, and a theory overlay ----------
INSERT INTO users (id, handle, display_name, email) VALUES
  ('99999999-0000-0000-0000-000000000001', 'demo', 'Demo Player', 'demo@local.test');

INSERT INTO user_game_progress (user_id, game_id, status, completed_at) VALUES
  ('99999999-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000002', 'COMPLETED', now() - interval '2 years'),
  ('99999999-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000005', 'COMPLETED_100', now() - interval '6 months'),
  ('99999999-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000004', 'IN_PROGRESS', NULL);

INSERT INTO theories (id, author_id, franchise_id, title, slug, body_md, status, spoiler_level) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', '99999999-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001',
   'Termina is a purgatory constructed by the Hero of Time', 'termina-purgatory',
   'Reading of Majora''s Mask in which Termina is not a physical location but a liminal space...', 'PUBLISHED', 2);

INSERT INTO theory_claims (theory_id, kind, node_id, payload, confidence) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', 'PROPOSES_PLACEMENT', '55555555-0000-0000-0000-000000000005',
   '{"reinterpret_as":"non-physical","note":"node is symbolic, not chronological"}'::jsonb, 3);

INSERT INTO theory_evidence (theory_id, node_id, game_id, quote, stance) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', '55555555-0000-0000-0000-000000000005', '33333333-0000-0000-0000-000000000003',
   'Every NPC in Termina has a counterpart in Hyrule.', 'SUPPORTS');

INSERT INTO theory_votes (theory_id, user_id, value) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', '99999999-0000-0000-0000-000000000001', 1);

COMMIT;
