.. _lab02:

==============================================
Développement croisé, déploiement et accès I/O
==============================================

:Laboratoire: lab02 (25.09.2026)
:Enseignants: Prof. Daniel Rossier / Clément Dieperink / Luc Reveyron

Objectif de laboratoire
=======================

L'objectif principal de ce laboratoire est la prise en charge en détail des composants de
l'environnement déployé sur une *board*, à savoir le noyau, le *device tree* (DT), le *rootfs* initial
(*initrd*) ainsi que le *rootfs* principal (*rootfs*).

Le déploiement s'effectuera dans l'environnement émulé *virt* ainsi que sur la plate-forme
*Raspberry Pi 4*.

****Echéance****

Le laboratoire doit être rendu avant le mardi 29.09.2026 23h59

Environnement *Linux* sur *QEMU/virt*
=====================================

Lors du laboratoire précédent, *Linux* a été compilé et déployé pour l'environnement émulé.
Cette étape revient plus en détail sur le déploiement effectué par les scripts ``build.sh``
et ``deploy.sh``.

Répondez aux différentes questions suivantes succinctement dans le fichier
``lab02.md`` (à créer) à la racine du repo.

#. Examiner le contenu du répertoire ``linux/images/`` et en particulier le fichier
   ``virt32.its``. Que décrit ce fichier ? A quoi cela sert-il ?

#. Pour générer l'image (fichier ``.itb``) à partir de ``virt32.its``, l'utilitaire
   ``mkimage`` est utilisé. Cette étape est effectuée par ``build.sh bsp-linux``
   et équivaut à la commande ci-dessous. L'argument ``-f`` permet de préciser
   l'utilisation du format FIT (*Flattened Image Tree*).

    .. code-block:: console

       ~/pos25-virt32/linux/images$ mkimage -f virt32.its virt32.itb

    Que contient le fichier ``virt32.itb`` ?

#. **Le déploiement du boot chain** copie ensuite l'ITB et l'environnement U-Boot sur la
   carte SD virtuelle : la partition 1 (``boot``) de ``filesystem/sdcard.img.virt32`` est
   montée, ``virt32.itb`` ainsi que ``uEnv_virt32.txt`` (renommé ``uEnv.txt``) y sont
   copiés, puis la partition est démontée — c'est ce que fait :

    .. code-block:: console

       ~/pos25-virt32$ dbuild.sh deploy.sh bsp-linux

    Avec *QEMU*, pourquoi *U-Boot* lui-même n'est pas copié dans le disque ?

#. Ce déploiement (``dbuild.sh deploy.sh bsp-linux``) est nécessaire après avoir
   compilé *Linux* (et *U-Boot* pour la *Raspberry Pi4*).

#. Finalement, le *rootfs* est déployé avec la recette ``rootfs-linux`` :

    .. code-block:: console

       ~/pos25-virt32$ dbuild.sh deploy.sh rootfs-linux

    Il n'est pas nécessaire de faire cette commande après une compilation de *Linux*, le
    *rootfs* n'étant pas modifié.

Développement d'un module et déploiement
========================================

Dans cet environnement, le développement d'une application destinée à tourner dans l'espace
utilisateur peut être réalisé dans le répertoire ``linux/usr``. Le sous-répertoire ``src/`` contient les
applications "normales" alors que le sous-répertoire ``module/`` est réservé à la production de
code destiné à s'exécuter dans l'espace noyau.

Les binaires générés pour les applications et les modules sont placés dans le sous-répertoire ``out/``.

