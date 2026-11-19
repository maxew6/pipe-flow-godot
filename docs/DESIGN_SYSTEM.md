# PIPE FLOW design system

Single source of truth: `scripts/ui/design_system.gd` (class `DS`). `UiKit` re-exports the colours for old code.

**Palette** - forest green (FOREST/FOREST_DARK), sky blue (SKY), aqua water (AQUA, AQUA_DEEP, AQUA_LIGHT),
warm wood (WOOD_DARK/WOOD/WOOD_LIGHT), stone beige (STONE/STONE_DARK), parchment + ink for text panels,
gold (GOLD/GOLD_DARK) only for stars and rewards. Difficulty accents: EASY green, HARD amber, EXTREME red.

**Typography** - display: Erica One (logo, big headings). UI/body: Outfit Bold (theme default font, set once in `Nav`).
Scale: 84 display / 64 title / 52 heading / 40 body / 30 small / 68 primary button / 56 button.
Text on art uses a dark outline of 8 px in the button's own dark tone.

**Spacing** - 8 / 16 / 24 / 36 / 56 (`SP_XS..SP_XL`). Screen side margin 28-40.

**Components** (one implementation each)
- `GameButton` - kinds green (primary), blue (utility), wood (navigation); heights 200 / 164 / 110; min touch target 96.
  States: normal, hover (+7%), pressed (-18% and 94% scale), disabled (dimmed).
- `UiKit.wood_panel()` / `UiKit.parchment_panel()` - 9-slice textured panels.
- `StarRow` - textured stars. `IconGlyph` - icon textures. `ToggleSwitch` - settings switch.
- `MenuStage` - illustrated backdrop with cover scaling (never stretched).

**Motion** - fast 0.12 s, base 0.25 s, slow 0.45 s; back-out easing for pop-ins, sine for ambient sway.

**Shadow/highlight rule** - baked into the textures: one soft drop shadow, one top highlight, no stacked shadows.
