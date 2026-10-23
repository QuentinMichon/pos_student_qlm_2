.. _lab08:

======================================
Gestion des événements de type *input*
======================================

:Laboratoire: lab08 (13.11.2025)
:Enseignants: Prof. Daniel Rossier / Clément Dieperink

Objectif de laboratoire
=======================

Dans le noyau Linux, la gestion des événements en provenance d'un périphérique d'entrée comme un
clavier, une souris, un écran tactile ou des *switches* par ex. peut être facilitée grâce au *framework*
dédié aux entrées (*input*). Dans ce cas, les événements sont récupérés et traités par l'application via
une entrée dans ``/dev/input``.

Ce laboratoire se concentre sur la gestion des événements liés aux *switches* du périphérique *vExt*.
L'objectif principal est la réalisation d'une application qui modifie l'état des LEDs lorsqu'on appuie sur
un *switch*.

Gestion des *switches* sur *virt32* avec le *framework* associé aux entrées *input*
===================================================================================

Cette étape vise à adapter le driver du périphérique *vExt* afin qu'une application tournant dans
l'espace utilisateur puisse récupérer un événement de type *input* à l'appui sur un *switch*.

#. Editer le module ``usr/module/access.c`` afin d'enregistrer auprès du *framework* des *input*

  * Définir une structure contenant un champ associé au *device input* ainsi qu'un champ pour stocker le numéro du *switch* pressé.
    Cette structure sera notamment propagée via l'argument ``dev_id`` de la routine de service.

#. Rajouter un **traitement différé** qui reportera au *framework* des *input* deux événements à chaque pression d'un *switch*,
    un ayant la valeur 1 (pression) suivi immédiatement d'un autre avec la valeur 0 (relâche).
#. Identifier l'entrée dans ``/dev/input`` qui est créée après chargement du module.
#. Editer le fichier ``usr/src/vextctl.c`` et réaliser une petite application qui lit en boucle les événements en provenance de cette entrée et qui affiche
    le **type**, le **code** et la **valeur** de l'événement *input*.

  * Il existe le type prédéfini ``struct input_event`` dans ``linux/input.h``.
      Le fichier ``/dev/input/event<n>`` délivre des événements de ce type.

Contrôle des LEDs *vExt* sur *virt32* à partir des *switches*
=============================================================

A présent, le *driver* pilotant *vExt* permet l'accès aux LEDs et la récupération des événements d'entrée liés
aux *switches* depuis une application tournant dans l'espace utilisateur.

Cette étape consiste à réaliser une application qui permet de jouer au Simon.
Ce jeu, de base, consiste en un appareil avec 4 boutons colorés qui peuvent s'allumer.

A chaque tour, une séquence est jouée en allumant les différents boutons et le joueur doit ensuite la reproduire en appuyant sur les boutons.
La séquence se construit au fur et à mesure des tours, en commençant avec un seul et un nouveau est ajouté à la fin de la séquence à chaque tour.
Pour tester par vous-même, ce site contient une version jouable : `https://freesimon.org <https://freesimon.org>`_

Implémenter ce jeu dans l'application user-space de la façon suivante :

* Créer un nouveau fichier ``linux/usr/src/examples/simon.c`` et l'ajouter dans le ``Makefile`` du même dossier
* Dans usr-linux_1.0.bb ajouté une ligne comme pour "hello" à ``do_install_apps``
* Le joueur lance le programme, toutes les LEDs s'allume indiquant que celui-ci est prêt.
* Le joueur doit alors appuyer sur n'importe quel switch pour démarrer la partie.
* A chaque tour, toutes les LEDs s'éteigne et la séquence est jouée.
* Une fois la séquence terminée, la LED centrale s'allume indiquant au joueur qu'il peut la reproduire.
* En cas d'erreur, le programme se termine en indiquant le nombre de tours réussis.
* Seuls les LED 1 à 4 sont utilisées pour la séquence.
* Les switchs sont associés aux LED par leur direction (LED de gauche → switch de gauche)
* Afin de simplifier l'application, la séquence peut être limitée à 20 tours et être prédéfinie (hardcodée) dans le code.
* Il existe un fichier ``linux/input.h`` dans la *toolchain* analogue à celui du noyau.

Portage sur la plateforme *Raspberry Pi 4*
==========================================

Cette étape consiste à porter le *driver vExt* sur la *RPi4* en tenant compte de spécificités de cet environnement.

#. Adapter le *driver* (fichier ``linux/usr/module/access.c``) en conséquence
    et s'assurer que la nouvelle entrée dans ``/dev/input`` soit bien créée.

  * Le prototype de la fonction ``rpisense_joystick_handler_register()`` est défini dans
      ``linux/usr/module/rpisense.h``.

#. Porter l'application ``simon`` en effectuant les adaptations nécessaires.

  * Ne pas oublier de vérifier la présence de l'entrée dans ``/dev/input`` (les noms peuvent changer selon l'environnement des plates-formes).
  * Il devrait être possible de facilement passer le jeu d'une plateforme à l'autre, via des defines
      ou autres mécanismes.
