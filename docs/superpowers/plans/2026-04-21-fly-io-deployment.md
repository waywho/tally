# Fly.io Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Fly.io as the primary deployment target alongside the existing Kamal config, with CI-driven deploys on push to `main`.

**Architecture:** A `fly.toml` config tells Fly to build from the existing Dockerfile, run `db:prepare` as a release command, and expose port 80 via Thruster. Production Rails config is updated for SSL, allowed hosts, and URL-based database connections. A GitHub Actions workflow deploys after CI passes.

**Tech Stack:** Fly.io, PostgreSQL (Fly Postgres), GitHub Actions, Rails 8 production config

---

### Task 1: Create `fly.toml`

**Files:**
- Create: `fly.toml`

- [ ] **Step 1: Create `fly.toml` at the project root**

```toml
app = 'tally'
primary_region = 'lhr'

[build]

[deploy]
  release_command = './bin/rails db:prepare'

[http_service]
  internal_port = 80
  force_https = true
  auto_stop_machines = 'stop'
  auto_start_machines = true
  min_machines_running = 0
  processes = ['app']

[[vm]]
  size = 'shared-cpu-1x'
  memory = '512mb'

[checks]
  [checks.status]
    port = 80
    type = 'http'
    interval = '10s'
    timeout = '2s'
    grace_period = '5s'
    method = 'GET'
    path = '/up'
```

- [ ] **Step 2: Commit**

```bash
git add fly.toml
git commit -m "feat: add fly.toml for Fly.io deployment"
```

---

### Task 2: Update `config/database.yml` production block

**Files:**
- Modify: `config/database.yml:87-104`

- [ ] **Step 1: Replace the production block with URL-based config**

The current production block uses hardcoded database names and a `TALLY_DATABASE_PASSWORD` env var. Replace it with URL-based config that works with Fly's auto-set `DATABASE_URL`:

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

The `ENV.fetch(...) { ENV["DATABASE_URL"] }` fallback means the auxiliary databases fall back to the primary URL if their dedicated vars aren't set. This is useful for bootstrapping and also keeps Kamal compatibility (just set `DATABASE_URL` on the VPS).

- [ ] **Step 2: Verify dev/test are unaffected**

Run: `bin/rails db:migrate:status`

Expected: normal output showing migration status against `tally_development`. The dev/test blocks are unchanged so they should work as before.

- [ ] **Step 3: Commit**

```bash
git add config/database.yml
git commit -m "feat: use URL-based database config for production"
```

---

### Task 3: Update `config/environments/production.rb`

**Files:**
- Modify: `config/environments/production.rb`

- [ ] **Step 1: Enable SSL termination**

Find these commented-out lines:

```ruby
  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }
```

Uncomment them to:

```ruby
  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }
```

- [ ] **Step 2: Set allowed hosts**

Find these commented-out lines:

```ruby
  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
```

Replace with:

```ruby
  # Enable DNS rebinding protection and other `Host` header attacks.
  config.hosts = [
    "tally.quest",
    /.*\.fly\.dev/
  ]

  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
```

- [ ] **Step 3: Update mailer default URL host**

Find:

```ruby
  config.action_mailer.default_url_options = { host: "example.com" }
```

Replace with:

```ruby
  config.action_mailer.default_url_options = { host: "tally.quest" }
```

- [ ] **Step 4: Commit**

```bash
git add config/environments/production.rb
git commit -m "feat: configure production SSL, allowed hosts, and mailer for tally.quest"
```

---

### Task 4: Create `bin/fly-setup`

**Files:**
- Create: `bin/fly-setup`

- [ ] **Step 1: Create the setup script**

This is a one-time provisioning script. It's interactive (requires user confirmation at each step) and idempotent where possible.

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="tally"
DB_NAME="tally-db"
REGION="lhr"

echo "=== Fly.io Setup for Tally ==="
echo ""

# 1. Create the Fly app
echo "--- Creating Fly app: $APP_NAME ---"
fly apps create "$APP_NAME" --org personal || echo "App may already exist, continuing..."

