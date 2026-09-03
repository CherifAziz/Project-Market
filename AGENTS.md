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
- `world/`: main scene, procedural arena, company facilities, physical equipment, and `SecurityDirector` for local company alerts. World objects report facts through signals; they do not change stock prices directly.
- `economy/`: one multi-company `MarketService` is the economic source of truth; `MarketDependency` data describes explicit cross-company reactions, and `ShortPosition` owns the pure P&L calculation.
- `ui/`: HUD and market views display state from services; UI must not calculate or own economic state.
- Current economic boundary: `World / CompanyFacility -> Main coordinator -> Economy / MarketService -> UI`.
- Current security boundary: `CompanyFacility equipment attack -> SecurityDirector -> matching company agents + HUD`. Keep security local to the attacked company; it must not own or mutate market state.
- Keep these boundaries explicit and avoid circular dependencies. In particular, combat/weapons must not know about the market, and economy must not depend on the player or rendering.

## Validation requirements

- Preserve and extend existing tests when behavior changes; never weaken assertions merely to make a change pass.
- Run all current suites before considering work complete:

```powershell
godot --headless --path . --script res://tests/playground_smoke_test.gd
godot --headless --path . --script res://tests/market_logic_test.gd
godot --headless --path . --script res://tests/market_flow_test.gd
godot --headless --path . --script res://tests/security_flow_test.gd
```

- Also launch or render the real project in Godot 4.7.1 when the change can affect scenes, shaders, input, visuals, physics, or signals. Check for script, shader, signal, and runtime errors.
- A task is not complete because the code looks correct: verify it proportionally to risk and report what was actually run.

## Workflow and delivery

- Keep changes focused, preserve unrelated user work, and leave the working tree understandable.
- When a requested mission is genuinely complete and validated, create a clean commit and push the current branch to GitHub, unless the user explicitly asks not to push.
- Do not start a later product step without an explicit request.
