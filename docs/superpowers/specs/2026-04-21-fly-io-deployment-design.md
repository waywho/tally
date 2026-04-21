# Fly.io Deployment — Design Spec

## Goal

Add Fly.io as the primary deployment target for Tally while preserving the existing Kamal 2 config for a future Hetzner VPS option. Set up CI-driven deploys on push to `main`.

## Domain

`tally.quest` — custom domain pointed at the Fly.io app. Fly also provides `tally.fly.dev` (or similar) as a fallback.

## Fly.io App Config

A `fly.toml` at the project root, alongside the existing `config/deploy.yml` (Kamal stays untouched).

| Setting | Value |
|---|---|
| App name | `tally` (or `tally-quest` if taken) |
| Primary region | `lhr` (London) |
| VM size | `shared-cpu-1x`, 512MB RAM |
| Internal port | 80 (Thruster) |
| Health check | `GET /up` |
| Deploy strategy | Fly builds from the existing `Dockerfile` |
| Release command | `bin/rails db:prepare` |

The existing Dockerfile is used as-is. Fly runs it natively — no changes needed.

## Database

Fly Postgres cluster:

| Setting | Value |
|---|---|
| Name | `tally-db` |
| Region | `lhr` |
| VM | `shared-cpu-1x`, 1GB RAM, 10GB disk |

Fly auto-sets `DATABASE_URL` on the app for the primary database. Three additional databases are created on the same cluster for Solid Cache, Solid Queue, and Solid Cable:

| Database | Env var |
|---|---|
| `tally_production` (primary) | `DATABASE_URL` (auto-set by Fly) |
| `tally_production_cache` | `CACHE_DATABASE_URL` |
| `tally_production_queue` | `QUEUE_DATABASE_URL` |
| `tally_production_cable` | `CABLE_DATABASE_URL` |

A one-time `bin/fly-setup` script creates the auxiliary databases and sets the env vars on the Fly app.

### `database.yml` changes (production only)

Update the production block to use URL-based config:

```yaml
production:
  primary:
    <<: *default
    url: <%= ENV["DATABASE_URL"] %>
  cache:
    <<: *default
    url: <%= ENV.fetch("CACHE_DATABASE_URL") { ENV["DATABASE_URL"] } %>
    migrations_paths: db/cache_migrate
  queue:
    <<: *default
    url: <%= ENV.fetch("QUEUE_DATABASE_URL") { ENV["DATABASE_URL"] } %>
    migrations_paths: db/queue_migrate
  cable:
    <<: *default
    url: <%= ENV.fetch("CABLE_DATABASE_URL") { ENV["DATABASE_URL"] } %>
    migrations_paths: db/cable_migrate
```

Fallback to `DATABASE_URL` means it works even if the auxiliary vars aren't set (all databases share the primary — useful for bootstrapping).

## Production Config Changes

In `config/environments/production.rb`:

- Enable SSL: `config.assume_ssl = true` and `config.force_ssl = true`
- Exclude health check from SSL redirect: `config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }`
- Set allowed hosts: `config.hosts = ["tally.quest", /.*\.fly\.dev/]`
- Set mailer host: `config.action_mailer.default_url_options = { host: "tally.quest" }`

## CI Deploy (GitHub Actions)

A `.github/workflows/deploy.yml` workflow:

- **Trigger:** push to `main`
- **Steps:**
  1. Checkout code
  2. Set up Fly CLI (`superfly/flyctl-setup-action`)
  3. Run `fly deploy --remote-only`
- **Secret:** `FLY_API_TOKEN` stored as a GitHub Actions secret

This is a minimal deploy pipeline. The existing CI (rubocop, brakeman, minitest) should run first as a dependency — the deploy job only runs if CI passes.

## One-Time Setup Script (`bin/fly-setup`)

A shell script for initial Fly.io provisioning:

1. Create the Fly app (`fly apps create`)
2. Create the Postgres cluster (`fly postgres create`)
3. Attach Postgres to the app (`fly postgres attach`)
4. Connect to Postgres and create the auxiliary databases
5. Set `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL`, `CABLE_DATABASE_URL` as Fly secrets
6. Set `RAILS_MASTER_KEY` as a Fly secret

## What Stays Unchanged

- `config/deploy.yml` (Kamal) — untouched, remains a viable deploy path to a VPS
- `Dockerfile` — used as-is by both Kamal and Fly
- `bin/docker-entrypoint` — kept for Kamal compatibility (Fly uses the release command instead)

## Files to Create or Modify

| File | Action |
|---|---|
| `fly.toml` | Create |
| `bin/fly-setup` | Create |
| `.github/workflows/deploy.yml` | Create |
| `config/database.yml` | Modify production block |
| `config/environments/production.rb` | Modify (SSL, hosts, mailer) |
