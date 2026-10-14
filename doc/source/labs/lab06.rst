.. _lab06:

==========================================
Accès au *framework* des LEDs sous *Linux*
==========================================

:Laboratoire: lab06 (26.10.2026)
:Enseignants: Prof. Daniel Rossier / Luc Reveyron

Objectif de laboratoire
=======================

Un pilote de périphérique (*driver*) n'a d'intérêt que s'il peut être utilisé par des applications
nécessitant des accès à ce périphérique. C'est pourquoi ce laboratoire propose d'examiner une
première manière d'interagir avec le driver au travers du système de fichier ***sysfs*** disponible
sous *Linux*.

Après avoir augmenté le *driver* avec les structures nécessaires à la gestion des LEDs au travers
de *sysfs*, il s'agira de développer une petite application qui pilote l'allumage/l'extinction de celles-ci.

Utilisation du *framework* des LEDs sous *Linux*
================================================

L'environnement est celui de *virt32* (*QEMU*). Il faut donc modifier ``build.conf`` en conséquence
et également remettre le code de la fonction ``probe`` pour celui de *virt32*.

L'utilisation des LEDs au niveau application s'effectuera à l'aide des entrées de ``/sys``. On
souhaite avoir autant d'entrées que de LEDs disponibles, c.-à-d. cinq entrées de classe LED.

#. Editer et compléter le code source du *driver* (module) afin de pouvoir gérer cinq entrées de
    classe LED (une pour chaque LED).

  * Inclure le fichier ``linux/leds.h``.
  * Le nom de l'entrée peut s'appeler ``vext_ledX`` pour la LED X.
  * La LED correspondante à l'entrée doit être allumée/éteinte en fonction de la brightness.

#. Démarrer *Linux* et charger le *driver* dans le noyau.
#. Observer les entrées dans ``/sys/class/leds`` et examiner le contenu des sous-répertoires
    associés aux LEDs de *vExt*.
#. Effectuer une écriture dans l'entrée ``brightness`` d'une LED pour valider l'exécution de la
    fonction set du *driver*, comme suit :

    .. code-block:: c

       pos_linux# echo 1 > /sys/class/leds/vext_led2/brightness

  * Le *driver* devrait allumer la LED 2.

Application dans l'espace utilisateur
=====================================

Le *driver* est prêt à être utilisé par une application *user-space*.

#. Créé le fichier ``usr/src/vextctl.c`` afin d'allumer les LEDs une à une, en allant dans l'ordre LED0, LED1, LED2, ...
    avec un intervalle de 750 millisecondes entre chaque LED, puis de les éteindre une à une dans l'ordre inverse avec le même intervalle de temps.

  * D'ajouter ``vextctl`` au ``CMakelist``.
  * Ne pas oublier de repositionner le curseur du fichier dans ``/sys`` à 0 avant chaque écriture.
  * La fonction ``usleep(<us>)`` permet d'attendre ``us`` microsecondes.
