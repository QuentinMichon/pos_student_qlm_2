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

*buildroot* est géré par la recette ``buildroot`` d'*Infrabase* :

* les sources de *buildroot* se trouvent dans ``linux/rootfs/buildroot`` ;
* le dossier de compilation (``.config``, ``build/``, ``images/``, ...) est ``linux/rootfs`` ;
* le *rootfs* déployé est le fichier ``build/meta-rootfs/recipes-rootfs/linux/files/board/virt32/rootfs.cpio``,
  récupéré depuis la CI/CD au lab01.

Commencer par déployer le *rootfs* actuel et lancer la simulation :

.. code-block:: console

   ~/pos25$ dbuild.sh deploy.sh rootfs-linux
   ~/pos25$ dbuild.sh st.sh

Vérifier que *Linux* se lance correctement et que les utilitaires habituels soient présents
et fonctionnels (``ls``, ``cd``, ...). Vérifier également que ni ``vim`` ni ``nano`` n'existent déjà
dans l'image en essayant de les exécuter.

Une fois les vérifications précédentes faites, rechercher les paquets ``vim`` et ``nano``
dans *buildroot* à l'aide de ``menuconfig``, depuis un shell *Docker* (``dbuild.sh`` sans argument) :

.. code-block:: console

   ~/pos25$ dbuild.sh
   $ cd linux/rootfs
   $ make menuconfig

* Inspirez-vous du nom de la configuration du paquet montré dans le cours pour les trouver.

.. important::
   Le ``.config`` de ``linux/rootfs`` n'est qu'une copie de travail : il est régénéré depuis
   ``configs/virt32_defconfig`` à chaque reconfiguration de la recette. Les modifications faites
   uniquement dans ``menuconfig`` seront donc perdues. Il faut les reporter dans le *defconfig*.

Ajouter les deux options trouvées (``BR2_PACKAGE_...=y``) à la fin du fichier
``linux/rootfs/buildroot/configs/virt32_defconfig``. Ce fichier est volontairement minimal
(seulement les options sélectionnées), il ne faut **pas** le remplacer par le ``.config``.

Les sources de *buildroot* ne font pas partie du dépôt : le *defconfig* y est stocké sous forme de *patch*
(``build/meta-rootfs/recipes-rootfs/buildroot/files/0001-buildroot-2024.11-r0/0002-virt32_defconfig.patch``).
Régénérer ce *patch* puis vérifier que seules vos deux lignes ont été ajoutées :

.. code-block:: console

   ~/pos25$ dbuild.sh updiff.sh buildroot

Il faut ensuite produire un nouveau ``rootfs.cpio`` contenant les deux paquets. Deux possibilités :

* **Via la CI/CD (recommandé)** : *commit* le *patch* et *push*. La modification
  sous ``build/meta-rootfs`` déclenche la pipeline (*Build > Pipelines* sur GitLab), qui publie une
  nouvelle *release* ``rootfs.v<N>``. Récupérer le ``rootfs.cpio`` de l'archive et le placer,
  comme au lab01, dans ``build/meta-rootfs/recipes-rootfs/linux/files/board/virt32/``.
* **En local** (compilation complète de *buildroot*, compter un temps non négligeable) :

  .. code-block:: console

     ~/pos25$ dbuild.sh build.sh rootfs-linux
     ~/pos25$ cp linux/rootfs/images/rootfs.cpio build/meta-rootfs/recipes-rootfs/linux/files/board/virt32/rootfs.cpio

  .. warning::
     La copie est obligatoire : à chaque *build* ou *deploy*, le fichier ``rootfs.cpio`` de
     ``files/board/virt32`` est recopié dans le dossier de travail et écrase celui compilé.
     Sans elle, l'ancien *rootfs* (sans ``vim`` ni ``nano``) serait déployé.

Déployer le nouveau *rootfs* et lancer la simulation :

.. code-block:: console

   ~/pos25$ dbuild.sh deploy.sh rootfs-linux
   ~/pos25$ dbuild.sh st.sh

Vérifier que les deux utilitaires sont bien présents.

.. note::
   Seul le *patch* ``0002-virt32_defconfig.patch`` doit être *commit*. Ne pas *commit* le ``.config``
   ni le fichier ``rootfs.cpio`` (fichier binaire, qui relancerait en plus la CI/CD à chaque *push*).

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
