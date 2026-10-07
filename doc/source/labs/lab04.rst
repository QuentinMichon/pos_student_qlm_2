.. _lab04:

========================================
Interruptions dans un périphérique émulé
========================================

:Laboratoire: lab04 (05.10.2026)
:Enseignants: Prof. Daniel Rossier / Clément Dieperink / Luc Reveyron

Objectif de laboratoire
=======================

Le but de ce laboratoire est d'implémenter l'émulation des *switch* de l'extension *vExt*.

L'appui sur un *switch* doit générer une interruption qui sera traitée ultérieurement par le *driver*.
Dans ce laboratoire, il sera possible de valider le bon fonctionnement de l'interruption en consultant la valeur des registres concernés.

Amélioration de la lecture/écriture des registres
=================================================

Modifier le périphérique *vExt* dans *QEMU* afin de pouvoir lire et écrire dessus avec des tailles
2 ou 4 octets. Il doit donc être possible de faire les commandes suivantes depuis *U-Boot* pour allumer les
LEDs correctement.

.. code-block:: console

   # Allume la LED central en acces de 2 octets
   [U-Boot] => mw.w 0x2000003a 0x1 1

   # Allume la LED de gauche en acces de 4 octets
   [U-Boot] => mw.l 0x20000038 0x20000 1

* L'accès peut être considéré comme aligné sur la taille accédée.
  Donc un accès de 2 octets est aligné sur 2 octets et un accès
  de 4 octets est aligné sur 4 octets.

Gestion de la pression d'un *switch* sur l'extension *vExt*
===========================================================

Lors de l'appui sur un des *switch*, l'application *Sense-HAT* génère un message ``JSON``
vers *QEMU* qui contient le numéro du *switch* pressé **ou zéro** lorsque le *switch*
est relâché. Cette information permet de conserver le numéro du *switch* pressé dans le registre I/O
de *vExt* réservé à cet effet.

#. Compléter la fonction ``vext_process_switch()`` afin de stocker le *switch* actuellement pressé,
   s'il y en a un.
#. Implémenter le *callback* de lecture permettant de récupérer la valeur de ce registre.

   * Il s'agit du registre ``PUSH_BUT_REG`` de *vExt*.
   * Ce registre doit être maintenu à jour en continu avec l'état des *switchs*.
   * Les bits pour les *switches* 7-8 peuvent être ignoré, car ils ne sont pas présents.

#. Valider le fonctionnement dans *U-Boot* (commandes ``md/mw``) en appuyant sur les *switches*.

* Utiliser la commande suivante dans le *shell* d'*U-Boot* pour afficher une zone mémoire
  toutes les deux secondes.

  .. code-block:: console

     => while true; do; md.w <addr> 0x1; sleep 2; done

Levée d'une *IRQ* dans *vExt*
=============================

Il s'agit à présent de lever une interruption vers le microcontrôleur pour informer de la pression
sur un *switch*. Du point de vue du contrôleur, une *IRQ* peut être levée seulement
si elle a été activée, et si l'interruption précédente a été acquittée.

* Le comportement de ``PUSH_BUT_REG`` ne doit pas être modifié !
  Cette étape ne concerne que le registre ``IRQ_CTRL_REG``.

#. Editer le fichier ``hw/arm/virt.c`` et activer le code d'initialisation permettant de réaliser
   le **lien avec la ligne *IRQ*** de *vExt*.
#. Compléter la structure d'état avec les champs nécessaires pour la gestion d'une *IRQ*.
#. Adapter la fonction d'initialisation du périphérique.
#. Implémenter la levée de l'*IRQ* (ligne *IRQ* à 1) en mettant à jour le registre I/O réservé à cet effet.
#. Gérer l'acquittement de l'*IRQ* (ligne *IRQ* à 0).

   * L'écriture et la lecture du registre ``IRQ_CTRL_REG`` doit respecter
     la documentation de *vExt* et avoir les effets voulus sur l'état du périphérique.

#. Valider le fonctionnement dans *U-Boot* (examiner l'évolution du registre d'interruption)

* Ne pas oublier d'activer les interruptions sur le périphérique ! Tester avec et sans l'activation.
* Afin d'utiliser les fonctions et types nécessaires à la gestion d'*IRQ*,
  il est nécessaire d'inclure les fichiers ``qemu/osdep.h`` et ``hw/irq.h``

**Complément sur le fonctionnement attendu des registres**

* Le champ ``IRQ_BUTTON`` du registre *IRQ* (``IRQ_CTRL_REG``) contient le numéro du *switch*
  ayant généré (1 à 5) la dernière interruption. Ce champ ne doit pas être mis à jour tant que l'*IRQ* n'est pas acquittée
  et ce même si un autre *switch* est appuyé. Ce champ n'est valide que lorsque ``IRQ_STATUS`` est actif.
