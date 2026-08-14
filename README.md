# PROJECT MARKET — Combat Playground

Première étape jouable du projet : mouvement indépendant de la visée, dash et SMG automatique dans une petite arène urbaine nocturne.

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

## Smoke test

```powershell
godot --headless --path . --script res://tests/playground_smoke_test.gd
```