La notion de module dans *Linux* permet d'insérer du code noyau à la volée, depuis l'espace
utilisateur (typiquement à partir d'un shell). Les modules sont alors des fichiers avec l'extension
``.ko``. Cet exercice montre comment procéder dans l'environnement émulé.

#. Examiner le fichier ``display.c`` dans le répertoire ``linux/usr/src`` ainsi que le *Makefile*.
#. Examiner le fichier ``access.c`` dans le répertoire ``linux/usr/src/modules``.
#. **Compiler.** Cela a pour effet de compiler l'ensemble des applications et des modules
   de ``linux/usr`` :

    .. code-block:: console

       ~/pos25-virt32$ dbuild.sh build.sh usr-linux

Le déploiement des applications userspace dans le *rootfs* (principal) s'effectue avec la
recette ``usr-linux`` :

.. code-block:: console

   ~/pos25-virt32$ dbuild.sh deploy.sh usr-linux

* Noter que ``deploy.sh usr-linux`` déploie le contenu de ``usr/build/deploy/`` dans le
  *filesystem*, c.-à-d. dans la carte SD virtuelle ou physique.

#. **Lancer l'environnement** (``dbuild.sh st.sh``) et exécuter l'application en tapant
   ``./display`` et insérer le module en tapant ``insmod access_mod.ko``.
#. Lancer la commande ``rmmod access_mod.ko`` pour retirer le module du noyau.

Accès I/O sur une LED depuis *U-boot*
=====================================

Cette étape permet d'effectuer un accès I/O simple vers les LEDs de *vext*.

#. **Préparer l'émulateur Sense-HAT** (une seule fois, sur la machine hôte — **pas dans
   Docker**) :

    .. code-block:: console

       [PC] ~/pos25-virt32$ ./scripts/build.sh sense-hat

   Ceci prépare un environnement virtuel Python dans ``build/tmp/sense-hat-emu/venv``.

#. **Démarrer l'émulateur graphique**, dans un **nouveau terminal**, sur la machine hôte :

    .. code-block:: console

       [PC] ~/pos25-virt32$ dbuild.sh
       [PC] ~/pos25-virt32$ . build/tmp/sense-hat-emu/venv/bin/activate
       [PC] ~/pos25-virt32$ python3 sense-hat/sense-hat-server.py

    .. note::
      Pour vérifier que le *venv*/GUI fonctionne indépendamment de QEMU, ``sense-hat/test_leds.py``
      peut être lancé (dans le même environnement virtuel) pour tester la matrice de LEDs seule.

  * Il n'est pas nécessaire de quitter l'émulateur entre deux lancements de *QEMU*.

#. **Démarrer l'environnement** avec l'option ``-g`` (active la connexion à la
   *Sense-HAT*, sur le port TCP 4442) dans votre **premier terminal** :

    .. code-block:: console

       ~/pos25-virt32$ dbuild.sh st.sh -g

  * Le message ``vext_try_connect: connected to Sense-HAT server!`` devrait s'afficher
      dans *QEMU* indiquant la bonne connexion à l'interface.
  * Le message ``Connected with <IP Address>:<Port>`` devrait s'afficher
      dans le terminal de ``sense-hat-server.py`` indiquant la bonne connexion à *QEMU*.
  * *Linux* étant déjà déployé sur la carte SD depuis l'étape précédente, U-Boot enchaîne
      automatiquement sur son démarrage après quelques secondes. Appuyer sur une touche
      pendant le compte à rebours (« Hit any key to stop autoboot ») pour rester au
      *prompt* U-Boot.

