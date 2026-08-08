# Publishing the site

## Correction from what I told you earlier

I said to set GitHub Pages to `main` + `/site`. That doesn't work — when Pages
deploys from a branch it only offers two folder options, **`/ (root)`** and
**`/docs`**. Arbitrary folders aren't supported.

So the site now lives in `docs/`, not `site/`. Everything else is unchanged.

## What to push

Push the whole repo. One repo holds both the authoring layer (schema, seed,
compose, export script) and the published site — they belong together, and only
`docs/` gets served.

```
lore-platform/
├── .gitignore          ← commit
├── .env.example        ← commit
├── .env                ← NEVER commit (gitignored)
├── docker-compose.yml  ← commit
├── db/                 ← commit
├── tools/              ← commit
├── docs/               ← commit — this is what GitHub Pages serves
└── node_modules/       ← never (gitignored)
```

## Push

```bash
cd lore-platform
git init
git add .
git commit -m "Lore timeline: schema, seed, static site"
git branch -M main
git remote add origin https://github.com/<you>/lore-timeline.git
git push -u origin main
```

Then: **Settings → Pages → Source: Deploy from a branch → `main` / `/docs` → Save.**

Live in about a minute at `https://<you>.github.io/lore-timeline/`.

## Check before you push

```bash
git status --short                        # nothing named .env, nothing under node_modules
cd docs && python3 -m http.server 8080    # open localhost:8080, click a few nodes
```

## Updating content later

Postgres stays on your machine. Nothing on the internet connects to it. You
publish a snapshot:

```bash
npm i pg
DATABASE_URL=postgresql://lore:lore_dev@localhost:5432/lore node tools/export-graph.mjs
git add docs/data/graph.json && git commit -m "refresh graph" && git push
```

Pages redeploys on push. Edit lore in SQL → export → push → live.

## One thing worth knowing if the repo is public

The schema, seed, and exported `graph.json` all become publicly readable. For
this project that's fine — none of it is sensitive. But `.env` with real
credentials never goes in, public or private, which is what `.gitignore` is for.
When you later add an API with real keys, those live in the host's environment
settings (Vercel, Netlify), never in the repo.

## What the static version does and does not do

Works:

- The branching canvas — pan, zoom, pinch, the three-way Ocarina split
- Canon-tier filtering, with excluded material fading to a ghost outline rather
  than vanishing, so you can see the shape of what you filtered
- Entity trails — pick Link, his four appearances light up across all branches
- "My lore journey" — log games, watch sealed nodes break open

Doesn't, and can't without a server:

- Users submitting theories or voting. Theories display (the export turns
  published `PROPOSES_EDGE` claims into theory-tier edges) but can't be added
  from the site.
- Progress syncing across devices — it's in that browser's local storage, so
  your phone starts from zero.
- Accounts, moderation, any shared state.

Those are what step 2 is for. When you want them: Next.js on Vercel plus Neon or
Supabase, both of which take `001_schema.sql` unchanged. The static site becomes
the read path; the API adds the write path.

## Local preview

```bash
cd docs && python3 -m http.server 8080
```

Opening `index.html` via `file://` also renders, but the browser blocks the
`graph.json` fetch, so you'll see the embedded fallback data instead of your
exported content.
