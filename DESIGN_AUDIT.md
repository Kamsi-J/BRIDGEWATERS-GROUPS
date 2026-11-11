# Bridge Waters Portal: AI-Slop Audit and Component Plan

Method: the `design-taste-frontend` skill from Finspire Intelligence V2 (Sections 4, 9, 11 and the Section 14 pre-flight list), applied to `index.html` (login) and `events.html` (portal). Component inventory taken from the 42 Material Design 3 screenshots in `design-inspiration/UI components`.

**Design read.** Redesign, overhaul of visuals with information architecture preserved. Internal executive and operations portal for a hotel group, quiet luxury language. Dials: `DESIGN_VARIANCE 5`, `MOTION_INTENSITY 3`, `VISUAL_DENSITY 5`. The skill lists dashboards as out of scope for its landing-page layouts, so only its universal rules (tells, type, colour, shape, states, copy) were applied to the app screens.

## 1. Audit findings (before)

| # | Tell | Evidence | Skill rule |
|---|------|----------|------------|
| 1 | Emoji used as UI | 59 emoji across both pages: nav feature tiles, toasts, hall badges, staff cards, theme toggle | 3.D, 9.E |
| 2 | Hand-rolled SVG icons | 18 inline `<svg>` icon paths, plus a drawn "BW" logo mark that is not the real logo | 3.C, 9.E |
| 3 | Em-dashes in visible copy | 25 (`Bridge Waters — Staff Portal`, `Approved — sent to cashier`, ...) | 9.G (zero allowed) |
| 4 | Default Tailwind "sky" palette | `#0ea5e9`, `#0284c7`, `#0369a1`, `#f0f9ff` are Tailwind sky-500/600/700/50, plus a blue gradient sidebar and login panel with decorative translucent circles | 4.2, 9.A |
| 5 | Card-in-card "double bezel" | Every stat, panel, calendar and staff block is a tinted outer box around a white inner box | 4.4 |
| 6 | Four identical stat cards | Same size, same anatomy, hover-lift on each | 9.C |
| 7 | Shape inconsistency | 19 different border-radius values on events.html (2px to 24px) | 4.4 shape lock |
| 8 | Colour inconsistency | 45 distinct hex values; five saturated hall/property colours (blue, violet, green, amber, red); violet "queried" status and button | 4.2 colour lock, Lila rule |
| 9 | Weight and label overuse | 34 uses of weight 800/900; 11 uppercase micro-labels (`stat-lbl`, `panel-ttl`, `req-sec-lbl`, `nav-sec-lbl`) on nearly every block | 4.7 eyebrow restraint |
| 10 | Browser dialogs | 3 `prompt()` and 3 `confirm()` for reject, query, delete, mark paid | 4.5 interactive states |
| 11 | Hover lift and glow everywhere | `translateY` plus blue glow shadows on stat cards, requisition cards, buttons | 9.A |
| 12 | Decorative dots and dot separators | 28 middle-dots, several per line; coloured dots on legends | 9.F (max 1 per line) |
| 13 | Generic marketing copy | Login: "Your workspace, all in one place.", "unified access to...", four icon-tile feature bullets | 9.D, 4.9 |
| 14 | Fake filled-track bars | Revenue bars on a grey track | 9.F scoring bars |
| 15 | Default map tiles | Stock OpenStreetMap tiles clash with the palette | 9.A |
| 16 | Modal for everything | Requisition detail (a working document) opens in a small centred modal | 4.5 |
| 17 | Placeholder data shown as fact | Hall capacities (500, 300, 400, 600, 200) and property coordinates are placeholders flagged in code comments | 9.D |

**Passes:** no pure black, no gradient text, no custom cursor, `100dvh` used, dark mode exists, reduced-motion respected, labels sit above inputs.
**Not slop but worth fixing:** Google Fonts loaded with `<link>` (skill prefers self-hosting for production); `Outfit` is on the skill's allowed list but is used at heavy weights throughout.

## 2. Component selection (from the 42 M3 screenshots)

Needed for this portal: 11 of the 22 M3 component families. Each is replaced with a bespoke version, not the Material default.

