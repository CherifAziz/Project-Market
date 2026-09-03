# PROJECT MARKET — Combat Playground

Prototype jouable : mouvement indépendant de la visée, dash et SMG automatique dans un quartier financier miniature en fin d'après-midi. La boucle systémique relie désormais les installations physiques de VITA MEDICAL et ARC ENERGY à leurs cours, avec une dépendance énergétique explicite `ARC → VITA`.

## Lancer

Ouvrir `project.godot` avec Godot 4.7.1 puis lancer le projet (`F6`/`F5`). Le renderer attendu est **Forward+**.

## Contrôles

- `WASD` ou `ZQSD` : déplacement
- Souris : visée
- Clic gauche maintenu : tir automatique
- `Espace` ou `Maj` : dash
- `R` : recharger la scène
- `M` : ouvrir / fermer le marché (désactive temporairement les contrôles de combat)
- `Échap` : libérer/capturer la souris

## Périmètre

Cette version contient VITA MEDICAL et ARC ENERGY, trois équipements critiques par installation et une position `SHORT ×300` indépendante par entreprise. Saboter ARC affecte directement ARC puis légèrement VITA via sa dépendance énergétique. Elle ne contient volontairement aucune simulation générique de supply chain, gestion de cash, position longue ou progression roguelite.

## Architecture

- `player/` : locomotion, visée, dash et caméra de suivi
- `weapons/` + `data/` : comportement de tir et réglages d’armes en ressources `.tres`
- `combat/` : cibles, points de vie et destruction
- `effects/` : feedback visuel, hitstop, camera shake et premiers sons procéduraux mutualisés
- `world/` : scène principale, arène et installations VITA / ARC ; le monde émet des faits de destruction
- `economy/` : registre multi-entreprise unique, séquençage des réactions et calcul pur des positions short
- `ui/` : HUD, réticule et vues marché réutilisables par entreprise ; aucun calcul économique dans l’UI
- `data/` : définitions réutilisables des armes, entreprises et de la dépendance explicite `ARC → VITA`

## Direction visuelle

Le playground utilise une palette naturelle et désaturée : pierre chaude, béton, asphalte, verre teinté, terre cuite et végétation. La lumière de golden hour, les ombres longues et les matériaux majoritairement mats donnent une lecture de diorama architectural. L'émission et le glow sont réservés aux actions de combat brèves.

Les réglages les plus directs sont regroupés dans :

- `world/main.gd` : exposition, lumière ambiante, saturation, SSAO et glow
- `world/main.tscn` : angle, couleur et énergie du soleil
- `world/arena_builder.gd` : palette des matériaux et composition urbaine
- `player/player.tscn` et `combat/damageable_target.tscn` : couleurs de lecture des personnages
- `data/starter_smg.tres` et `effects/effects_service.gd` : couleurs et intensité des VFX ponctuels

## Smoke test

```powershell
godot --headless --path . --script res://tests/playground_smoke_test.gd
godot --headless --path . --script res://tests/market_logic_test.gd
godot --headless --path . --script res://tests/market_flow_test.gd
```
