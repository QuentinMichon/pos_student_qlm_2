.. _lab03:

==============================
Périphérique émulé dans *QEMU*
==============================

:Laboratoire: lab03 (02.10.2026)
:Enseignants: Prof. Daniel Rossier / Clément Dieperink / Luc Reveyron

Objectif de laboratoire
=======================

Le modèle de périphérique implémenté dans l'émulateur *QEMU* permet de rajouter facilement de
nouveaux périphériques. Ce laboratoire propose de rajouter l'émulation du périphérique *vext*
à la plate-forme *virt32*. Dans un premier temps, il s'agira d'implémenter l'émulation d'un
contrôleur LED ainsi que les interactions avec l'interface graphique (GUI) *Sense-HAT* développée
en *Python*.

Egalement, une première compilation de *buildroot* sera faite pour prendre en main l'outil.

****Echéance****

Le laboratoire doit être rendu avant le mardi 05.10.2026 23h59

Création de la nouvelle branche
===============================

Si nécessaire, corriger les commentaires de l'assistant sur la merge request du laboratoire précédent
et informer l'assistant une fois fait. Seules les erreurs qui peuvent poser problèmes pour la suite
sont à corriger, ils ont la mention *A corriger*. Mais il peut y avoir d'autres commentaires
à prendre en compte dont la correction peut être faite sur la branche du nouveau laboratoire.

Créer la nouvelle branche pour le laboratoire. Si la branche du laboratoire précédent n'a pas encore été
merge (modification à faire valider), repartir de celle-ci pour créer la nouvelle branche.

.. code-block:: console

   # S'assurer d'etre a jour avec dev
   ~/pos25$ git switch dev
   ~/pos25$ git pull
   ~/pos25$ git switch -c lab03
   ~/pos25$ git push --set-upstream origin lab03

Compilation de *buildroot*
==========================

La compilation de *buildroot* prenant du temps non négligeable, commencer par lancer celle-ci en arrière-plan
le temps de faire les étapes suivantes. Les commandes suivantes doivent être effectuées depuis *Docker*.

*buildroot* ayant besoin des sources pour les différents packages compilés, il va automatiquement
aller les télécharger. L'URL utilisé par défaut pour les sources GNU n'est pas des plus rapides (~20ko/s).
Il est possible de modifier celui-ci via ``menuconfig`` dans le menu *Build Options > Mirros and Download locations*
et l'option *GNU Software mirror*. Plusieurs miroirs (copie des sources) existent à travers le monde,
mais l'URL http://ftpmirror.gnu.org permet de sélectionner l'une d'elle automatiquement.
Plus d'informations sont disponibles ici https://www.gnu.org/prep/ftp.html.

Au lieu d'utiliser l'option ``-j`` de ``make``, *buildroot* à son propre paramètre pour la compilation
sur plusieurs threads. Par défaut, il va automatiquement utiliser tous les threads disponibles pour compiler les packages
et donc avoir de temps à autre un impact sur l'utilisation de l'ordinateur.
Pour limiter cela, il est possible de modifier l'option *Number of jobs to run simultaneously*,
dans le menu *Build options* de ``menuconfig``. L'idéal serait donc de modifier cette valeur pour laisser
2 libres pour le reste du système.

Les commandes suivantes permettent de lancer la compilation de *buildroot* :

.. code-block:: console

   ~/pos25$ cd rootfs.src
   ~/pos25/rootfs.src$ make virt32_defconfig

   # Modifier le miroir des sources et le nombre de jobs simultanes
   ~/pos25/rootfs.src$ make menuconfig

   # Ne pas utiliser l'otion -j
   ~/pos25/rootfs.src$ make

Garder le terminal ouvert et passer à létape suivante avec un nouveau terminal Docker.
En cas de problème, il est possible de relancer la compilation simplement avec ``make``.

Développement des accès aux LEDs sur *vExt*
===========================================
Nous allons maintenant implémenter les fonctionnalitées de *vExt*. La première étape est de compiler *QEMU* en mode ``build``. 
Dans ``local.conf`` modifier : ``IB_QEMU_METHOD``. Puis recompiler.

    .. code-block:: console

       ~/pos25$ dbuild.sh build.sh qemu

L'ensemble des fichiers concernant le périphérique *vExt* se trouvent dans le répertoire
``hw/arm/vext`` de *QEMU*. Cette étape consiste à implémenter le code du périphérique *vExt*
afin de gérer l'accès aux LEDs.

#. Modifier le fichier ``build.conf`` pour repasser sous ``virt32``.
#. Supprimer le fichier ``qemu/build/qemu-system-arm`` qui correspondait à une version
    pré-compilée pour le laboratoire précédent avec le code qui sera implémenté dans celui-ci.
