.. _lab05:

=======================================
Driver Linux pour le pilotage de *vExt*
=======================================

:Laboratoire: lab05 (16.10.2025)
:Enseignants: Prof. Daniel Rossier / Clément Dieperink

Objectif de laboratoire
=======================

L'émulation des LEDs et des *switches* de *vExt* étant réalisée,
il s'agit à présent de piloter le périphérique à l'aide d'un driver Linux.

Ce laboratoire couvre certains aspects fondamentaux liés aux drivers sous Linux.
Il permettra de faire connaissance avec le *device-tree* de la plate-forme *virt32*
et de développer un driver simple sous forme d'un module Linux.
Le laboratoire se focalise dans un premier temps sur le code de driver uniquement,
sans interactions avec une application utilisateur.

****Echéance****

Le laboratoire doit être rendu avant le mercredi 28.10.2024 23h59

Récupération des changements sur ``pos_student``
================================================

Des changements sur ``pos_student`` sont à récupérer pour ce laboratoire.
Voici la procédure pour les récupérer :

.. code-block:: console

   # Sauvegarde des eventuelle modifications locales
   ~/pos25$ git stash

   # Mise a jour de main
   ~/pos25$ git switch main
   ~/pos25$ git pull base main
   ~/pos25$ git push

   # Merge dans dev
   ~/pos25$ git switch dev
   ~/pos25$ git pull
   ~/pos25$ git merge main
   ~/pos25$ git push

   # Restauration des modifications locales
   ~/pos25$ git stash pop

Il ne devrait normalement pas y avoir de conflit. S'il y en a quand même, il faut les corriger puis faire ``git merge --continue``.

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
   ~/pos25$ git switch -c lab05
   ~/pos25$ git push --set-upstream origin lab05

Mise en place du driver pour le périphérique *vExt*
===================================================

A partir du support de cours, il s'agit d'adapter le module dont le code se trouve
dans le fichier ``usr/src/modules/access.c`` pour en faire un driver dédié
au périphérique *vExt*.

#. Editer le *device-tree* de la plate-forme *virt32* afin de rajouter
    un noeud dédié à *vExt* avec une propriété ``reg`` permettant de définir
    la région mémoire I/O propre à ce périphérique.

  * Le *device-tree* est dans le fichier ``linux/linux/arch/arm/boot/dts/arm/virt32.dts``
  * La propriété ``reg`` comporte quatre cellules de 32 bits :
      Les deux premières correspondent à l'adresse sur 64 bits (MSB puis LSB)
      et les deux suivantes à la taille sur 64 bits.
  * Ce noeud peut être placé directement au-dessus de celui intitulé ``psci``

#. Le *device-tree* est recompilé avec le noyau, puis placé dans l'image ITB, par la recette ``bsp-linux`` :

    .. code-block:: console

       ~/pos25$ dbuild.sh build.sh bsp-linux

#. Editer le module ``linux/usr/src/modules/access.c`` afin de gérer un modèle de type plateforme avec une fonction
    ``probe()``. Cette dernière devra allumer les mêmes LEDs que la version précédente du module.

  * Le nœud du *device-tree* qui a provoqué le *matching* est disponible dans ``pdev->dev.of_node`` :
      il n'est pas nécessaire de le rechercher dans l'arbre (``of_find_node_by_name()``).
  * En cas d'erreur (propriété absente, ressource manquante), ``probe()`` retourne un code
      d'erreur négatif (``-ENODEV``, ``-EINVAL``, ``-ENOMEM``, …), si possible via ``dev_err_probe()``.
      Ne pas utiliser ``BUG_ON()`` ou ``BUG()`` : un *driver* ne doit pas faire planter le noyau.
  * Utiliser les fonctions *managées* ``devm_kzalloc()`` et ``devm_platform_ioremap_resource()`` :
      les ressources sont libérées automatiquement par le noyau au retrait du *driver*.
#. Tester le fonctionnement du module en veillant que la fonction ``probe()`` soit bien exécutée.
    Ne pas oublier de déployer le nouveau *device-tree* avec ``dbuild.sh deploy.sh bsp-linux``.

Implémentation d'un traitement immédiat pour les *switches*
===========================================================

L'appui sur un *switch* déclenche une interruption (*IRQ*). Il s'agit d'implémenter le traitement immédiat qui sera chargé
d'acquitter l'interruption et de récupérer le numéro du *switch* appuyé.

* La ligne d'interruption dédiée à *vExt* est de type *SPI* (*Shared Peripheral Interrupt*).

