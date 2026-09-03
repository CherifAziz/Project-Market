# PROJECT MARKET — First Complete Run

Prototype jouable : **prendre des positions → saboter → survivre → extraire → réaliser les profits**. Mouvement indépendant de la visée, dash d'esquive et SMG automatique dans un quartier financier miniature en golden hour. VITA MEDICAL et ARC ENERGY disposent chacune d'une sécurité locale. La boucle systémique `ARC → VITA`, les prix, les armes et les quatre gardes restent ceux du playground validé.

## Lancer

Ouvrir `project.godot` avec Godot 4.7.1 puis lancer le projet avec `F5`. Le renderer attendu est **Forward+**. Aucun plugin ou asset externe nécessaire.

## Contrôles

- `WASD` ou `ZQSD` : déplacement
- Souris : visée
- Clic gauche maintenu : tir automatique
- `Espace` ou `Maj` : dash
- `E` maintenu 2,2 secondes dans la zone **SERVICE EXIT** : extraire
- `R` ou bouton **NEW RUN** sur le résultat : nouvelle run complète
- `M` : ouvrir / fermer le marché ; boutons **SHORT** et **CLOSE** indépendants pour VITA / ARC (combat temporairement suspendu, comme auparavant)
- `Échap` : libérer/capturer la souris

## Jouer une run

Ouvrir les deux shorts avant sabotage (`300` actions chacun), attaquer ARC, combattre/esquiver ses gardes et détruire les trois équipements. Une fois les réactions terminées : ARC passe de `$64` à `$35` (`+$8,700`) et VITA de `$42` à `$38` (`+$1,200`) par dépendance énergétique.

La première attaque d'un équipement déverrouille la sortie de service au sud-est du quartier. Le HUD indique sa direction et sa distance. Rejoindre la zone, rester immobile et maintenir `E` : déplacement, dash, dégâts, relâchement ou ouverture du marché annulent la progression. Les gardes restent actifs et le joueur vulnérable pendant l'interaction.

L'extraction ferme les positions restantes **aux prix affichés à cet instant**, arrête la run et présente le détail VITA / ARC, le profit total puis le nouveau cash avec des compteurs animés. Attendre la fin des réactions ARC permet d'obtenir **+$9,900 réalisés**, soit **$19,900** de cash final. Extraire plus tôt peut produire moins de profit.

## Cash, positions et risque V1

- Chaque nouvelle run commence avec **$10,000**. Aucun capital ne persiste entre les runs.
- **Cash** : capital initial + P&L déjà réalisé dans cette run. Ouvrir un short ne crée ni ne dépense de cash ; pas de marge, levier, frais ou vente à découvert réaliste.
- **Unrealized P&L** : gain/perte latent des positions encore ouvertes, jamais ajouté au cash avant clôture.
- **Realized P&L** : gain/perte cumulé des positions fermées, par entreprise et au total. Une clôture manuelle permet de rouvrir un short au nouveau prix ; elle ne termine pas la run.
- **Mort avant extraction** : tous les P&L de la run sont annulés, y compris les gains déjà fermés ; les positions sont supprimées et le capital initial restauré. Il faut extraire pour sécuriser le résultat de la run. Cette règle est affichée dans le marché et sur l'écran d'échec.

Cette version conserve deux entreprises, trois équipements et deux gardes par installation, 100 PV joueur et une seule arme. Pas de troisième entreprise, nouvel ennemi, loot, boutique, progression permanente ou simulation générique de supply chain.

## Architecture

- `player/` : locomotion, visée, dash invulnérable, santé/mort et caméra de suivi
- `weapons/` + `data/` : comportement de tir et réglages d’armes en ressources `.tres`
- `combat/` : agents de sécurité stylisés et petite machine à états patrouille/engagement/tir
- `effects/` : feedback visuel, hitstop, camera shake et premiers sons procéduraux mutualisés
- `world/` : arène, installations VITA / ARC, directeur des alertes locales et extraction physique ; `Main` coordonne les états `ACTIVE / EXTRACTED / FAILED`
- `economy/` : `MarketService` unique pour prix, positions, cash et règlement ; `ShortPosition` conserve le calcul pur du P&L
- `ui/` : HUD, réticule, vues marché et relevé de résultat animé ; aucun calcul économique dans l'UI
- `data/` : définitions réutilisables des armes, entreprises et de la dépendance explicite `ARC → VITA`

## Direction visuelle

Le playground utilise une palette naturelle et désaturée : pierre chaude, béton, asphalte, verre teinté, terre cuite et végétation. La lumière de golden hour, les ombres longues et les matériaux majoritairement mats donnent une lecture de diorama architectural. L'émission et le glow sont réservés aux actions de combat brèves.

Les réglages les plus directs sont regroupés dans :

- `world/main.gd` : exposition, lumière ambiante, saturation, SSAO et glow
- `world/main.tscn` : angle, couleur et énergie du soleil
- `world/arena_builder.gd` : palette des matériaux et composition urbaine
- `player/player.tscn` et `combat/security_agent.tscn` : couleurs et silhouettes de lecture des personnages
- `data/starter_smg.tres` et `effects/effects_service.gd` : couleurs et intensité des VFX ponctuels

Les fichiers centraux de cette passe sont `economy/market_service.gd`, `world/extraction_point.gd/.tscn`, `world/main.gd`, `ui/run_results.gd/.tscn`, les vues `ui/market_*` et `ui/money_format.gd`.

## Validation

```powershell
godot --headless --path . --script res://tests/playground_smoke_test.gd
godot --headless --path . --script res://tests/market_logic_test.gd
godot --headless --path . --script res://tests/market_flow_test.gd
godot --headless --path . --script res://tests/security_flow_test.gd
godot --headless --path . --script res://tests/run_account_test.gd
godot --headless --path . --script res://tests/run_flow_test.gd
```

Les tests couvrent les systèmes précédents, le cash/P&L signé, les clôtures indépendantes, l'absence de double paiement, le règlement pendant une transition de prix, la perte des gains, l'interaction vulnérable et le reset réel de scène. Le scénario complet a aussi été exécuté dans Godot 4.7.1 **Forward+** avec déplacements, visée/tirs SMG et dash : trois machines ARC détruites, garde poursuivant jusqu'à la sortie et interrompant `E` par un tir, puis extraction à `$19,900` et nouvelle run.

## Placeholders / limites

Géométrie, personnages, animations, borne d'extraction et audio restent procéduraux. La sécurité utilise des raycasts et de courts contournements locaux, sans navigation générale. L'ouverture du marché suspend encore le combat mais annule toute extraction en cours. Les résultats sont propres à chaque run, sans sauvegarde ou progression permanente.
