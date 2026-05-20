# Tally - Project Conventions

## Deployment

Push to `main` triggers automatic deployment to Fly.io. Do not use `flyctl deploy` — merge and push instead.

## ViewComponent

Use the Rails generator to scaffold new components:

```bash
bin/rails generate view_component:component NameComponent attr1 attr2 --sidecar --locale
```
