# PROJECT MARKET — Combat Playground

Première étape jouable du projet : mouvement indépendant de la visée, dash et SMG automatique dans un quartier financier miniature en fin d'après-midi.

## Lancer

Ouvrir `project.godot` avec Godot 4.7.1 puis lancer le projet (`F6`/`F5`). Le renderer attendu est **Forward+**.

## Contrôles

- `WASD` ou `ZQSD` : déplacement
- Souris : visée
- Clic gauche maintenu : tir automatique
- `Espace` ou `Maj` : dash
- `R` : recharger la scène
- `Échap` : libérer/capturer la souris

## Périmètre

Cette version ne contient volontairement ni économie, ni trading, ni progression roguelite. Le dossier `economy/` réserve seulement la frontière du futur module.

## Architecture

- `player/` : locomotion, visée, dash et caméra de suivi
- `weapons/` + `data/` : comportement de tir et réglages d’armes en ressources `.tres`
- `combat/` : cibles, points de vie et destruction
- `effects/` : feedback visuel, hitstop et camera shake
- `world/` : scène principale, éclairage et construction procédurale de l’arène
- `ui/` : HUD, réticule et overlay d’écran
- `economy/` : frontière réservée, sans implémentation à cette étape

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
```
