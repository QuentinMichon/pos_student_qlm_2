.. _lab07:

=======================================
Portage des *LEDs* sur *Raspberry Pi 4*
=======================================

:Laboratoire: lab07 (06.11.2024)
:Enseignants: Prof. Daniel Rossier / Clément Dieperink

Objectif de laboratoire
=======================

Ce laboratoire consiste à porter l'application et le *driver* pilotant les LEDs de *vExt* sur la plateforme *Raspberry Pi 4*.
Le périphérique *vExt* correspond à l'extension *Sense-HAT* de la *RPi 4*. Dans ce cadre, il s'agira de modifier le *driver*
de telle manière à ce qu'il puisse fonctionner pour *virt32* et *RPi 4* en utilisant une propriété du *device tree*.

Réorganisation du *driver* avec une structure privée
====================================================

Si cela n'est pas déjà le cas, il est temps de réorganiser le module et d'utiliser une *structure privée*
au *driver* afin de regrouper les informations spécifiques au périphérique *vExt*. La structure ``platform_device``
comprend un champ de type ``void *`` permettant de gérer une telle structure.

#. Définir un type de structure privée contenant au moins les éléments suivants :

  * Adresse virtuelle pour accéder aux registres I/O de *vExt*.
  * Structure associée aux LEDs.
  * Variable qui sera utilisée pour stocker le type de plateforme.

#. Adapter et compléter le module afin d'utiliser la structure privée dans les différentes fonctions *callbacks* du *driver*.

  * A partir de maintenant, il ne doit plus y avoir de variable globale dans le module.
  * Pour la fonction *callback* ``led_set()``, il faut se rappeler qu'une référence vers la structure
      ``platform_device`` est passée comme argument à l'enregistrement de chaque LED, en tant que *device* parent.
      L'utilisation de ``container_of()`` permettra de récupérer la référence vers ``platform_device`` et la fonction
      ``platform_get_drvdata()`` de récupérer la structure privée.

Modification du *device tree*
=============================

Editer les *device tree* de *virt32* et *RPi4* pour ajouter la nouvelle propriété ``plateform_type``
au noeud du périphérique *vExt*. Cette propriété consiste en une chaîne de caractères qui permettra au module de connaître
le type de plateforme (``virt32`` ou ``rpi4``).

* Pour rappel, les devices trees sont dans les fichiers suivants:

  * ``linux/linux/arch/arm/boot/dts/arm/virt32.dts``
  * ``linux/linux/arch/arm/boot/dts/broadcom/bcm2711-rpi-4-b.dts``

Adaptation du *driver* pour *vExt* sur *RPi4*
=============================================

Cette étape consiste à modifier le driver pour la gestion de *vExt* afin de gérer les deux plateformes (*virt32* et *RPi4*).

#. Adapter le *driver* afin de récupérer la propriété permettant d'identifier la plateforme et modifier la fonction ``probe()`` en conséquence.

  * Ne pas oublier de modifier ``build.conf`` avant de compiler le module.
  * Après ces modifications, il ne doit plus être nécessaire de modifier le driver pour le compiler entre *virt32* et *rpi4*
  * Attention, certaines opérations effectuées dans les laboratoires précédents sont propres à la plateforme *virt32*.
      Il est donc important de gérer le ``probe`` selon la plateforme choisie dans le device tree.

#. Déployer le *driver* sur la *RPi4*, charger le module et vérifier la présence des entrées dans ``/sys/class/leds``.
#. Tester l'application développée dans le laboratoire précédent.

Validation sur l'environnement *virt32*
=======================================

Valider que le module et l'application fonctionnent toujours sous *virt32* en les recompilant et en les déployant sur celle-ci.
