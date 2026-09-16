.. _vext_json_api:

=======================================================
API de la librairie JSON pour l'application Sense-HAT
=======================================================

Ce document décrit les fonctions de communication entre l'émulateur *QEMU* et
l'interface graphique d'émulation « *Sense-HAT* ».

Architecture générale
======================

La communication entre l'émulateur et le *frontend* graphique est assurée par deux
*threads* s'exécutant dans le processus *QEMU* et deux autres *threads* s'exécutant
dans le processus de l'application graphique. Dans les deux cas, un *thread* gère
l'émission de messages tandis que l'autre réagit à la réception de messages. Les
messages sont échangés sur une socket TCP, en local, sur la machine exécutant le
*framework* d'émulation.

.. list-table:: Architecture générale de l'interface de communication QEMU avec le GUI
   :header-rows: 1

   * - Côté
     - Composant
     - Rôle
   * - *QEMU* (``qemu/hw/arm/vext/``)
     - *Command Processing Thread* (CPT)
     - Envoie les commandes (p.ex. LEDs) vers la GUI via ``vext_cmd_post()``
   * - *QEMU* (``qemu/hw/arm/vext/``)
     - *Event Processing Thread* (EPT)
     - Réceptionne les évènements (p.ex. *switch*) via ``vext_process_switch()``
   * - *Sense-HAT GUI* (``sense-hat/``)
     - *Command Gateway*
     - Reçoit les commandes et pilote LEDs, *Sensors*, *Gyroscope*
   * - *Sense-HAT GUI* (``sense-hat/``)
     - *Event Gateway*
     - Emet les évènements du *Switch* vers *QEMU*

Le périphérique *vExt* (côté *QEMU*) relaie ainsi les LEDs, *Switch*, *Sensors* et
*Gyroscope* vers/depuis le GIC et le CPU (l'*IRQ* de *vExt* est l'*IRQ* 50, voir
:ref:`vexpress_register_description`).

Format des messages
--------------------

Les messages échangés entre *QEMU* et la *GUI* sont formatés de manière générique,
sous forme d'objets JSON séparés par des retours à la ligne. Les données de ces
objets sont stockées sous forme de paires **clé/valeur**, les clés étant sous forme
de texte.

Chacun de ces objets JSON doit posséder une clé « ``device`` » indiquant le
périphérique correspondant au message, sous forme d'une chaîne de caractères. Les
autres champs présents dans l'objet JSON sont spécifiques à chaque périphérique
concerné.

*QEMU* n'inclut pas nativement de fonctionnalités de support JSON. La bibliothèque
externe « **cJSON** » est donc utilisée pour générer et parser le JSON dans *QEMU*.

Envoi de commandes depuis QEMU
===============================

L'envoi d'un message depuis le code d'émulation s'effectue selon la séquence
ci-dessous (avec un périphérique imaginaire ``my_device``).

.. code-block:: c

   cJSON *root = cJSON_CreateObject(); /* Creation of the JSON object */

   cJSON_AddStringToObject(root, "device", "my_device");

   cJSON_AddStringToObject(root, "status", "run"); /* Value of type string */
   cJSON_AddNumberToObject(root, "speed", 10)      /* Value of type integer */

Pour terminer, on utilise la fonction ``vext_cmd_post`` pour mettre en queue l'envoi
du paquet.

.. code-block:: c

   vext_cmd_post(root);

Le paquet sera ensuite mis en queue et envoyé automatiquement, et l'espace mémoire
qui lui était réservé sera automatiquement nettoyé. Les noms des périphériques dans
l'interface *Sense-HAT*, ainsi que les clés/valeurs attendues par les périphériques
implémentés, sont présentées dans le tableau ci-après.

.. list-table:: LEDs
   :header-rows: 1

   * - Clé
     - Valeur
   * - ``device``
     - ``led``
   * - ``value``
     - Entier dont les 8 bits LSB définissent l'état des LEDs

Réception d'événements (events) dans QEMU
===========================================

Les messages envoyés par l'interface graphique sont récupérés dans la fonction
``sp6_emul_event_handle()``. Le paquet JSON parsé se retrouve dans la variable
locale ``root``.

.. note::
   Dans le code de ce dépôt (``qemu/hw/arm/vext/vext_emul.c``), cette fonction se
   nomme ``vext_emul_event_handle()`` (et non ``sp6_emul_event_handle()`` comme dans
   le document original — le préfixe ``sp6`` vient d'une version antérieure/générique
   du périphérique, renommé ``vext`` dans ce fork).

La valeur correspondant à chacune des clés se récupère en utilisant la fonction
``cJSON_GetObjectItem()``, dont voici le prototype :

.. code-block:: c

   cJSON *cJSON_GetObjectItem(cJSON *root, const char *key);

Si la valeur attendue pour cette clé-là est une chaîne de caractères, elle peut être
récupérée via son attribut ``valuestring``. Si l'on attend une valeur numérique,
celle-ci peut être récupérée via son attribut ``valueint``.

La seule clé obligatoirement présente dans le message JSON en provenance de *QEMU*
est ``device``. La valeur textuelle correspondant à cette clé est inspectée afin de
déterminer à quel périphérique est destiné le paquet.

.. code-block:: c

   char *dev = cJSON_GetObjectItem(root, "device")->valuestring;

En fonction de l'identifiant de périphérique, il est ensuite possible d'associer une
fonction au message, qui aura pour rôle d'exploiter les autres données présentes dans
la structure ``cJSON``.

.. code-block:: c

   if (!strcmp(dev, "my_device"))
       process_my_device(root);

Les paires clé/valeur émises par chacun des périphériques d'entrée de l'interface
graphique « *Sense-HAT* » (*switch* uniquement pour le moment) sont affichées dans le
tableau ci-dessous.

.. list-table:: Switch
   :header-rows: 1

   * - Clé
     - Valeur
   * - ``device``
     - ``switch``
   * - ``status``
     - Entier dont les 8 bits LSB indiquent l'état des boutons

La fonction ci-dessous est une fonction d'exemple de traitement pour les messages en
provenance des *switch* :

.. code-block:: c

   void process_switch(void *opaque, cJSON *packet)
   {
       int swStatus = cJSON_GetObjectItem(root, "status")->valueint;

       printf("0x%x\n", swStatus);
   }
