.. _lab09:

================================================
Mise en place du *driver vExt* dans *SO3/virt32*
================================================

:Laboratoire: lab09 (20.11.2025)
:Enseignants: Prof. Daniel Rossier / Clément Dieperink

Objectif de laboratoire
=======================

Ce laboratoire permet de découvrir différents aspects liés au portage d'un *driver* d'un OS à un autre,
en particulier de *Linux* à *SO3*. Le *driver vExt* sera progressivement porté dans l'environnement *SO3*,
d'abord sur *virt32* puis sur *Raspberry Pi 4*. Dans ce laboratoire, seule la partie concernant la gestion
des LEDs sera portée et l'application de test ``vextctl`` permettra de valider le fonctionnement de
celles-ci.

Au niveau de *SO3*, et dans le contexte de ces laboratoires, seule la configuration avec
**le stockage du rootfs en RAM** sera utilisée, afin de rester compatible
avec les deux environnements (*virt32* et *RPi4*).

Travailler avec SO3
===================

*SO3* se construit dans le même arbre et avec les mêmes scripts que *Linux* : seule la recette
change (``bsp-so3`` au lieu de ``bsp-linux``). Les deux systèmes partagent la même carte
``filesystem/sdcard.img.virt32`` : ``deploy.sh bsp-so3`` remplace l'ITB ``virt32.itb`` (et
``uEnv.txt``) de la partition de boot, mais ne touche pas au *rootfs Linux* (partition ``p2``),
puisque le *rootfs* de *SO3* est embarqué dans l'ITB. Revenir à *Linux* ne demande donc qu'un
``deploy.sh bsp-linux``.

On continue donc dans le worktree *virt32* existant (``~/pos25-virt32``), à la suite des laboratoires
précédents.

#. Vérifier dans ``build/conf/local.conf`` que la plateforme active est bien *virt32*
    (``IB_PLATFORM ?= "virt32"``). La configuration et l'ITS de *SO3* sont choisis dans la
    section *SO3* du même fichier :

    .. code-block:: text

       IB_CONFIG:so3:virt32     ?= "virt32_fb_defconfig"
       IB_TARGET_ITS:so3:virt32 ?= "virt32_so3"

#. Compiler, déployer et lancer *SO3* :

    .. code-block:: console

       ~/pos25-virt32$ dbuild.sh build.sh bsp-so3
       ~/pos25-virt32$ dbuild.sh deploy.sh bsp-so3
       ~/pos25-virt32$ dbuild.sh st.sh

  * La première compilation est plus longue : elle récupère les sources de *SO3* depuis GitHub
      dans ``so3/`` et construit la *toolchain* MUSL de l'espace utilisateur *SO3*. U-Boot et
      QEMU, déjà construits pour *Linux*, sont réutilisés.
  * Le déploiement place l'ITB *SO3* (``virt32.itb``) sur la partition de boot de
      ``filesystem/sdcard.img.virt32``.
  * Quitter QEMU avec ``Ctrl-A x``.
  * Pour revenir à *Linux* : ``dbuild.sh deploy.sh bsp-linux``.

#. Une fois l'environnement fonctionnel, utiliser la recette la plus petite pour chaque
    modification :

    .. list-table::
       :header-rows: 1
       :widths: 45 55

       * - Modification
         - Commandes
       * - noyau *SO3*, *driver*, *device tree*, *defconfig*
         - ``build.sh so3`` puis ``deploy.sh bsp-so3``
       * - applications de l'espace utilisateur
         - ``build.sh usr-so3`` puis ``deploy.sh bsp-so3`` (le *ramfs* est embarqué dans l'ITB,
           qui doit être régénérée)

.. important::

   ``so3/`` est un arbre **généré** : il est récupéré à une version figée de *SO3*, puis le jeu de
   patches du cours (``build/meta-so3/recipes-so3/vext``) y est appliqué. Vos modifications dans
   ``so3/`` ne sont donc pas suivies par git.

   Comme pour ``linux/``, on modifie et on recompile directement dans ``so3/`` : ``build.sh so3``
   est incrémental et ne régénère ``so3/`` que si le jeu de patches du cours (ou la version de
   *SO3*) change. Avant de **commiter**, intégrer vos modifications au jeu de patches : ce sont
   ces patches (sous ``build/meta-so3/``) qui sont commités.

   .. code-block:: console

      ~/pos25-virt32$ dbuild.sh updiff.sh so3

   Si le jeu de patches change alors que ``so3/`` contient des modifications non intégrées, le
   build refuse de régénérer ``so3/`` pour ne pas les écraser (``Refusing to re-attach so3``) :
   lancer ``updiff.sh so3`` puis relancer le build.

Mise en place du *driver vExt* dans *SO3*
=========================================

Il s'agit de mettre en place un nouveau *driver* dans *SO3*. L'environnement est celui de
*virt32*, dans le worktree ``~/pos25-virt32``.

Le jeu de patches du cours fournit déjà un **squelette** du *driver* : le fichier
``so3/so3/devices/vext.c`` (signatures uniquement, marquées ``A completer (POS)``), l'option
``CONFIG_VEXT`` dans ``devices/Kconfig`` et la règle correspondante dans ``devices/Makefile``.
Pour *virt32*, il reste à activer le *driver* et à le décrire dans le *device tree*.

#. Comparer le squelette ``devices/vext.c`` avec le modèle de *driver* ``devices/mydev.c`` et
    examiner comment ``vext.c`` est intégré au build (``devices/Kconfig``, ``devices/Makefile``).

