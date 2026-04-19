# Tally - Project Conventions

## ViewComponent

Always use the Rails generator to scaffold new components, then modify the generated files:

```bash
bin/rails generate view_component:component NameComponent attr1 attr2 --sidecar --locale
```

Do not create component files manually from scratch.
