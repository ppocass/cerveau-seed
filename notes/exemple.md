---
name: exemple
description: "Modèle de note montrant quoi retenir (erreurs payées, endroits, décisions, contraintes) — à supprimer dès la première vraie note"
metadata:
  node_type: memory
  type: "note"
  statut: "actif"
  machine: "commun"
  mots-cles: "exemple, modele, structure"
---

# Exemple — à supprimer dès la première vraie note

Ce fichier ne sert qu'à montrer la forme. Il illustre le principe : **ce qui compte n'est
pas « où on en est », mais ce que la prochaine session ne doit pas réapprendre.**

## Les erreurs déjà payées

C'est souvent la partie la plus précieuse, et toujours celle qu'on oublie d'écrire.

- On a perdu deux jours à essayer de faire tourner X avec Y : ce n'est pas la bonne
  piste, ça diverge dès que le pas de temps descend sous 1 ms.
- Le réglage `--truc` écrase la configuration locale : ne plus l'utiliser sans sauvegarde.

## Les endroits

Où sont les choses, par leur nom : le dépôt `aeris` sur GitHub ; les jeux de données bruts
uniquement sur la machine `station-calcul` ; l'interface locale sur le port 8090.

## Ce qui a été décidé, et pourquoi

Le pourquoi est ce qui manque six mois plus tard. Sans lui, on refait le débat et on
rechoisit mal.

## Les contraintes découvertes

Ce qu'on n'apprend qu'en se cognant dessus : « le capteur sature à 3 g », « au-delà de
200 000 mailles la CI dépasse la mémoire », « ce format d'export perd les quaternions ».

## Les chiffres qui comptent

Seuils, constantes physiques validées, paramètres de référence qu'on ne veut pas recalculer.

## Voir aussi

[[ordinateurs]] — un lien vers une autre note, sans chemin et sans `.md`.
