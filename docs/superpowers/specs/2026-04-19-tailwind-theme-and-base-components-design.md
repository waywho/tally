# Ticket 5: Tailwind Theme + Design Tokens + Base Components

## Visual Direction

Warm & friendly with clean edges. Minimalist — a calm counterpoint to MyFitnessPal's density.

- **Palette:** "Garden" — green primary, stone neutrals
- **Rounding:** Subtle (6px / `rounded-md`)
- **Typography:** System fonts (`-apple-system`, SF Pro on iOS, system-ui fallback)
- **Calorie progress:** Horizontal progress bar with eaten/target, remaining count, macro summary (P/C/F/Fiber)

## Color Tokens

Defined in `app/assets/tailwind/application.css` using Tailwind v4 `@theme` syntax.

| Token | Value | Usage |
|---|---|---|
| `--color-primary` | `#16A34A` (green-600) | Buttons, progress bar fill, active states |
| `--color-primary-light` | `#4ADE80` (green-400) | Hover states, secondary accents |
| `--color-primary-muted` | `#BBF7D0` (green-200) | Borders on tinted containers |
| `--color-primary-tint` | `#F0FDF4` (green-50) | Tinted backgrounds (bucket headers, badges) |
| `--color-text` | `#1C1917` (stone-900) | Primary text |
| `--color-text-secondary` | `#78716C` (stone-500) | Secondary/muted text |
| `--color-bg` | `#FFFFFF` | Card backgrounds |
| `--color-bg-page` | `#F5F5F4` (stone-100) | Page background |
| `--color-border` | `#E7E5E4` (stone-300) | Default borders |

## Spacing & Layout

Use Tailwind's default spacing scale. Key conventions:

- Page padding: `px-4` (16px) on mobile
- Card padding: `p-4` (16px)
- Gap between cards/sections: `gap-4` (16px)
- List row padding: `px-4 py-3` (16px / 12px)
- Component internal spacing: `gap-2` or `gap-3`

## Base Components

All built as ViewComponents in `app/components/`. Each has a Lookbook preview in `test/components/previews/`.

### 1. ButtonComponent

Renders a styled button or link.

**Params:**
- `label` (String) — button text
- `scheme` (Symbol) — `:primary` (green-600 bg, white text) or `:secondary` (white bg, green-600 border + text)
- `size` (Symbol) — `:sm` or `:md` (default)
- `tag` (Symbol) — `:button` (default) or `:a`
- `**system_arguments` — passed through (href, data attributes, etc.)

**Rendering:** Inline Tailwind classes, no separate CSS. `rounded-md` on all sizes.

### 2. CardComponent

Content container with white background, border, and rounded corners. Yields a content block.

**Params:**
- `**system_arguments` — passed through

**Default classes:** `bg-white border border-border rounded-md overflow-hidden`

### 3. ListRowComponent

A single row inside a meal bucket or search result list. Displays a label on the left and a value on the right.

**Params:**
- `label` (String) — food name or description
- `value` (String) — calorie display (e.g., "320 cal")
- `**system_arguments` — passed through

**Rendering:** `flex justify-between items-center px-4 py-3`, with a `border-b border-border` (except last child via `last:border-b-0`). Label in `text-text`, value in `text-primary font-semibold`.

### 4. BucketHeaderComponent

Header row for a meal bucket (Breakfast, Lunch, Dinner, Snacks).

**Params:**
- `meal` (String) — meal name
- `subtotal` (Integer) — calories in this bucket
- `add_path` (String) — URL for the "+ Add" link

**Rendering:** `bg-primary-tint px-4 py-3 flex justify-between items-center`. Meal name in `font-semibold text-primary text-sm`. Subtotal as muted text. "+ Add" as a small green link on the right.

### 5. CaloriePillComponent

The daily progress summary shown at the top of the Today view.

**Params:**
- `eaten` (Integer) — calories consumed today
- `target` (Integer) — daily calorie goal
- `protein` (String) — e.g., "28g / 150g"
- `carbs` (String) — e.g., "52g / 250g"
- `fat` (String) — e.g., "12g / 67g"
- `fiber` (String) — e.g., "8g / 30g"

**Rendering:** Wrapped in a CardComponent. Top row: large eaten number, "/ {target} cal" muted, remaining count right-aligned in green. Below: 8px-tall green progress bar (`rounded` inner). Bottom row: four macro labels in `text-xs text-text-secondary` (P / C / F / Fiber).

**Edge case — over target:** When eaten > target, progress bar fills 100% and turns `red-500`. Remaining text changes to "{over} over" in red.

## Lookbook Setup

Add `lookbook` gem to `:development` group. Mount in routes behind a development guard.

Preview classes live in `test/components/previews/` and show each component with realistic calorie-tracking data:
- ButtonComponent: primary + secondary, both sizes
- CardComponent: with sample content
- ListRowComponent: 2-3 food items in a card
- BucketHeaderComponent: "Breakfast — 470 cal — + Add"
- CaloriePillComponent: normal state (470/2000) and over-target state (2150/2000)

## Files to Create/Modify

| File | Action |
|---|---|
| `app/assets/tailwind/application.css` | Add `@theme` block with color tokens |
| `app/components/button_component.rb` + `.html.erb` | Create |
| `app/components/card_component.rb` + `.html.erb` | Create |
| `app/components/list_row_component.rb` + `.html.erb` | Create |
| `app/components/bucket_header_component.rb` + `.html.erb` | Create |
| `app/components/calorie_pill_component.rb` + `.html.erb` | Create |
| `test/components/previews/*_preview.rb` (x5) | Create |
| `Gemfile` | Add `lookbook` to `:development` |
| `config/routes.rb` | Mount Lookbook engine in development |
| `app/views/layouts/application.html.erb` | Update body bg to `bg-bg-page`, add flash messages |

## Out of Scope

- Rodauth view styling (ticket 6)
- Dark mode
- Responsive breakpoints beyond mobile-first defaults
- Animation / transitions
