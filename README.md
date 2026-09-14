# PadKey

Utiliser une manette PS5 (DualSense) sur des jeux Mac qui ne gerent que le clavier et la souris.

PadKey lit la manette et envoie a votre place des appuis clavier, des clics et des
mouvements de souris. Le jeu ne sait pas qu'une manette existe : il voit un clavier
et une souris normaux.

## Installation

Depuis l'image disque :

```bash
./package.sh
open dist/PadKey-1.2.0.dmg
```

Glissez PadKey sur le dossier Applications, puis lancez-le.

Depuis les sources, sans passer par l'image :

```bash
./build.sh
open /Applications/PadKey.app
```

Dans les deux cas, macOS demande ensuite l'autorisation Accessibilite. Elle est
obligatoire : sans elle, aucun evenement ne peut etre envoye aux jeux.

Reglages Systeme > Confidentialite et securite > Accessibilite > activer PadKey.

Cette autorisation doit etre reaccordee apres chaque `./build.sh`, car la
signature locale change a chaque compilation. `./package.sh` n'y touche pas.

### Sur une autre machine

L'application est signee localement, sans compte developpeur Apple, donc elle
n'est pas notarisee. Au premier lancement macOS la bloque : clic droit sur
PadKey, puis Ouvrir, puis Ouvrir dans la boite de dialogue. Si le fichier a
transite par internet, l'attribut de quarantaine se retire a la main :

```bash
xattr -dr com.apple.quarantine /Applications/PadKey.app
```

## Utilisation

L'icone manette dans la barre de menus donne acces a tout :

- la liste des manettes detectees, avec celle qui est utilisee
- activer ou couper le mapping
- changer de profil
- ouvrir la fenetre de reglages

Bouton PS maintenu une seconde : coupe ou relance le mapping sans quitter le jeu.
Utile si le curseur part en vrille en plein ecran.

## La fenetre

Deux vues, au choix dans la barre du haut.

**Manette** affiche une DualSense dessinee a l'echelle. Chaque controle porte une
etiquette avec la touche qui lui est assignee, reliee par un trait de rappel.
Cliquer un controle, ou son etiquette, ouvre son reglage dans le bandeau du bas.
Les etiquettes vides marquent les entrees encore libres. Pendant que vous jouez
avec la manette, les boutons presses s'allument et les capuchons de sticks suivent
les vrais sticks : c'est le moyen le plus rapide de verifier que PadKey lit bien
la manette, et de reperer une derive ou une zone morte mal reglee.

**Liste** reprend les memes reglages sous forme de tableau, groupes par famille de
controles, pratique pour revoir un profil entier d'un coup.

La colonne de gauche regroupe les profils, les manettes detectees, les reglages de
visee et les seuils. Le bandeau du bas montre en permanence l'etat lu de la
manette : sticks, gachettes analogiques et entrees actives.

## Steam

Le probleme n'est pas Steam, c'est **Steam Input**. Quand il est actif, Steam prend
la main sur la DualSense et la remplace par une manette virtuelle generique : macOS
montre alors deux manettes, et la vraie ne renvoie plus rien d'exploitable.

**Pour un jeu Steam, ne fermez pas Steam.** Desactivez seulement Steam Input pour ce
jeu : Bibliotheque, clic droit sur le jeu, Proprietes, Manette, Desactiver Steam
Input. Steam continue de tourner et de lancer le jeu, mais lache la manette, que
PadKey lit alors normalement.

Pour le couper partout : Steam, Reglages, Manette, puis desactivez la prise en
charge des manettes.

Pour un jeu hors Steam, fermer Steam regle la question d'un coup.

Dans tous les cas, le test qui tranche en dix secondes : ouvrez la fenetre de
PadKey, bougez les sticks, et regardez le bandeau du bas. S'il reagit, la manette
est bien lue.

## Profils

Trois profils sont installes au premier lancement :

- **Outlast** : calque sur le menu Controles du jeu
- **FPS generique** : base a dupliquer pour un autre jeu
- **Bureau** : piloter le Mac au canape, curseur et clics

Les profils sont des fichiers JSON dans
`~/Library/Application Support/PadKey/Profiles`. La fenetre de reglages les modifie,
mais ils restent editables a la main.

```json
{
  "name": "Mon jeu",
  "mouse": {
    "source": "rightStick",
    "speed": 1500,
    "deadzone": 0.09,
    "curve": 2.0,
    "verticalScale": 0.75,
    "invertY": false
  },
  "stickDeadzone": 0.4,
  "triggerThreshold": 0.25,
  "scrollInterval": 0.07,
  "bindings": {
    "leftStickUp": { "keys": ["W"] },
    "l3": { "keys": ["Shift"] },
    "r2": { "mouse": "left" },
    "dpadUp": { "scroll": "up" },
    "options": { "keys": ["Escape"] }
  }
}
```