* Une interruption ne peut être levée tant que la précédente n'est pas acquittée et/ou que la génération des *IRQ* est désactivée.

GIC et routine d'interruption
=============================

Cette étape consiste à initialiser le GIC dans *U-Boot* et à récupérer l'interruption de *vExt*,
c.-à-d. l'interruption générée par l'appui d'un *switch*.

Dans *U-Boot*, créer la nouvelle commande ``enable_irq`` (comme ``hello`` à l'étape 3 du lab01).
Cette commande doit configurer le GIC, activer les interruptions du périphérique *vExt*, et
gérer leur traitement.

.. warning::
   Il faut d'abord trouver le numéro d'*IRQ* de *vExt* : regarder comment il est défini
   dans ``hw/arm/virt.c`` (table ``irqmap``), puis ajouter un **offset de 32**, car il
   s'agit d'une *IRQ* de type *SPI* (*Shared Peripheral Interrupt*). C'est ce numéro
   (``IRQn``) qui est utilisé dans toute la suite de cette étape.

#. **Initialiser le GIC**, dans la commande ``enable_irq`` :

   #. **Configurer l'affinité avec le CPU0** : écrire ``0x01010101`` à l'offset
      ``0x800 + 4*(IRQn/4)`` du distributeur (registre ``GICD_ITARGETSR``).
   #. **Activer le distributeur** (activation globale).
   #. **Activer l'interface CPU**.
   #. **Configurer les priorités** : ne rien masquer, c.-à-d. mettre les bits
      ``[7..0]`` du registre ``ICCPMR`` à 1.
   #. **Démasquer l'interruption de** *vExt* (activation de la ligne individuelle
      correspondant à ``IRQn`` dans le distributeur).
   #. **Activer l'interruption de** *vExt* côté *QEMU* (activation du périphérique
      source, registre ``IRQ_CTRL_REG``).
   #. **Activer la ligne** *IRQ* **au niveau du CPU** avec ``local_irq_enable()``.

   * Sur la plateforme *virt*, la base du distributeur est à ``0x0800'0000`` et l'interface locale (*CPU Interface*) à ``0x0801'0000``.

#. **Brancher la routine d'interruption.** Ouvrir le fichier ``arch/arm/lib/vector.S``,
   localiser le code d'entrée au vecteur d'interruption associé à une *IRQ*. Repérer
   l'instruction de branchement appelant une fonction en C, puis éditer le fichier
   source ``.c`` contenant cette routine. Modifier cette routine afin qu'elle appelle
   une fonction qui sera implémentée dans le code de la commande ``enable_irq``
   (par exemple ``handle_irq()``) : pour la rendre visible dans ce fichier, il suffit
   de la déclarer en mode ``extern`` au-dessus.

#. **Créer la boucle de gestion d'interruption**, dans ``handle_irq()``, comme le
   ferait *Linux* :

   #. Acquitter l'interruption en lisant le numéro d'*IRQ* au registre ``ICCIAR``
      (l'acquittement se fait automatiquement à la lecture).
   #. Inverser l'état de la LED correspondant au *switch* pressé (si allumée, l'éteindre,
      et inversement).
   #. Terminer la routine en notifiant le CPU : écrire le numéro d'*IRQ* reçu dans le
      registre ``ICCEOIR`` (*End-of-Interrupt*).

#. Tester la commande dans *U-Boot* et avec l'interface graphique (``-g``).

* La fonction ``local_irq_enable()`` permet d'activer la ligne *IRQ* au niveau CPU
  (dernière sous-étape de l'initialisation du GIC ci-dessus).

Rendu du laboratoire
====================

Pour rendre les laboratoires, il faut s'assurer que tout est commit et push sur GitLab.
Attention à ne commit que les modifications utiles et concernant le laboratoire !
Par exemple, il n'est pas nécessaire de commit les fichiers résultant de compilation
(programme, module, ...). Ne pas hésiter à ajouter des règles dans les ``.gitignore`` si besoin.

Ensuite, il faut aller sur la page GitLab de votre repo. Puis, sur le menu à gauche aller dans ``Code > Merge Requests``
et cliquer sur ``New merge request``. En français, ``merge request`` est traduit pas ``requête de fusion``.

Sélectionnez la branche ``lab04`` comme source et la branche ``dev`` comme cible.
Revérifiez les changements effectués et continuez.

Finalement, mettez ``Rendu lab04`` comme titre et ajouter ``CDieperink`` comme *Reviewer* (*Relecteur* en français)
et finalisez en appuyant sur le bouton pour créer la *merge request*.
