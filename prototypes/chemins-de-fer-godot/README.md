# Chemins de fer — la tranche Godot

Un jeu de gestion ferroviaire sur une grille octogonale : un dépôt au centre,
des ressources autour, une ville cachée à 8 cases qui seule rapporte de l'or.
Idée du 22 octobre 2026. **Le document de conception** est l'Artefact
« Chemins de fer — idée de jeu » (onglet *Conception*) : c'est lui qui fait
autorité sur les règles ; les valeurs de `niveau.json` en sont issues.

## Lancer

```bash
godot --path prototypes/chemins-de-fer-godot
godot --headless --path prototypes/chemins-de-fer-godot --script res://banc.gd
```

Sur la carte : **Construire** (toucher une case voisine du cercle bleu),
**Explorer** (50 or par case de brouillard), **Itinéraire** (choisir les
arrêts, puis *Valider*), **Lancer le train**. Toucher le dépôt (D) ouvre sa
vue : la voie, le quai de 5 emplacements, les stocks, l'achat de la
locomotive et des wagons. Le bouton ×60 / ×600 ne sert qu'à tester : le
jeu est en temps réel (production en heures réelles). La locomotive roule à
40 km/h sur des cases d'1 km : 90 s par case.

## Les fichiers

| | ce qu'il fait |
|---|---|
| `niveau.json` | toutes les valeurs : grille, ressources, prix, production, locomotive |
| `moteur.gd` | les règles, sans écran, déterministes |
| `banc.gd` | le banc d'essai ; il refuse (code de sortie 1) au lieu d'avertir |
| `principal.gd` | la scène : la carte, la vue du dépôt, les boutons |

## Ce que le moteur garde

Le banc vérifie les voies (virage de 45° au plus, 2 bois + 1 fer par case,
annuler rend tout), l'exploration (50 or, au voisinage du connu), le train
(ne part qu'avec le charbon de sa boucle, attend si le dépôt est plein,
conserve le charbon à 1e-6) et la livraison d'eau à la ville (5 or l'unité).

## Simplifications connues

- **Demi-tour :** un train fait demi-tour à un arrêt ou au dépôt. La plaque
  tournante et la boucle de retournement ne sont pas écrites. En pleine voie
  le demi-tour est refusé : une ligne doit *traverser* la ressource (le lac)
  pour que le train poursuive vers la ville.
- **Pas encore :** les feux et les croisements (un seul train), le niveau de
  la ville et ses demandes au-delà de l'eau, les usines, le marché,
  l'amélioration du dépôt, la sauvegarde.
- **Vérification visuelle :** `CHEMINS_CAPTURE=<dossier> godot --path
  prototypes/chemins-de-fer-godot --resolution 600x1300` photographie la
  carte et le dépôt, en fenêtre.