# 2. Create the Postgres cluster
echo ""
echo "--- Creating Postgres cluster: $DB_NAME ---"
fly postgres create \
  --name "$DB_NAME" \
  --region "$REGION" \
  --vm-size shared-cpu-1x \
  --initial-cluster-size 1 \
  --volume-size 10 || echo "Postgres cluster may already exist, continuing..."

# 3. Attach Postgres to the app (sets DATABASE_URL automatically)
echo ""
echo "--- Attaching Postgres to app ---"
fly postgres attach "$DB_NAME" --app "$APP_NAME" || echo "May already be attached, continuing..."

# 4. Create auxiliary databases
echo ""
echo "--- Creating auxiliary databases ---"
echo "Connecting to Postgres to create cache, queue, and cable databases..."
fly postgres connect --app "$DB_NAME" --command "
CREATE DATABASE tally_production_cache;
CREATE DATABASE tally_production_queue;
CREATE DATABASE tally_production_cable;
" || echo "Databases may already exist, continuing..."

# 5. Build auxiliary DATABASE_URLs
# Extract the DATABASE_URL from Fly secrets to construct auxiliary URLs
echo ""
echo "--- Setting auxiliary database URLs ---"
echo "Fetching DATABASE_URL to construct auxiliary URLs..."
echo ""
echo "NOTE: You need to manually set these secrets using the DATABASE_URL format."
echo "Run 'fly secrets list --app $APP_NAME' to see DATABASE_URL,"
echo "then set auxiliary URLs by replacing the database name in the URL:"
echo ""
echo "  fly secrets set --app $APP_NAME \\"
echo "    CACHE_DATABASE_URL=\"postgres://.../<db_cache>\" \\"
echo "    QUEUE_DATABASE_URL=\"postgres://.../<db_queue>\" \\"
echo "    CABLE_DATABASE_URL=\"postgres://.../<db_cable>\""
echo ""

# 6. Set RAILS_MASTER_KEY
echo "--- Setting RAILS_MASTER_KEY ---"
if [ -f config/master.key ]; then
  fly secrets set --app "$APP_NAME" RAILS_MASTER_KEY="$(cat config/master.key)"
  echo "RAILS_MASTER_KEY set from config/master.key"
else
  echo "WARNING: config/master.key not found. Set it manually:"
  echo "  fly secrets set --app $APP_NAME RAILS_MASTER_KEY=<your-key>"
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Set the auxiliary database URLs (see above)"
echo "  2. Point tally.quest DNS to Fly: fly certs create --app $APP_NAME tally.quest"
echo "  3. Deploy: fly deploy --app $APP_NAME"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x bin/fly-setup
```

- [ ] **Step 3: Commit**

```bash
git add bin/fly-setup
git commit -m "feat: add bin/fly-setup for one-time Fly.io provisioning"
```

---

### Task 5: Create `.github/workflows/deploy.yml`

**Files:**
- Create: `.github/workflows/deploy.yml`
- Reference: `.github/workflows/ci.yml` (existing CI workflow)

- [ ] **Step 1: Create the deploy workflow**

The deploy workflow triggers on push to `main` and depends on all CI jobs passing first. It uses `superfly/flyctl-setup-action` to install the Fly CLI and runs `fly deploy --remote-only`.

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  ci:
    uses: ./.github/workflows/ci.yml

  deploy:
    needs: ci
    runs-on: ubuntu-latest
    concurrency:
      group: deploy-production
      cancel-in-progress: false

    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Set up Fly CLI
        uses: superfly/flyctl-setup-action@v2

      - name: Deploy to Fly.io
        run: fly deploy --remote-only
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

- [ ] **Step 2: Update `ci.yml` to support reusable workflow calls**

The deploy workflow uses `uses: ./.github/workflows/ci.yml` to run CI as a dependency. For this to work, `ci.yml` must support the `workflow_call` trigger. Add it to the existing `on:` block:

In `.github/workflows/ci.yml`, change:

```yaml
on:
  pull_request:
  push:
    branches: [ main ]
```

To:

```yaml
on:
  pull_request:
  push:
    branches: [ main ]
  workflow_call:
```

This is a no-op for the existing CI behavior — it just allows other workflows to call it.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/deploy.yml .github/workflows/ci.yml
git commit -m "feat: add GitHub Actions deploy workflow for Fly.io"
```
