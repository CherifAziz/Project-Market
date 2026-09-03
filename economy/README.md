# Economy

Prototype volontairement limité à VITA MEDICAL et ARC ENERGY, avec un short indépendant par entreprise et une seule dépendance explicite ARC → VITA.

`MarketService` est l'unique source de vérité pour les prix, positions, cash et P&L réalisé de la run. Il reçoit les événements du monde via `Main`, sans dépendre du joueur, des armes ou du rendu. `MarketDependency` fournit les réactions croisées en données ; `ShortPosition` conserve le calcul pur `(entry_price - current_price) × shares`.

## Compte de run

- Capital initial configurable : `$10,000`. Ouvrir un short ne touche pas au cash ; aucune marge, notion de collatéral, commission ou simulation du produit de vente.
- `close_short(company_id)` ferme au cours affiché, crédite/débite le cash et cumule le P&L réalisé de l'entreprise. Les doubles clôtures sont refusées ; une nouvelle position peut ensuite être ouverte.
- `settle_all_positions()` verrouille le compte, annule les réactions encore en attente et ferme toutes les positions au cours affiché à cet instant. Il retourne un relevé détaché pour l'UI. Un appel répété ne paie pas deux fois.
- `forfeit_run_profit()` verrouille le compte, annule toutes les positions et tous les P&L de la run, y compris déjà réalisés, puis restaure le capital initial. Une issue terminale ne peut pas être remplacée par l'autre.
- Un rechargement complet crée un nouveau compte ; aucun cash ne persiste entre les runs.

Frontière : `CompanyFacility / ExtractionPoint / player death → Main → MarketService → UI`. Le monde décide seulement des faits physiques et `Main` de l'issue de la run ; le service décide seul des montants. Le HUD distingue cash, unrealized P&L et realized P&L. L'extraction est nécessaire pour sécuriser le résultat final, même après une clôture manuelle.