#. Ouvrir le document de *bindings* lié au contrôleur d'interruption (GIC)
    et trouver la signification des trois cellules de la propriété ``interrupts``.

  * Le fichier de *bindings* est le suivant
       {``linux/linux/Documentation/devicetree/bindings/interrupt-controller/arm,gic.yaml``}
  * Pour rappel, l'interruption est de type *niveau* (*actif haut*) et son numéro de SPI est 13 (soit l'INTID 45 du GIC).

#. Editer le *device-tree* de la plate-forme *virt32* et rajouter la propriété permettant de définir les informations liées à l'interruption.
#. Editer le module et rajouter le traitement immédiat qui sera exécuté à la réception d'une interruption. La fonction de traitement affichera
    le numéro du *switch* pressé (de 1 à 5).

  * Le numéro d'IRQ s'obtient avec ``platform_get_irq()`` ; c'est un numéro *Linux* (pas l'INTID du GIC),
      et une valeur négative signale une erreur à retourner telle quelle.
  * L'interruption générée étant de type *niveau*, l'argument ``flags`` de ``request_irq()``
      doit être mis à ``IRQF_TRIGGER_HIGH``.
  * Préférer ``devm_request_irq()`` (ou ``devm_request_threaded_irq()``), libérée automatiquement au retrait du *driver*.
  * Le fichier ``include`` à rajouter est le suivant :

      .. code-block:: c

         #include <linux/interrupt.h>

#. Tester le bon fonctionnement du driver dans son ensemble.
#. Tester l'affichage du bon numéro du *switch*.
#. Editer le traitement immédiat afin d'inverser l'état (allumé/éteint) de la LED correspondante au *switch* appuyé.

  * Garder l'allumage des LEDs dans le ``probe`` pour s'assurer que la fonction soit bien exécutée.

#. Tester le bon fonctionnement du driver dans son ensemble.

Déploiement du driver sur *RPi4*
================================

Cette étape consiste à adapter votre driver ``access.c`` afin de le déployer sur Raspberry Pi 4.

#. Modifier le fichier ``local.conf`` pour mettre ``IB_PLATFORM ?= "rpi4"``.

#. Éditer le *device-tree* propre à la plate-forme *RPi4* afin de rajouter un noeud dédié à *vExt*. Pour le moment, seul la propriété ``compatible`` est nécessaire.

  * Le *DT* est dans ``linux/linux/arch/arm/boot/dts/broadcom/bcm2711-rpi-4-b.dts``
  * Ce nœud peut être placé à la suite de celui intitulé ``memory@0``.

#. Pour le moment, commenter ou entourer d'une condition ``#if 0 … #endif`` la totalité du code écrit dans le probe du driver. (Ce code sera réutilisé par la suite).

#. À l'aide des fonctions ``rpisense_init()`` et ``display_led(int led_nr, bool on)`` fournies dans le fichier ``linux/usr/module/rpisense.h``, initialiser la board d'extension connectée au *RPi4* puis allumé les leds 0, 2 et 4.

  * La compilation pour la *RPi4* de *Linux* et d'*U-Boot*
      du deuxième labo devrait encore être présente. Si ce n'est pas le cas,
      le reconfigurer avec ``rpi4_defconfig`` pour *Linux*
      et ``rpi_4_32b_defconfig`` pour *U-Boot*
  * Le code écrit à l'étape 2 est propre à la platforme *virt32*.
  * Observer les fonctions se trouvant dans le fichier ``linux/usr/module/rpisense.c`` dont la fonction ``display_led`` afin de comprendre comment les accès aux leds sont effectués.

Rendu du laboratoire
====================

Pour rendre les laboratoires, il faut s'assurer que tout est commit et push sur GitLab.
Attention à ne commit que les modifications utiles et concernant le laboratoire !
Par exemple, il n'est pas nécessaire de commit les fichiers résultant de compilation
(programme, module, ...). Ne pas hésiter à ajouter des règles dans les ``.gitignore`` si besoin.

Ensuite, il faut aller sur la page GitLab de votre repo. Puis, sur le menu à gauche aller dans ``Code > Merge Requests``
et cliquer sur ``New merge request``. En français, ``merge request`` est traduit pas ``requête de fusion``.

Sélectionnez la branche ``lab05`` comme source et la branche ``dev`` comme cible.
Revérifiez les changements effectués et continuez.

Finalement, mettez ``Rendu lab05`` comme titre et ajouter ``CDieperink`` comme *Reviewer* (*Relecteur* en français)
et finalisez en appuyant sur le bouton pour créer la *merge request*.
