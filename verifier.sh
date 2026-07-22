#!/bin/bash
# Ce fichier ne contient AUCUNE logique : il appelle l'installateur en mode
# vérification. Deux copies du même contrôle finiraient par diverger, et c'est
# précisément ce genre de duplication qui a déjà cassé une installation.
curl -fsSL "https://raw.githubusercontent.com/CONTINUDESCROLL/derush-install/main/install.sh" \
  | bash -s -- --verifier