#. Activer le *driver* dans la configuration *virt32* de *SO3*. Le build régénère le ``.config``
    à partir du *defconfig* à chaque ``build.sh so3`` (``make virt32_fb_defconfig``, choisi par
    ``IB_CONFIG:so3:virt32`` dans ``local.conf``) : c'est donc le fichier
    ``so3/so3/configs/virt32_fb_defconfig`` qu'il faut modifier, en y ajoutant ``CONFIG_VEXT=y``
    (s'inspirer de ``virt64_fb_defconfig``).

    .. code-block:: console

       ~/pos25-virt32$ dbuild.sh build.sh so3
       ~/pos25-virt32$ grep VEXT so3/so3/.config      # doit afficher CONFIG_VEXT=y

  * Une modification faite directement dans ``.config`` (par exemple avec ``make menuconfig``)
      est perdue au build suivant.

#. Adapter le *device tree* ``so3/so3/dts/virt32.dts`` en ajoutant un noeud pour *vExt*,
    permettant au *driver* d'effectuer les initialisations nécessaires.

  * Examiner les autres noeuds du DT afin de comprendre la signification de la propriété ``reg``.
  * Le noeud *vExt* de ``so3/so3/dts/virt64.dts`` peut servir d'exemple.
  * Le DT est recompilé avec le noyau (``build.sh so3``) puis placé dans l'ITB au déploiement.

#. Examiner le fichier ``devices/device.c`` et expliquer dans le fichier ``lab09.md`` (à créer)
    comment s'effectue le *parsing* du DT et le remplissage de la structure ``dev_t``,
    reçue par la fonction d'initialisation du *driver* (équivalent d'une fonction ``probe``).

#. Examiner le fichier ITS ``build/meta-bsp/recipes-bsp/so3/files/its/virt32_so3.its`` utilisé
    par ``deploy.sh bsp-so3`` et expliquer dans ``lab09.md`` :

  * à quelles adresses sont chargés le noyau (``so3.bin``), le *device tree* (``virt32.dtb``)
      et le *ramfs* (``rootfs.fat``), et pourquoi ces adresses ne se chevauchent pas ;
  * le rôle de la propriété ``default`` du noeud ``configurations``, et comment ajouter une
      seconde configuration (par exemple sans *ramfs*) ;
  * comment ``${IB_SO3_PATH}`` et ``${IB_ROOTFS_PATH}`` sont résolus au moment du build.

#. Compiler *SO3* avec le nouveau *driver*, ainsi que les applications de l'espace utilisateur
    et le *ramfs* (``rootfs.fat``, régénéré automatiquement par la recette ``rootfs-so3``) :

    .. code-block:: console

       ~/pos25-virt32$ dbuild.sh build.sh bsp-so3

#. Déployer et tester le fonctionnement de *SO3* :

    .. code-block:: console

       ~/pos25-virt32$ dbuild.sh deploy.sh bsp-so3
       ~/pos25-virt32$ dbuild.sh st.sh

#. Avant de commiter, intégrer les modifications faites dans ``so3/`` (``vext.c``, *defconfig*,
    DT) au jeu de patches :

    .. code-block:: console

       ~/pos25-virt32$ dbuild.sh updiff.sh so3

Portage de la gestion des LEDs
==============================

Cette étape porte sur le portage de la gestion des LEDs du périphérique *vExt*.
La version du *driver* développé sous *Linux* servira de base et le code pourra être repris
et adapté autant que possible. La gestion des données internes au *driver* se fera à l'aide d'une structure privée.

#. Compléter le *driver vExt* dans *SO3* avec la gestion d'accès aux LEDs.
#. Test l'allumage d'une LED (ou plusieurs) dans la fonction d'initialisation.
#. Compléter le *callback* permettant d'allumer/éteindre une LED depuis l'espace utilisateur.
    Cette partie sera testée dans l'étape suivante.

Portage de l'application user-space
===================================

Cette étape porte sur le portage de la gestion des LEDs du périphérique *vExt*.
La version de l'application ``vextctl`` développée sous *Linux* au lab06 pourra être portée
simplement dans l'environnement *SO3*.

#. Copier l'application ``vextctl`` développé sous *Linux* au **lab06** (donc sans la gestion des switchs)
    dans ``so3/usr/src`` et adapter le fichier ``CMakeLists.txt`` afin
    qu'elle puisse être compilée comme application *SO3*.
#. Créer les entrées requises dans le répertoire ``so3/usr/out/dev`` à l'aide de la commande ``touch``, suivant l'exemple suivant :

    .. code-block:: console

       ~/pos25-virt32/so3/usr/out/dev$ touch <devname>0
       ~/pos25-virt32/so3/usr/out/dev$ touch <devname>1
       ...

#. Adapter l'application ``vextctl`` afin d'ouvrir les bonnes entrées.
#. Déployer l'application et tester son fonctionnement.

  * Le déploiement des applications *SO3* (et des nouvelles entrées dans ``dev/``)
      se fait en recompilant ``usr-so3``, puis en redéployant ``bsp-so3`` : les applications
      sont copiées dans le *ramfs*, lui-même embarqué dans l'ITB, qui doit donc être régénérée.

      .. code-block:: console

         ~/pos25-virt32$ dbuild.sh build.sh usr-so3
         ~/pos25-virt32$ dbuild.sh deploy.sh bsp-so3