| M3 component | Used for | Bespoke replacement |
|---|---|---|
| Navigation drawer / rail | Sidebar | Persistent deep-ink rail on desktop, drawer on mobile; hairline active marker in logo azure; no filled pills |
| Top app bar | Page header | Serif page title, one quiet toolbar, no hamburger on desktop |
| Buttons (filled, tonal, outlined, text) | All actions | Two weights only: solid ink primary, hairline secondary; text-only destructive |
| Cards (elevated, filled, outlined) | Stats, panels | Removed. Ledger strips and hairline sections; one outlined container where grouping is needed |
| Lists and dividers | Requisition list, attention list, staff | Ledger rows with a single bottom hairline |
| Tabs (primary) | Requisition status | Underline tabs with counts |
| Chips | Status | Square 3px outlined status marks, sentence case, muted tones |
| Badges | Pending count on Requisitions nav item | Small count mark in azure |
| Side sheet / bottom sheet | Requisition detail | Right side sheet on desktop, bottom sheet on mobile |
| Dialog | Reject reason, query, confirm payment, delete | In-app dialog with serif title, replaces all `prompt()` and `confirm()` |
| Snackbar | Toasts | Ink bar, Phosphor icon, no emoji |
| Text fields | Forms | Hairline outlined fields with visible labels and focus ring |

Not needed: FAB, FAB menu, split buttons, extended FAB, segmented buttons, carousel, switch, checkbox, date picker (native date input kept), menus, toolbars, tooltips.

## 3. Design system (after)

- **Palette.** Cold luxury, from the real logo: deep ink `#0b1823`, porcelain canvas `#f4f6f8`, silver hairlines, one accent, Bridge Waters azure `#2ea6dc` (text-safe `#12709c`). Muted semantic tones for status only.
- **Type.** Cormorant Garamond for page titles and key figures (echoes the logo wordmark), Geist for everything else. Sentence case, no uppercase micro-labels.
- **Shape.** One radius: 3px.
- **Elevation.** Hairlines, no card shadows. One tinted shadow on the side sheet.
- **Icons.** Phosphor Light only.
- **Motion.** Sheet and dialog transitions, list entrance, state feedback. Nothing decorative.

## 4. Result (after the redesign)

| Tell | Before | After |
|---|---|---|
| Emoji in UI | 59 | 0 (Phosphor Light icons) |
| Hand-rolled SVG icons | 18 | 0 (one data-URI select arrow remains) |
| Em-dashes in visible copy | 25 | 0 |
| Middle-dot separators | 28 | 0 |
| `prompt()` / `confirm()` | 6 | 0 (in-app dialog) |
| Border-radius values (events.html) | 19 | 4: 3px everywhere, 2px calendar chips, 1px chart bars, 6px top corners of the mobile bottom sheet |
| Uppercase micro-labels | 11 | 0 |
| Weight 800/900 uses | 34 | 0 |
| Hover lift / glow effects | 4 | 0 |
| Card-in-card blocks | all stats, panels, calendar, staff | 0 (ledger strips, hairline sections, rows) |
| Saturated hall/property rainbow | 5 hues | 5 tones of one cool family |
| Violet "queried" status | yes | neutral outlined mark |
| Filled-track bars | yes | thin bars without a track |

## 5. Still open

1. **Placeholder data is still shown as fact.** Hall capacities (500, 300, 400, 600, 200) and the property map coordinates are placeholders from the original code. Supply real figures.
2. **No photography.** The login panel has a marked slot for a property photograph. The skill requires a real visual for a hero; none exists in the project.
3. **Fonts are loaded from Google Fonts via `<link>`.** The skill prefers self-hosting for production.
4. **Map tiles are stock OpenStreetMap, desaturated with CSS.** CARTO's light basemap now requires an API key, so it was not used.
5. **Not rendered with real data:** every screen was checked in the browser with mock records, and the dashboard also with the live (empty) database.

## 6. Dashboard revision

The first MD dashboard used editorial lists and hairline rows, so it read like a menu rather than an app. It was rebuilt as a panel grid:

- Four KPI tiles with a trend chip against last month and a six-month sparkline (none on phones).
- Revenue area chart (12 months), requisition status donut with a clickable legend, revenue-by-property bar chart (Chart.js 4.4.3).
- A "needs your attention" table with a Review button per row, an upcoming-events panel with date tiles, and a recent-activity panel.
- Panels are real bordered containers, because on a dashboard the grouping does carry hierarchy. The 3px radius, palette, type and icons are unchanged, and the other pages are untouched.
- Each chart has an empty state, and charts re-colour when the theme changes.
