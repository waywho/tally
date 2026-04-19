# Tally - Project Conventions

## ViewComponent

Always use the Rails generator to scaffold new components, then modify the generated files:

```bash
bin/rails generate view_component:component NameComponent attr1 attr2 --sidecar --locale
```

Do not create component files manually from scratch.

## Testing

For all frontend views and templates, always write a Capybara system test to verify the user-facing behavior (page renders, form submissions, navigation flows).

## Commits

Always commit after completing each task. Do not batch multiple tasks into a single commit.
