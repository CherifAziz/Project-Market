# PROJECT MARKET — Permanent Codex Instructions

## Technical baseline

- Use Godot **4.7.1**, **GDScript**, and the **Forward+** renderer.
- Keep the project launchable from `project.godot`; do not introduce external plugins, paid assets, or unnecessary dependencies.
- Inspect the existing implementation before changing it. Reuse and extend current systems instead of rebuilding parallel versions.

## Product and design principles

- Prefer the smallest clear solution that proves the requested idea. Simple before complex; no premature frameworks, simulations, or generalized event buses.
- Implement only the requested scope. Do not add adjacent features, content, weapons, economies, or progression without an explicit request.
- Protect the validated priorities: movement, aim, shooting, dash, responsiveness, readable feedback, and overall game feel.
- Prioritize immediate visual comprehension: communicate through silhouettes, icons and contextual feedback. Avoid mechanics requiring explanatory text, verbose HUDs, or additional commands without necessity.
- Preserve the calm, stylized golden-hour direction: natural/desaturated colors, mostly matte materials, strong readable silhouettes, restrained emission, and brief effects for important actions. Avoid aggressive neon, cyan/magenta styling, excessive bloom, visual noise, and photorealism.

## Existing architecture

- `player/`: movement, mouse aim, dash/evasion, health, follow camera, and proximity/LOS loot interaction. Cargo never changes movement or dash.
- `combat/`: company security agents, their lightweight patrol/LOS/ranged-combat state machine, and health/destruction behavior.
- `weapons/` + `data/`: weapon behavior and data-driven resources.
- `effects/`: shared combat, destruction, and lightweight procedural audio feedback.
- `world/`: main/run coordinator, arena, company facilities/equipment, authored `LootPickup` objects, extraction point, and local `SecurityDirector`. World objects emit facts; they never change prices or cash directly.
- `inventory/`: one three-slot `RunInventory` owns unique manifests and atomic, slot-preserving exchanges. One object = one slot. `data/loot/` defines fixed names, values and visual identities; no weight, bulk, random loot or equipment system.
- `economy/`: one `MarketService` owns prices, positions, run cash and settlement (market profit and loot sale kept separate); `MarketDependency` describes cross-company reactions, and `ShortPosition` owns pure P&L math.
- `ui/`: HUD/market views display service state; `RunResults` animates a detached settled statement. UI must not calculate or own economic state.
- Current economic boundary: `World / CompanyFacility -> Main coordinator -> Economy / MarketService -> UI`.
- Current security boundary: `CompanyFacility equipment attack -> SecurityDirector -> matching company agents + HUD`. Keep security local to the attacked company; it must not own or mutate market state.
- Current run boundary: `ExtractionPoint / player death -> Main -> MarketService settlement / forfeiture -> RunResults`. Extraction remains vulnerable until completion; only then stop combat.
- Loot boundary: `LootInteractor request -> Main -> RunInventory -> HUD`; only extraction passes the manifest to `MarketService` for sale. Replaced objects return to the incoming object's reachable location; never clone IDs or reorder unaffected slots.
- Cargo UX: three compact silhouette/value slots only. Nearby loot shows price + E; when full, aim at reachable loot and press 1/2/3 to replace that slot directly. No inspection menu, separate drop command, persistent instructions or visible categories.
- Market and loot interactions remain live. The market immobilizes combat controls, never guards or damage. Only terminal run outcomes disable security.
- V1 run rule: start at $10,000; opening shorts does not change cash. Closing realizes run-local P&L. Death loses all cargo and run P&L (even closed gains), cancels positions and restores starting capital. Extraction settles shorts at displayed prices and sells carried assets once. No permanent cash carryover or meta progression.
- Keep these boundaries explicit and avoid circular dependencies. In particular, combat/weapons must not know about the market, and economy must not depend on the player or rendering.

## Validation requirements

- Preserve and extend existing tests when behavior changes; never weaken assertions merely to make a change pass.
- Run all current suites before considering work complete:

```powershell
godot --headless --path . --script res://tests/playground_smoke_test.gd
godot --headless --path . --script res://tests/market_logic_test.gd
godot --headless --path . --script res://tests/market_flow_test.gd
godot --headless --path . --script res://tests/security_flow_test.gd
godot --headless --path . --script res://tests/run_account_test.gd
godot --headless --path . --script res://tests/run_flow_test.gd
godot --headless --path . --script res://tests/loot_logic_test.gd
godot --headless --path . --script res://tests/loot_flow_test.gd
godot --headless --path . --script res://tests/audio_lifecycle_test.gd
```

- Also launch or render the real project in Godot 4.7.1 when the change can affect scenes, shaders, input, visuals, physics, or signals. Check for script, shader, signal, and runtime errors.
- A task is not complete because the code looks correct: verify it proportionally to risk and report what was actually run.
- Scene tests use `SceneCleanup.free_scene` and assert success before quitting. It observes actual node/stream/playback release across the asynchronous audio mixer; do not replace this with suppressed warnings or disabled audio.

## Workflow and delivery

- Keep changes focused, preserve unrelated user work, and leave the working tree understandable.
- When a requested mission is genuinely complete and validated, create a clean commit and push the current branch to GitHub, unless the user explicitly asks not to push.
- Do not start a later product step without an explicit request.