#. Editer le fichier ``hw/arm/virt.c`` et activer la portion de code qui rattache
    le périphérique *vExt* à la board *virt32*. Il ne faut pas activer la partie pour les IRQs.
#. Compléter le fichier ``hw/arm/vext/vext.c`` afin que *QEMU* puisse instancier le
    nouveau périphérique. Tester en affichant un texte dans la fonction d'initialisation.
#. Rajouter le code qui sera appelé lorsqu'un accès aux LEDs sera effectué.
    Tester le fonctionnement avec *U-Boot*. (A priori, il n'est **pas** nécessaire de recompiler *U-Boot* pour *virt32*)
#. Finaliser la gestion des LEDs en interagissant avec l'application *Sense-HAT*.
    Il s'agit d'implémenter le code permettant l'envoi d'un message JSON au *frontend* graphique.

  * Seul l'implémentation de la gestion des LEDs 0 à 4 est demandée.
  * La lecture du registre doit évidemment retourner une valeur cohérente.

#. Tester l'implémentation avec les commandes *U-Boot*.
#. Tester le fonctionnement sous *Linux* avec le module ``access.ko``.

Ajout de ``vim``/``nano`` dans *Buildroot*
==========================================

Une fois que la compilation de *buildroot* lancée à l'étape 2, est terminée, le résultat de la compilation
est le fichier ``board/virt32/rootfs.cpio`` du dossier ``rootfs.src``.
Pour pouvoir le déployer dans le disque virtuel, il faut le copier au même emplacement dans le dossier ``rootfs``.
Ensuite, il suffit de déployer le *rootfs* comme habituellement.

.. code-block:: console

   ~/pos25$ cp rootfs.src/board/virt32/rootfs.cpio rootfs/board/virt32/rootfs.cpio
   ~/pos25$ ./deploy.sh -r

Lancer la simulation et vérifier que *Linux* se lance correctement et que les utilitaires habituels soit présent
et fonctionnel (``ls``, ``cd``, ...). Vérifier également que ni ``vim`` et ni ``nano`` n'existe déjà
dans l'image en essayant de les exécuter.

Une fois les vérifications précédentes faites, activer les paquets pour ``vim`` et ``nano``
dans *buildroot* à l'aide de ``menuconfig`` (depuis le dossier ``rootfs.src``).

* Inspirez-vous du nom de la configuration du paquet montré dans le cours pour les trouver.

Ensuite, recompiler *buildroot* pour ajouter les deux nouveaux paquets et déployer dans l'image.

.. code-block:: console

   ~/pos25/rootfs.src$ make

   ~/pos25$ cp rootfs.src/board/virt32/rootfs.cpio rootfs/board/virt32/rootfs.cpio
   ~/pos25$ ./deploy.sh -r

Lancer la simulation et vérifier que les deux utilitaires soient bien présents.

Finalement, copier le fichier ``.config`` dans ``configs/virt32_defconfig`` dans le dossier ``rootfs.src``
pour pouvoir commit les changements.

Questions sur *buildroot*
=========================

A l'aide des informations vu en cours, retrouver les dépendances des paquets ``vim``, ``nano`` et
``python3`` dans *buildroot*. Indiquer les dans le fichier ``lab03.md`` à la racine du repo (à créer).

Sans rentrer dans les détails, lister les patches appliquer à ces trois paquets dans ``lab03.md``.

* Pour information, l'environnement utilisé utilise le dossier ``buildroot``
    à la racine de repos comme dossier de base pour la compilation.

Rendu du laboratoire
====================

Pour rendre les laboratoires, il faut s'assurer que tout est commit et push sur GitLab.
Attention à ne commit que les modifications utiles et concernant le laboratoire !
Par exemple, il n'est pas nécessaire de commit les fichiers résultant de compilation
(programme, module, ...). Ne pas hésiter à ajouter des règles dans les ``.gitignore`` si besoin.

Ensuite, il faut aller sur la page GitLab de votre repo. Puis, sur le menu à gauche aller dans ``Code > Merge Requests``
et cliquer sur ``New merge request``. En français, ``merge request`` est traduit pas ``requête de fusion``.

Sélectionnez la branche ``lab03`` comme source et la branche ``dev`` comme cible.
Revérifiez les changements effectués et continuez.

Finalement, mettez ``Rendu lab03`` comme titre et ajouter ``CDieperink`` comme *Reviewer* (*Relecteur* en français)
et finalisez en appuyant sur le bouton pour créer la *merge request*.
