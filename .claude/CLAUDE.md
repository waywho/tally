# Tally - Project Conventions

## ViewComponent

Always use the Rails generator to scaffold new components, then modify the generated files:

```bash
bin/rails generate view_component:component NameComponent attr1 attr2 --sidecar --locale
```

Do not create component files manually from scratch.

## Controllers

Always use conventional CRUD actions (`index`, `show`, `new`, `create`, `edit`, `update`, `destroy`) as much as possible. Avoid custom action names when the behavior maps to a standard REST action.

## Acceptance

Always verify UI changes by clicking through the application using Playwright (`mcp__playwright__*` tools). After implementing a feature or fix, navigate to the relevant pages, interact with the UI, and confirm everything works as expected before considering the task complete.

## Commits

Always commit after completing each task. Do not batch multiple tasks into a single commit.
