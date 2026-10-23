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
       * - noyau *SO3*, *driver*, *device tree*
         - ``build.sh so3`` puis ``deploy.sh bsp-so3``
       * - applications de l'espace utilisateur
         - ``build.sh usr-so3`` puis ``deploy.sh usr-so3``

.. important::

   ``so3/`` est un arbre **généré** : il est récupéré à une version figée de *SO3*, puis le jeu de
   patches du cours (``build/meta-so3/recipes-so3/vext``) y est appliqué. Vos modifications dans
   ``so3/`` ne sont donc pas suivies par git. Pour les conserver (et les committer), les intégrer
   au jeu de patches :

   .. code-block:: console

      ~/pos25-virt32$ dbuild.sh updiff.sh so3

   Sans cela, une nouvelle récupération des sources refuse d'écraser ``so3/``
   (``Refusing to re-attach so3``).

Mise en place du *driver vExt* dans *SO3*
=========================================

Il s'agit de mettre en place un nouveau *driver* dans *SO3* en se basant sur un modèle existant. Le
fichier *ITS* doit être également adapté. L'environnement est celui de *virt32*.

* Travailler dans le worktree ``~/pos25-virt32``.

#. Effectuer les commandes ci-dessous afin de configurer le noyau *SO3* avec le *rootfs*
    chargé en RAM et de recompiler ensuite le noyau :

    .. code-block:: console

       ~/pos25-virt32/so3/so3$ make virt32_defconfig
       ~/pos25-virt32/so3/so3$ make

#. Créer une nouvelle image de *rootfs* pour *SO3* (dans le répertoire ``rootfs/``)
    avec la commande suivante :

    .. code-block:: console

       ~/pos25-virt32/rootfs$ ./create_ramfs.sh virt32

#. A partir du modèle de *driver* présent dans le fichier ``devices/mydev.c``,
    créer un fichier ``devices/vext.c`` qui contiendra le code du nouveau *driver*.
    Cette tâche comprend l'adaptation des fichiers ``Kconfig`` et ``Makefile``
#. Adapter le *device tree* permettant au *driver* d'effectuer les initialisations nécessaires.

  * Examiner les autres noeuds du DT afin de comprendre la signification de la propriété ``reg``.

#. Examiner le fichier ``devices/device.c`` et expliquer dans le fichier ``lab09.md`` (à créer)
    comment s'effectue le *parsing* du DT et le remplissage de la structure ``dev_t``,
    reçue par la fonction d'initialisation du *driver* (équivalent d'une fonction ``probe``).
#. Adapter le fichier ITS ``target/virt32.its`` afin d'utiliser les composants de *SO3*

  * Le noyau *SO3* doit être chargé à l'adresse ``0x4100'8000``
  * Le *device tree* doit lui être chargé à l'adresse ``0x44a0'0000``
  * Pour le *rootfs* dans *SO3*, il est nécessaire de spécifier le fichier du ***ramfs***
      créé plus tôt qui doit être chargé à l'adresse ``0x44c0'0000``
  * Il existe différentes approches pour la gestion de plusieurs configurations dans l'ITS.
      Par exemple, l'utilisation de la propriété ``default`` dans le noeud ``configurations`` sont deux possibilités.

#. Compiler *SO3* avec le nouveau driver

#. Compiler les applications de l'espace utilisateur pour *SO3* à l'aide de la commande suivante :

    .. code-block:: console

       ~/pos25-virt32/so3/usr$ ./build.sh

#. Déployer et tester le fonctionnement de *SO3*

    .. code-block:: console

       ~/pos25-virt32$ ./deploy.sh -bs

  * L'option ``b`` déploie le noyau de *SO3*
  * L'option ``s`` déploie les applications user-space de *SO3*

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
      s'effectue avec l'option ``-s`` du script ``deploy.sh``
