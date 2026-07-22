# Derush Studio — installation

Outil de dérushage première passe. Il repère les Reels dans un rush, écarte les
reprises, place les zooms, et exporte soit des vidéos finies, soit un projet de
montage pour Premiere Pro ou DaVinci Resolve.

Cette page ne sert qu'à **installer** l'outil. Elle ne donne pas accès à
l'application : un jeton fourni par Tom est nécessaire.

---

## Installer

Ouvre le **Terminal** (⌘ + Espace, tape « Terminal », Entrée), colle cette ligne
et appuie sur Entrée :

```bash
curl -fsSL https://raw.githubusercontent.com/CONTINUDESCROLL/derush-install/main/install.sh | bash
```

Une fenêtre te demandera le **jeton d'accès** que Tom t'a envoyé, puis
**dans quel dossier** installer l'application.

---

## Ce qui va se passer

| Étape | Ce qui s'installe | Durée |
|---|---|---|
| 1 | Vérification de ton Mac | instantané |
| 2 | Vérification du jeton | quelques secondes |
| 3 | Choix du dossier | à toi de jouer |
| 4 | Node et les outils vidéo (~90 Mo) | 1 à 2 min |
| 5 | Moteur de transcription (~1,5 Go) | **10 à 20 min** |
| 6 | L'application | quelques secondes |

**L'étape 5 est la longue.** Le modèle de transcription pèse 1,4 Go et rien ne
s'affiche pendant son téléchargement. C'est normal, laisse tourner.

Au total : **15 à 25 minutes**, une seule fois. Les mises à jour suivantes ne
prennent que quelques secondes.

---

## Ce qu'il faut savoir

**Aucun mot de passe administrateur ne sera demandé.** Tout s'installe dans ton
dossier personnel. Si une commande te réclame un mot de passe administrateur,
ce n'est pas celle-ci — arrête et préviens Tom.

**macOS peut demander l'autorisation d'accéder à ton Bureau** ou à tes Documents.
Réponds OK. Si tu refuses, l'installation continue quand même et t'indique où
trouver le lanceur.

**Il faut les outils de développement d'Apple** (git, python). S'ils manquent,
une fenêtre s'ouvrira pour les installer : accepte, attends la fin, puis relance
la même commande.

---

## Après l'installation

Un raccourci **Derush Studio** apparaît sur ton Bureau. Double-clique dessus :
l'application s'ouvre dans ton navigateur.

Une fenêtre de Terminal reste ouverte pendant ce temps — c'est le moteur de
l'application. **Ferme-la pour arrêter l'outil.**

Tout tourne **sur ta machine** : tes rushs ne sont envoyés nulle part.

---

## Mises à jour

Le bouton **⚙** en haut à droite de l'application. Une pastille ambre apparaît
quand une nouvelle version existe. La mise à jour ne retélécharge que
l'application — ni les outils vidéo, ni le modèle de transcription.

Tes montages ne sont jamais touchés par une mise à jour.

---

## Si ça ne marche pas

Le script s'arrête avec un message qui explique quoi faire. Les cas courants :

**« Ce jeton ne donne pas accès à l'application »** — le jeton est incomplet,
mal collé, ou expiré. Redemandes-en un.

**« Téléchargement impossible »** — la source des outils vidéo est parfois
indisponible. Le script réessaie cinq fois ; si ça échoue quand même, relance la
commande quelques minutes plus tard.

**« Ce dossier n'est pas vide »** — choisis un autre emplacement, ou vide
celui-là. Le script refuse d'écraser des fichiers existants.

Dans tous les cas : **garde la fenêtre du Terminal ouverte** et envoie son
contenu à Tom.

---

## Désinstaller

Supprime le dossier de l'application, et `~/.local` si tu ne t'en sers pour rien
d'autre. Rien n'a été installé ailleurs.
