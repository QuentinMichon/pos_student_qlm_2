.. _lab01:

=================================
Environnement et gestionnaire git
=================================

:Laboratoire: lab01 (18.09.2026)
:Enseignants: Prof. Daniel Rossier / Clément Dieperink / Luc Reveyron

Objectif de laboratoire
=======================

Ce premier laboratoire permet de mettre en place l'environnement de base
permettant le développement croisé sur une cible émulé (*QEMU/virt*) et sur une cible matérielle,
en l'occurrence la plate-forme *Raspberry Pi 4/Sense Hat*.

Pour commencer, ce laboratoire se concentre essentiellement sur l'environnement émulé avec
l'émulateur *QEMU* (plate-forme ***virt***, système de référence ARM composé d'un
*Cortex- A15/armv7*).

Ce laboratoire est aussi l'occasion de mettre en pratique quelques manipulations avec le
gestionnaire de version *git*, outil indispensable pour la gestion des prochains laboratoires.

****Echéance****

Le laboratoire doit être rendu avant le mardi 22.09.2026 23h59

Récupération du code source
===========================

Un dépots Gitlab hébergé sur REDS vous est fournis : 
``https://reds-gitlab-2.reds-heig-vd.in/pos-26/<nom>_<prenom>``

Commencer par cloner votre dépôt dans ``~/pos25`` et le relier au dépôt de référence.

   .. code-block:: console

      ~$ git clone https://reds-gitlab-2.reds-heig-vd.in/pos-26/<nom>_<prenom> pos25
      ~$ cd pos25
      ~/pos25$ git remote add upstream https://reds-gitlab.heig-vd.ch/reds-public/pos_student.git
      ~/pos25$ git fetch upstream
      ~/pos25$ git merge upstream/main
      ~/pos25$ git push origin main

Votre ``push`` va déclencher la pipeline de build du ``rootfs`` (sur Gitlab aller dans Build/Pipelines).

Un worktree par plateforme
--------------------------

Ce clone ``~/pos25`` (branche ``main``) est votre **référence de base** : *on n'y compile pas et on
n'y travaille pas*. Il sert à récupérer les mises à jour du dépôt de référence et à créer un
**worktree par plateforme** (voir :ref:`worktrees`). Un worktree est une seconde copie de travail
du même dépôt, sur sa propre branche ``wt/<plateforme>``, avec ses propres répertoires générés
(``linux/``, ``u-boot/``, ``build/tmp``, ...) : les plateformes ne partagent ainsi jamais leur
état de compilation.

Créer le worktree *virt32* depuis un shell de l'**hôte** (pas dans le conteneur : ``dbuild.sh`` ne
monte que la racine de l'arbre, le répertoire voisin n'y est pas accessible) :

.. code-block:: console

   ~/pos25$ ./scripts/wt.sh add virt32
   ~/pos25$ cd ../pos25-virt32
   ~/pos25-virt32$ git push --set-upstream origin wt/virt32

* ``wt.sh add virt32`` crée la branche ``wt/virt32`` à partir de ``main``, la place dans
  ``../pos25-virt32`` et y sélectionne ``IB_PLATFORM ?= "virt32"`` dans ``build/conf/local.conf``.
  Cette modification reste locale : **ne pas la committer.**