#. Utiliser la commande ``mw`` dans *U-Boot* afin d'allumer les LEDs et effectuer quelques tests
    (utiliser ``help`` pour obtenir des informations sur les commandes de *U-Boot*).

  * Consulter la :ref:`description des registres de l'extension vExt
    <virt32_register_description>` pour obtenir les informations nécessaires sur
    le pilotage des LEDs.
  * Les registres de *vExt* font 16 bits : utiliser ``mw.w`` / ``md.w``
    (accès 16 bits, *word* au sens d'U-Boot). Les accès 8 bits (``.b``) sont
    ignorés par le périphérique.

Accès I/O sur une LED depuis *Linux*
====================================

Cette étape permet d'effectuer un accès I/O simple vers les LEDs de *vext* depuis *Linux*.

* Il s'agit d'un driver *Linux* comme vu dans les laboratoires de DRV.
    Il n'est pour l'instant pas nécessaire d'utiliser un *platform driver*.
* Les variables globales dans le driver sont acceptées, tant qu'elle ne se multiplie pas inutilement.

#. Editer le fichier ``linux/usr/src/modules/access.c`` et compléter la fonction
   d'initialisation ``access_init()`` afin que celle-ci allume les LEDs "LED0-LED2-LED4"
   (selon la :ref:`description des registres de l'extension vExt <virt32_register_description>`).
#. Compléter la fonction de sortie ``access_exit()`` qui éteindra les LEDs allumées.
#. **Regénérer les fichiers** de ``usr/`` :

    .. code-block:: console

       ~/pos25-virt32$ dbuild.sh build.sh usr-linux

#. **Déployer** les applications et modules :

    .. code-block:: console

       ~/pos25-virt32$ dbuild.sh deploy.sh usr-linux

#. Tester le fonctionnement du module.

Premier déploiement sur la plate-forme *Raspberry Pi 4*
=======================================================

Informations sur la compilation multiplateforme
===============================================

Durant les laboratoires, le développement sera fait en alternance entre *QEMU* et la *Raspberry Pi4*.
Les deux plateformes n'ayant pas les mêmes configurations du noyau *Linux* (drivers différents et autres),
il est normalement nécessaire de le recompiler entièrement.

La plateforme est déterminée par la variable ``IB_PLATFORM`` dans le fichier de
configuration ``build/conf/local.conf`` à la racine du repo. Plutôt que de modifier cette variable
(et de tout recompiler) à chaque changement de plateforme, on utilise **un worktree par
plateforme** (voir :ref:`worktrees`) : une seconde copie de travail du même dépôt, sur sa propre
branche, avec ses propres répertoires générés (``linux/``, ``u-boot/``, ``build/tmp``, ...).

* Le worktree ``~/pos25-virt32`` (créé au lab01) est dédié à *virt32*, branche ``wt/virt32``.
* Le worktree ``~/pos25-rpi4`` est dédié à la *RPi4*, branche ``wt/rpi4``.
* Les deux sont créés depuis la référence ``~/pos25`` (branche ``main``).

Passer d'une plateforme à l'autre revient alors à changer de répertoire.

Partage des périphériques USB à WSL
===================================

Les commandes suivantes ne sont destinées qu'aux utilisateurs *Windows/WSL*.
Les utilisateurs *Linux* peuvent ignorer cette partie.

Afin de transférer un périphérique USB (lecteur carte SD et câble UART), il faut ouvrir un terminal PowerShell
en administrateur et exécuter les commandes suivantes.

.. code-block:: console

   # Lister tous les peripherique
   PS> usbipd list

   # Bind le peripherique pourvoir l'attribuer a WSL
   PS> usbipd bind --busid <BUS-ID>

   # Attacher le peripherique a WSL
   PS> usbipd attach --wsl --busid <BUS-ID>

Le périphérique est maintenant disponible dans WSL et Docker.
La commande ``attach`` doit être rexécutée à chaque déconnexion du périphérique.

Il est également possible d'exécuter la commande suivante ce qui permet de ne pas avoir
à exécuter ``attach`` à chaque fois. Dans ce cas, le programme ne se termine pas
et il ne faut pas fermer le terminal.

.. code-block:: console

   PS> usbipd attach --auto-attach --wsl --busid <BUS-ID>

Désactiver le montage automatique des cartes SD
===============================================

Pour les utilisateurs *Linux*, il est possible d'ajouter les deux lignes suivantes
à la suite de celles existantes dans le fichier ``/etc/fstab``. Cela permet de désactiver
le montage automatique des partitions de la carte SD par Linux et d'éviter de potentiels problèmes.

.. code-block:: console

   LABEL=POS-BOOT none vfat noauto 0 0
   LABEL=POS-ROOTFS none ext4 noauto 0 0

Déploiement RPi4
================

Le déploiement sur la *Raspberry Pi 4* s'effectuera à l'aide d'une carte SD (*SD-card*).

#. **Créer le worktree RPi4.** Depuis un shell de l'**hôte** (pas dans le conteneur :
   ``dbuild.sh`` ne monte que la racine de l'arbre, le répertoire voisin n'y est pas accessible) :

    .. code-block:: console

       ~/pos25$ ./scripts/wt.sh add rpi4
       ~/pos25$ cd ../pos25-rpi4
       ~/pos25-rpi4$ git merge wt/virt32      # reprendre le travail fait sur virt32
       ~/pos25-rpi4$ git push --set-upstream origin wt/rpi4
       ~/pos25-rpi4$ . ./env.sh

  * Lancer ``wt.sh`` depuis la référence ``~/pos25`` : le worktree est créé à côté de l'arbre
      d'où le script est lancé.
  * ``wt.sh add rpi4`` crée la branche ``wt/rpi4`` à partir de ``main``, la place dans
      ``../pos25-rpi4`` et y sélectionne ``IB_PLATFORM ?= "rpi4"`` dans ``build/conf/local.conf``.
      Cette modification reste locale : ne pas la committer.
  * Si ``env.sh`` a déjà été chargé dans ce terminal, un ``cd`` vers un autre arbre propose de
      basculer l'environnement : répondre ``y``.
  * L'image *Docker* est partagée entre les arbres : inutile de refaire ``dbuild.sh --build``.
  * ``rootfs.cpio`` n'est pas suivi par git : copier l'artefact *RPi4* de la CI dans
      ``build/meta-rootfs/recipes-rootfs/linux/files/board/rpi4/`` **du worktree**.

