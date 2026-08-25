# Tally - Project Conventions

## Comments

Do not add comments. The only exception is something genuinely surprising — a
hidden constraint, a workaround for a specific bug, a non-obvious invariant.
Applies to every file type, not just code: Ruby, Swift, HAML, plists, configs.

Never comment to restate what the code does, to explain a standard framework
idiom, or to narrate the change being made — that belongs in the commit message.

Push to `main` triggers automatic deployment to Fly.io. Do not use `flyctl deploy` — merge and push instead.

## ViewComponent

Use the Rails generator to scaffold new components:

```bash
bin/rails generate view_component:component NameComponent attr1 attr2 --sidecar --locale
```
