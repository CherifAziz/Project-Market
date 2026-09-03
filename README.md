# PROJECT MARKET — Sabotage, Cargo & Extraction

Prototype jouable : **prendre des positions → saboter → combattre → voler et choisir sa cargaison → extraire → réaliser les profits**. Mouvement indépendant de la visée, dash d'esquive et SMG automatique dans un quartier financier miniature en golden hour. VITA MEDICAL et ARC ENERGY conservent chacune leur sécurité locale. La dépendance `ARC → VITA`, les prix, l'arme et les quatre gardes sont inchangés.

## Lancer

Ouvrir `project.godot` avec Godot 4.7.1 puis lancer le projet avec `F5`. Le renderer attendu est **Forward+**. Aucun plugin ou asset externe nécessaire.

## Contrôles

- `WASD` ou `ZQSD` : déplacement
- Souris : visée
- Clic gauche maintenu : tir automatique
- `Espace` ou `Maj` : dash
- `E` près d'un objet : ramasser dans une place libre
- Sac plein : viser un objet à portée, puis `1`, `2` ou `3` (rangée supérieure) pour remplacer directement le slot correspondant
- `E` maintenu 2,2 secondes dans la zone **SERVICE EXIT** : extraire
- `R` ou bouton **NEW RUN** sur le résultat : nouvelle run complète
- `M` : marché de terrain latéral ; **SHORT** et **CLOSE** par entreprise. Le joueur reste immobile, mais les gardes continuent à se déplacer et tirer. `M` / `Échap` rend immédiatement les contrôles de combat.
- `Échap` : libérer/capturer la souris

## Jouer une run

Ouvrir les deux shorts avant sabotage (`300` actions chacun), attaquer ARC, combattre/esquiver ses gardes et détruire les trois équipements. Une fois les réactions terminées : ARC passe de `$64` à `$35` (`+$8,700`) et VITA de `$42` à `$38` (`+$1,200`) par dépendance énergétique.

La première attaque d'un équipement déverrouille la sortie de service au sud-est du quartier. Le HUD indique sa direction et sa distance. Rejoindre la zone, rester immobile et maintenir `E` : déplacement, dash, dégâts, relâchement ou ouverture du marché annulent la progression. Les gardes restent actifs et le joueur vulnérable pendant l'interaction.

L'extraction ferme les positions restantes **aux prix affichés à cet instant**, arrête la run et présente le détail VITA / ARC, le profit total puis le nouveau cash avec des compteurs animés. Attendre la fin des réactions ARC permet d'obtenir **+$9,900 réalisés**, soit **$19,900** de cash final. Extraire plus tôt peut produire moins de profit.

## Loot — trois objets, trois icônes

Le HUD montre uniquement trois silhouettes avec leur prix court. Aucun poids, ralentissement, catégorie visible, menu d'inspection ou commande de dépôt. À portée et en ligne de vue : prix + `E`. Sac plein : viser le loot révèle les trois slots numérotés ; `1/2/3` remplace directement le slot choisi. L'objet remplacé réapparaît au même endroit et reste récupérable. Les autres slots ne bougent pas.

Six objets fixes, plus grands et dégagés dans les allées gardées, ont chacun une silhouette et une palette distinctes :

- Prototype VITA : mallette ivoire / croix rouge brique — `$4,800`.
- Analyseur : instrument bleu en L — `$3,600`.
- Échantillons : deux flacons ivoire / violet sourd — `$1,600`.
- Module ARC : bloc ocre à ailettes — `$7,200`.
- Bobine : cuivre roux entre deux disques — `$2,600`.
- Composant énergétique : trois isolateurs verts — `$3,000`.

**Un objet occupe toujours un slot**, même le module ARC. Ramassage : contraction rapide de l'objet, icône vers le slot et son bref réutilisé. Pas de glow permanent. Les valeurs et le service financier restent inchangés.

La cargaison n'est vendue qu'à l'extraction. Exemple avec module + prototype + composant : **MARKET PROFIT +$9,900 / STOLEN ASSETS +$15,000 / RUN PROFIT +$24,900 / NEW NET CASH $34,900**. Le relevé nomme les trois objets vendus. Le premier sabotage d'équipement reste nécessaire pour débloquer la sortie.

## Cash, positions et risque V1

