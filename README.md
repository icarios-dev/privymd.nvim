# privymd.nvim

Plugin Neovim pour éditer des fichiers Markdown avec des blocs chiffrés GPG.

## Fonctionnalités

- Déchiffrement automatique à l'ouverture (`decrypt_async`)
- Chiffrement automatique à la sauvegarde (`encrypt_sync`)
- Bloc Markdown spécial : ````gpg````
- Définition du destinataire GPG dans le front-matter YAML :
  ```yaml
  ---
  gpg-recipient: identifiant-de-clé-GPG
  ---
  ```
- Passphrase demandée une seule fois par session
- Aucun texte en clair jamais écrit sur disque

## Dépendances

- Neovim ≥ 0.10
- gnupg

## Installation (avec Lazy.nvim)

````lua
return {
  "icarios-dev/privymd.nvim",
  ft = "markdown"
  config = function()
    require("privmd").setup({
    })
  end
}
````

### Options de configuration possibles 

Valeurs par défaut :
  ````lua
  require("privmd").setup({
    ft_pattern = "*.md",
    auto_decrypt = true,  -- déchiffrement automatique à l’ouverture
    auto_encrypt = true,  -- chiffrement automatique à l’enregistrement
    progress = true,      -- afficher spinner ou compteur de progression
  })
  ````

## Commandes

- ```:PrivyMDShowBlocks``` → affiche tous les blocs GPG détectés
- ```:PrivyMDClearPass``` → oublie la passphrase de la session

## ✅ Points forts de cette structure

1. Tout est **en mémoire** → pas de fichiers temporaires en clair.
2. Flux transparent → l’utilisateur édite normalement, les blocs sont
   déchiffrés automatiquement.
3. Sauvegarde sécurisée → tous les blocs sont chiffrés avant écriture.
4. Plugin autonome → autocommands, commandes utilisateur, aucun setup
   obligatoire.
