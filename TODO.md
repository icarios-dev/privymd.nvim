# TODO

- [*] refacto async => sync
- [*] decrypt : gestion de multiples clés de chiffrements et identification des clés
- [-] couverture de test du nouveau module inspect.lua
- [*] utilisation de la nouvelle fonction run_gpg pour factoriser encrypt et decrypt
- [ ] ajout d'une option pour définir un recipient par défaut
- [ ] remplacement de ce recipient par celui du front-matter si présent
- [ ] possibilité de préciser un recipient par bloc => chiffrement pour plusieurs destinataire possible
- [ ] affichage de ce recipient pour les bloc en clair : ```gpg/recipient
- [ ] dissimulation du recipient pour les blocs chiffrés : ```gpg
- [ ] création d'une CLI pour chiffrer / déchiffrer sans lancer Neovim