- Chaque nouvelle run commence avec **$10,000**. Aucun capital ne persiste entre les runs.
- **Cash** : capital initial + P&L déjà réalisé + vente du loot à l'extraction. Ouvrir un short ne crée ni ne dépense de cash ; pas de marge, levier, frais ou vente à découvert réaliste.
- **Unrealized P&L** : gain/perte latent des positions encore ouvertes, jamais ajouté au cash avant clôture.
- **Realized P&L** : gain/perte cumulé des positions fermées, par entreprise et au total. Une clôture manuelle permet de rouvrir un short au nouveau prix ; elle ne termine pas la run.
- **Mort avant extraction** : toute la cargaison est perdue et tous les P&L de la run sont annulés, même déjà fermés ; les positions sont supprimées et le capital initial restauré. Cette règle est affichée dans les overlays et sur l'écran d'échec.

Cette version conserve deux entreprises, trois équipements et deux gardes par installation, 100 PV joueur et une seule arme. Pas de troisième entreprise, nouvel ennemi, boutique, upgrades, progression permanente ou simulation générique de supply chain.

## Architecture

- `player/` : locomotion, visée, dash invulnérable, santé/mort et caméra de suivi
- `inventory/` : manifeste unique du sac de run, capacité et échanges directs conservant l'ordre des slots ; aucune modification de cash
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

Loot : `data/loot_definition.gd` + `data/loot/*.tres`, `world/loot_pickup.gd/.tscn`, `player/loot_interactor.gd`, `inventory/run_inventory.gd` et `ui/inventory_hud.gd/.tscn`. `Main` coordonne les événements physiques ; `MarketService` conserve seul le règlement financier. `RunResults` présente un relevé détaché, jamais un calcul UI.

## Validation

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

Les tests couvrent les systèmes précédents, le cash/P&L signé, les clôtures indépendantes, l'absence de double paiement, le règlement pendant une transition de prix, la perte des gains, l'interaction vulnérable et le reset réel de scène. Le scénario complet a aussi été exécuté dans Godot 4.7.1 **Forward+** avec déplacements, visée/tirs SMG et dash : trois machines ARC détruites, garde poursuivant jusqu'à la sortie et interrompant `E` par un tir, puis extraction à `$19,900` et nouvelle run.

La refonte visuelle du loot est validée en **Forward+ Vulkan** avec captures inspectées à 1280×720 : deux shorts, tir de garde reçu avec marché ouvert, combat SMG dans ARC et VITA, sabotage ARC, trois objets ARC ramassés via `E`, puis remplacement direct de la bobine par le prototype avec `2`. Le retour, l'extraction à `$34,900` et le reset complet sont vérifiés sans soin, téléportation ni désactivation des gardes dans ce scénario graphique. La reconnaissance repose sur les six formes/couleurs, pas sur des noms, catégories ou instructions affichés.

Les tests couvrent aussi les trois indices de remplacement, l'ordre des slots, les échanges répétés sans duplication, portée/LOS, absence d'action sur E quand le sac est plein, touches hors contexte, vitesse réelle inchangée, vente séparée/idempotente, mort et reset. Les anciennes assertions de poids/encombrement sont remplacées par celles du nouveau contrat demandé ; les tests financiers restent intacts.

### Diagnostic ObjectDB

Reproduit avant correction : 3–4 objets signalés à la fermeture du smoke test, uniquement `AudioStreamWAV` / `AudioStreamPlaybackWAV`. Une sonde a constaté quatre références encore vivantes après suppression des nodes, puis zéro après 96 ms de traitement audio. Le processus de test quittait après seulement deux frames, avant la libération asynchrone du mixer. Le [code d'AudioServer](https://github.com/godotengine/godot/blob/master/servers/audio/audio_server.cpp) confirme que `stop_playback_stream` demande une suppression différée.

`tests/scene_cleanup.gd` observe désormais les références faibles des nodes, streams et playbacks jusqu'à leur libération réelle, avec délai maximal et assertion d'échec. Aucun warning masqué, audio désactivé ou attente arbitraire à la place d'une vérification. Le test `audio_lifecycle_test.gd` répète cinq fermetures pendant des sons actifs ; cinq smoke tests consécutifs ont aussi terminé sans warning. Cela corrige le teardown de nos tests, pas le moteur Godot ni tous ses modes de fermeture forcée.

## Placeholders / limites

Géométrie, personnages, animations, objets de valeur et audio restent procéduraux. Le loot reste procédural, posé au sol, sans lancer/chute en rigid-body ni équipement porté visible. La sécurité utilise une navigation locale simple. Le marché immobilise le joueur et annule l'extraction, sans arrêter le danger ; les trois slots sont visibles sans commande d'inspection. Les résultats restent propres à chaque run, sans sauvegarde, génération aléatoire ou progression permanente.
