# PROJECT MARKET — Permanent Codex Instructions

## Technical baseline

- Use Godot **4.7.1**, **GDScript**, and the **Forward+** renderer.
- Keep the project launchable from `project.godot`; do not introduce external plugins, paid assets, or unnecessary dependencies.
- Inspect the existing implementation before changing it. Reuse and extend current systems instead of rebuilding parallel versions.

## Product and design principles

- Prefer the smallest clear solution that proves the requested idea. Simple before complex; no premature frameworks, simulations, or generalized event buses.
- Implement only the requested scope. Do not add adjacent features, content, weapons, economies, or progression without an explicit request.
- Protect the validated priorities: movement, aim, shooting, dash, responsiveness, readable feedback, and overall game feel.
- Preserve the calm, stylized golden-hour direction: natural/desaturated colors, mostly matte materials, strong readable silhouettes, restrained emission, and brief effects for important actions. Avoid aggressive neon, cyan/magenta styling, excessive bloom, visual noise, and photorealism.

## Existing architecture

- `player/`: movement, mouse aim, dash/evasion, health, death/restart state, and follow camera.
- `combat/`: company security agents, their lightweight patrol/LOS/ranged-combat state machine, and health/destruction behavior.
- `weapons/` + `data/`: weapon behavior and data-driven resources.
- `effects/`: shared combat, destruction, and lightweight procedural audio feedback.
- `world/`: main scene/run coordinator, procedural arena, company facilities, physical equipment, physical extraction point, and `SecurityDirector` for local alerts. World objects emit facts; they never change stock prices or cash directly.
- `economy/`: one multi-company `MarketService` owns prices, positions, run cash, realized P&L and terminal settlement; `MarketDependency` describes cross-company reactions, and `ShortPosition` owns the pure P&L calculation.
- `ui/`: HUD/market views display service state; `RunResults` animates a detached settled statement. UI must not calculate or own economic state.
- Current economic boundary: `World / CompanyFacility -> Main coordinator -> Economy / MarketService -> UI`.
- Current security boundary: `CompanyFacility equipment attack -> SecurityDirector -> matching company agents + HUD`. Keep security local to the attacked company; it must not own or mutate market state.
- Current run boundary: `ExtractionPoint / player death -> Main -> MarketService settlement / forfeiture -> RunResults`. Extraction remains vulnerable until completion; only then stop combat.
- V1 run rule: every run starts with $10,000; opening shorts does not debit or credit cash. Closing realizes P&L into run-local cash. Death forfeits all run P&L (including manually closed gains), cancels positions and restores starting capital. Extraction settles at current displayed prices. No permanent cash carryover or meta progression.
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
```

- Also launch or render the real project in Godot 4.7.1 when the change can affect scenes, shaders, input, visuals, physics, or signals. Check for script, shader, signal, and runtime errors.
- A task is not complete because the code looks correct: verify it proportionally to risk and report what was actually run.

## Workflow and delivery

- Keep changes focused, preserve unrelated user work, and leave the working tree understandable.
- When a requested mission is genuinely complete and validated, create a clean commit and push the current branch to GitHub, unless the user explicitly asks not to push.
- Do not start a later product step without an explicit request.