#. **Compiler.** La configuration et la compilation de *U-Boot* et *Linux* pour la *RPi4*
   se font en une seule commande scriptée, depuis la racine du worktree. Le worktree part d'un
   ``build/tmp`` vide : cette première compilation est aussi longue que celle du lab01.

    .. code-block:: console

       ~/pos25-rpi4$ dbuild.sh build.sh bsp-linux

#. Insérer la carte SD.

  * Sous Windows, suivre les commandes ``usbipd`` présentées.
  * Identifier le *device* correspondant à la carte SD insérée à l'aide de la commande
      ``lsblk``, qui affiche la liste des *devices* associés aux supports de stockage
      reconnus par *Linux*.

      ⚠  **ATTENTION !!** **Il est important de spécifier le bon *device***,
      sous risque d'écraser un autre disque et donc perdre toutes les données dessus, voir votre OS complet !
      N'hésitez pas à demander confirmation avant d'exécuter la commande.

  * Renseigner ce nom de *device* (p.ex. ``sda``, sans le ``/dev/``) dans la variable
      ``IB_STORAGE_DEVICE:rpi4`` du fichier ``build/conf/local.conf``.

#. **Partitionner et formater** la carte SD :

    .. code-block:: console

       ~/pos25-rpi4$ dbuild.sh init_storage.sh

#. **Déployer**, mais sans la partie ``usr/``, sur la carte SD réelle de la *RPi4* :

    .. code-block:: console

       ~/pos25-rpi4$ dbuild.sh deploy.sh bsp-linux

#. Tester l'environnement *Linux* sur la *board*.

  * L'accès à la console via l'interface série (UART) peut se faire à l'aide d'une application qui
      émule un terminal série, comme l'utilitaire ``picocom``. Grâce à la commande suivante :

      .. code-block:: console

         ~/pos25-rpi4$ picocom /dev/ttyUSB0 -b 115200 -r -l

      Pour quitter ``picocom``, il faut faire ``CTRL+X`` puis ``CTRL+A``
      (en maintenant ``CTRL`` appuyé)

  * Ne pas oublier d'attacher l'interface USB à *WSL*
  * Il n'est pas forcément nécessaire de passer par *Docker* pour cette commande.
  * Un schéma est disponible sur Cyberlearn montrant comment brancher le câble sur la *RPi4*.

Rendu du laboratoire
====================

Pour rendre les laboratoires, il faut s'assurer que tout est commit et push sur GitLab.
Attention à ne commit que les modifications utiles et concernant le laboratoire !
Par exemple, il n'est pas nécessaire de commit les fichiers résultant de compilation
(programme, module, ...). Ne pas hésiter à ajouter des règles dans les ``.gitignore`` si besoin.

Le dépôt est construit de laboratoire en laboratoire, avec **un worktree par plateforme**, et
donc une branche par plateforme (voir :ref:`worktrees`) :

* ``~/pos25`` est le clone de **référence** (branche ``main``) : on n'y travaille pas, il sert à
  récupérer les mises à jour du dépôt de référence et à créer les worktrees ;
* le worktree ``~/pos25-virt32`` (*virt32*, créé au lab01) travaille sur la branche ``wt/virt32`` ;
* le worktree ``~/pos25-rpi4`` (*RPi4*, créé au lab02) travaille sur la branche ``wt/rpi4``.

Commiter dans le worktree où la modification a été faite, puis pousser sa branche :

.. code-block:: console

   ~/pos25-virt32$ git push origin wt/virt32
   ~/pos25-rpi4$ git push origin wt/rpi4

* Ne pas commiter ``build/conf/local.conf`` : la sélection de la plateforme (et
  ``IB_STORAGE_DEVICE``) est propre à chaque worktree.
* Une modification commune aux deux plateformes (*driver*, application) se reporte d'une branche
  à l'autre avec ``git merge`` ou ``git cherry-pick`` (les branches sont visibles depuis tous les
  worktrees).