Entrees disponibles : `cross`, `circle`, `square`, `triangle`, `l1`, `r1`, `l2`,
`r2`, `l3`, `r3`, `dpadUp`, `dpadDown`, `dpadLeft`, `dpadRight`, `options`,
`create`, `ps`, `touchpad`, `leftStickUp/Down/Left/Right`,
`rightStickUp/Down/Left/Right`.

Une entree peut declencher :

- `"keys": ["Shift", "W"]` : des touches, nommees par leur position sur un clavier
  QWERTY. Le `W` designe la touche physique du W, soit le `Z` d'un clavier AZERTY,
  ce que lisent la plupart des jeux.
- `"chars": ["z"]` : un caractere resolu selon la disposition clavier active, pour
  les rares jeux qui lisent le caractere plutot que la position.
- `"keycodes": [13]` : un code de touche brut.
- `"mouse": "left" | "right" | "middle"` : un bouton de souris.
- `"scroll": "up" | "down" | "left" | "right"` : la molette, repetee tant que
  l'entree est maintenue.
- `"autoRepeat": true` : repete la touche tant que l'entree est maintenue, apres un
  court delai, comme le fait un clavier.

Sans `autoRepeat`, une touche reste simplement **enfoncee** tant que l'entree est
maintenue. C'est ce qu'attend un jeu : le personnage avance sans s'arreter. Dans un
editeur de texte, un seul caractere s'affiche, parce que l'auto-repetition du
systeme ne s'applique qu'aux vraies frappes clavier ; ce n'est pas un defaut.
Activez `autoRepeat` pour naviguer dans un menu, ou pour verifier le mapping dans
un editeur de texte.

Le stick qui pilote la souris ignore ses propres directions, pour eviter d'envoyer
des touches en meme temps que le mouvement.

## Reglages de visee

- **Vitesse** : pixels par seconde, stick pousse a fond.
- **Zone morte** : course ignoree autour du centre. A monter si le curseur derive.
- **Courbe** : 1 est lineaire, 2 a 3 donnent plus de finesse pres du centre et
  gardent la vitesse maximale a fond. C'est le reglage qui rend la visee agreable.
- **Axe vertical** : les jeux sont souvent plus sensibles en Y, 0,75 compense.

## Diagnostic

```bash
/Applications/PadKey.app/Contents/MacOS/PadKey --diagnostic
```

Liste les manettes vues par macOS et affiche en direct les sticks, les gachettes et
les boutons. Utile pour verifier le materiel sans passer par l'autorisation
Accessibilite.

```bash
/Applications/PadKey.app/Contents/MacOS/PadKey --test-touche
/Applications/PadKey.app/Contents/MacOS/PadKey --test-souris
```

Verifient respectivement qu'une touche envoyee reste enfoncee puis se relache, et
que les mouvements de souris sortent. Le test clavier passe par F13, donc il n'ecrit
nulle part.

## Harnais de developpement

```bash
.build/release/PadKey --snapshot capture.png --dark --demo --profile Outlast
```

Rend la fenetre hors ecran dans un PNG, sans autorisation d'enregistrement d'ecran :
une vue sait se dessiner elle-meme. `--list` rend la vue en tableau, `--demo`
simule des appuis pour verifier les surbrillances.

## Versions

Le numero de version est dans le fichier `VERSION` a la racine, lu par `build.sh`
pour le bundle et par `package.sh` pour nommer l'image disque. Le numero de build
est un horodatage de compilation, visible dans le menu de la barre et en tete du
diagnostic. L'historique est dans `CHANGELOG.md`.

Pour publier une nouvelle version, changez la ligne de `VERSION` puis relancez
`./package.sh`.

## Credits

Les visuels de manette viennent du
[Gamepad Asset Pack](https://github.com/AL2009man/Gamepad-Asset-Pack) d'AL2009man,
sous licence MIT, cree a l'origine pour VSCView. L'icone de l'application est
composee a partir de ces memes visuels. Voir `Resources/CREDITS.md`.

## Limites connues

- Les jeux qui capturent la souris en plein ecran attendent des mouvements relatifs.
  PadKey en envoie, mais quelques moteurs anciens filtrent les evenements de synthese.
- La vibration et les gachettes adaptatives de la DualSense ne sont pas utilisees :
  un clavier ne renvoie rien au jeu.