* Toujours lancer ``wt.sh`` depuis la référence ``~/pos25`` : le worktree est créé à côté de
  l'arbre d'où le script est lancé (``../<nom de l'arbre>-<plateforme>``).
* ``wt.sh list`` affiche les worktrees existants et leur plateforme.

**Toutes les étapes suivantes se font dans le worktree** ``~/pos25-virt32``.

Pour récupérer plus tard une mise à jour du dépôt de référence, la fusionner dans ``main``, puis
dans la branche de chaque worktree :

.. code-block:: console

   ~/pos25$ git fetch upstream
   ~/pos25$ git merge upstream/main
   ~/pos25$ git push origin main
   ~/pos25$ cd ../pos25-virt32
   ~/pos25-virt32$ git merge main


.. warning::
   Les laboratoires s'exécutent depuis une image *Docker* contenant tous les outils
   nécessaires (compilation, déploiement, exécution). Il est donc **nécessaire d'avoir
   *Docker* installé sur votre machine**.

Lancer l'image Docker pour les prochaines étapes, depuis la racine du worktree.

.. important::
    ``env.sh`` doit être sourcé depuis la racine de l'arborescence — il détermine l'emplacement de
    l'arborescence à partir du répertoire courant. Il ajoute ``scripts/`` et ``bitbake`` au ``PATH``.
    Dès lors, ``build.sh``, ``deploy.sh``, ``st.sh`` et ``dbuild.sh`` peuvent être exécutés comme de
    simples commandes, depuis n'importe quel endroit de l'arborescence. À faire une seule fois par
    terminal.

.. code-block:: console

   ~/pos25-virt32$ . ./env.sh
   ~/pos25-virt32$ dbuild.sh --build # Prends quelques minutes

Attendre la fin de la CI/CD et récupérer l'artefact ``rootfs.cpio``. Le placer dans le worktree, dans
``build/meta-rootfs/recipes-rootfs/linux/files/board/<plat>``, ``<plat>`` dépend de la plateforme
choisie (ici ``virt32``). Ce fichier n'est pas suivi par git : chaque worktree a besoin du sien.

Pour exécuter les prochaines commandes dans l'environnement Docker, utiliser ``dbuild.sh``
avant chacune d'elles, ou lancer directement ``dbuild.sh`` sans argument.

La sélection de la cible (*target*) se fait via la variable ``IB_PLATFORM`` dans le fichier
de configuration ``build/conf/local.conf``. ``wt.sh`` l'a déjà réglée sur *virt32* dans ce
worktree : ne pas la modifier, les autres plateformes auront chacune leur propre worktree.

Environnement émulé *QEMU/virt*
===============================

Dans un premier temps, nous allons commencer par compiler **QEMU** et **U-Boot**
sans **Linux** afin de voir les différentes étapes nécessaires.

#. **Compiler QEMU.** Cette étape est couverte par le système de scripts *Infrabase*, qui
   invoque la recette ``qemu`` et s'exécute depuis la racine du dépôt :

   .. code-block:: console

      ~/pos25-virt32$ dbuild.sh build.sh qemu   # compile qemu-system-arm/qemu-system-aarch64

   .. note::
      Dans le fichier ``local.conf``, la variable ``IB_QEMU_METHOD`` est définie à
      ``prebuilt``. Cela implique que le script ``build.sh`` va uniquement copier les binaires
      déjà compilés de QEMU. Plus tard, vous serez amené à écrire des fonctionnalités pour QEMU
      et devrez compiler QEMU vous-même. Pensez à changer cette variable à ``build`` le moment venu.

#. Effectuer ensuite la **compilation du bootloader** en utilisant la configuration prédéfinie pour
   l'environnement *QEMU/virt32*. La configuration et la compilation se font en une seule
   commande, depuis la racine du dépôt :

   .. code-block:: console

      ~/pos25-virt32$ dbuild.sh build.sh uboot

#. **Créer une image de la carte SD virtuelle.** Cette étape est automatique :
   ``deploy.sh`` crée l'image (``filesystem/sdcard.img.virt32``) si elle n'existe pas
   encore, puis y copie le *bootloader* compilé (seule la partition *boot* reçoit du
   contenu ; la partition *rootfs* reste vide) :

   .. code-block:: console

      ~/pos25-virt32$ dbuild.sh deploy.sh uboot

#. A ce stade, **l'environnement émulé peut être lancé avec le script** ``st``, qui se
   trouve désormais dans ``scripts/`` et se lance via :

.. code-block:: console

   ~/pos25-virt32$ dbuild.sh st.sh

* Examiner le script ``st`` : 
   son exécution démarre le *bootloader* sur la machine émulée *virt*. La carte SD virtuelle est déjà associée 
   à l'émulateur, même sans contenu (le *bootloader* est passé via
   l'option ``-kernel``).
* Observer la taille de la RAM et lister les variables d'environnement prédéfinies avec ``printenv``.
* Ignorer les messages d'erreurs apparaissant avant le *prompt* de *U-Boot*.
* Pour quitter *QEMU*, il faut taper ``CTRL+A`` puis ``X`` (en relâchant ``CTRL+A``).

Modification de *U-Boot (bootloader)*
=====================================

Cette étape consiste à rajouter une commande ``hello`` dans l'environnement *U-Boot*.

#. A partir du fichier ``u-boot/cmd/version.c``, **créer un fichier** ``hello.c``
   dans le même répertoire et adapter le ``Makefile``.
#. **Editer** ``hello.c`` afin que la commande ``hello`` affiche un message simple.
#. **Compiler et tester.**

Compilation de *Linux*
======================

.. warning::
    Vérifier votre nombre de coeur de votre processor et adapter la variable ``BB_NUMBER_THREADS`` de ``local.conf`` en fonction. Pensez à en laisser
    2 de libre pour le reste du système.
    Vous pouvez vérifier cela avec ``lscpu`` sous Linux et via le *gestionnaire des tâches* sous Windows.

Cette étape consiste à compiler *Linux* pour l'environnement émulé *QEMU/virt*.
Pour cela, suivez les étapes suivantes :

#. **La configuration et la compilation du noyau** pour la cible *virt32*, ainsi que la
   compilation du *device tree* (DTS), s'effectuent en une seule commande scriptée,
   depuis la racine du dépôt :

    .. code-block:: console

       ~/pos25-virt32$ dbuild.sh build.sh linux

#. Le script ``deploy.sh`` à la racine du dépôt permet de déployer les différents
   composants. **Examiner les options disponibles** en lançant le script sans argument.

#. **Déployer le bootloader** *U-Boot*, le noyau *Linux* et le *rootfs* dans la carte SD
   virtuelle avec la recette ``bsp-linux`` (image *FIT*, *rootfs*, carte SD). Les
   applications user-space ne sont déployées que si elles ont été compilées au préalable
   (``build.sh usr-linux`` ou ``build.sh bsp-linux``), ce qui n'est pas le cas ici puisque
   seul ``linux`` a été construit à l'étape précédente :

    .. code-block:: console

       ~/pos25-virt32$ dbuild.sh deploy.sh bsp-linux

#. **Lancer l'environnement** avec le script ``st`` et vérifier que *Linux* démarre
   correctement jusqu'au terminal :

    .. code-block:: console

       ~/pos25-virt32$ dbuild.sh st.sh

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
