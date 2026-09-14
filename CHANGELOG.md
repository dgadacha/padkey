# Journal des versions

Le numero de version vit dans le fichier `VERSION` a la racine. `build.sh` le pose
dans `CFBundleShortVersionString` et `package.sh` nomme l'image disque avec.
`CFBundleVersion` recoit un horodatage de compilation, ce qui distingue deux builds
d'une meme version sans avoir a tenir un compteur.

Numerotation semantique : le premier nombre change si l'usage change en profondeur,
le deuxieme pour une nouveaute, le troisieme pour une correction.

## 1.1.2

- PadKey apparait desormais dans le Dock et dans Commande+Tab. L'application vivait
  uniquement dans la barre de menus, ce qui la rendait introuvable quand son icone
  y etait masquee.
- Reglage « Afficher dans le Dock », dans la colonne de gauche et dans le menu de la
  barre, pour revenir au mode discret d'origine.
- Vraie barre de menus applicative en mode Dock : A propos, Reglages, Masquer,
  Quitter, et le menu Fenetre.

## 1.1.1

- Double-cliquer l'application ne produisait rien de visible : sans icone dans le
  Dock, et avec une barre de menus pleine ou macOS masque l'icone, PadKey devenait
  injoignable alors qu'il tournait. La fenetre s'ouvre desormais a chaque lancement,
  et relancer l'application la rouvre.
- Avertissement dans la fenetre quand l'icone de barre de menus ne tient pas, avec
  la marche a suivre pour faire de la place.
- Icone : macOS 26 encadrait de gris les icones fournies en seul .icns. Elle passe
  maintenant par un catalogue d'assets compile et remplit toute la forme.

## 1.1.0

- Interface repensee autour d'une illustration de DualSense : chaque controle est
  cliquable, s'allume quand il est presse et porte l'etiquette de sa touche, reliee
  par un trait de rappel. Les capuchons de sticks suivent les vrais sticks.
- Vue Liste en alternative, groupee par famille de controles.
- Bandeau de lecture en direct : sticks, gachettes analogiques, entrees actives.
- Icone d'application et image disque d'installation (`./package.sh`).
- Steam : l'avertissement conseillait de fermer Steam, ce qui est un mauvais conseil
  quand le jeu vient justement de Steam. Il explique desormais comment desactiver
  Steam Input pour un jeu, sans quitter Steam.
- `build.sh` ne remet plus l'autorisation Accessibilite a zero quand il se contente
  de construire, seulement quand il installe.

## 1.0.0

- Lecture de la DualSense et injection clavier, souris et molette.
- Profils JSON, avec Outlast, FPS generique et Bureau livres d'origine.
- Choix explicite de la manette, pour ne pas tomber sur celle que cree Steam Input.
- Application en barre de menus, bouton PS maintenu une seconde pour couper le
  mapping sans quitter le jeu.
- Modes console `--diagnostic`, `--test-souris` et `--snapshot`.
