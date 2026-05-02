# Fly.io Cheatsheet

App: `tally-quest` (`tally-quest.fly.dev`)

## Deploy

```bash
flyctl deploy                         # Build + deploy
flyctl deploy --remote-only           # Build on Fly's servers (faster)
```

## Status & Info

```bash
flyctl status                         # App status, machines, IPs
flyctl apps list                      # All your apps
```

## Logs

```bash
flyctl logs                           # Stream live logs
flyctl logs --app tally-quest         # Specify app
```

## Secrets (env vars)

```bash
flyctl secrets list                   # List all secrets
flyctl secrets set KEY=value          # Set a secret
flyctl secrets deploy                 # Deploy staged secrets
flyctl secrets unset KEY              # Remove a secret
```

## Database (Postgres)

```bash
flyctl postgres list                  # List Postgres clusters
flyctl postgres connect -a <pg-app>   # Open psql shell
```

## SSH & Console

```bash
flyctl ssh console                    # SSH into the machine
flyctl ssh console -C "bin/rails console"      # Rails console
flyctl ssh console -C "bin/rails db:migrate"   # Run migrations manually
```

## Machines

```bash
flyctl machine list                   # List machines
flyctl machine restart <id>           # Restart a machine
flyctl scale count 1                  # Scale to N machines
flyctl scale show                     # Show current scale
```

## Domains & Certs

```bash
flyctl certs list                     # SSL certificates
flyctl certs add example.com          # Add custom domain
flyctl ips list                       # Allocated IPs
```

## Debugging

```bash
flyctl doctor                         # Diagnose common issues
flyctl ping                           # Check connectivity
```
