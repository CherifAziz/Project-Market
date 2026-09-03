# Economy

Prototype économique volontairement limité à une entreprise et une position short.

`MarketService` est la source de vérité pour le prix courant et le P&L. Il reçoit les événements du monde via le coordinateur de la scène principale, sans dépendre du joueur, des armes ou du rendu. `ShortPosition` porte uniquement le calcul financier pur.
