#!/usr/bin/env python3
"""Test standalone de la matrice LED via l'émulateur sense_emu (sans guest QEMU).

Lance d'abord le GUI si besoin (`sense_emu_gui &`), puis exécute ce script.
Il affiche un damier de couleurs et RESTE VIVANT : tant que l'objet SenseHat
existe, son thread interne rafraîchit le fichier partagé /dev/shm/rpi-sense-emu-screen
et le GUI redessine. Ctrl-C pour quitter.
"""
import time
from sense_emu import SenseHat

R = (255, 0, 0)
G = (0, 255, 0)
B = (0, 0, 255)
W = (255, 255, 255)
_ = (0, 0, 0)

pattern = [
    R, _, G, _, B, _, W, _,
    _, R, _, G, _, B, _, W,
    W, _, R, _, G, _, B, _,
    _, W, _, R, _, G, _, B,
    B, _, W, _, R, _, G, _,
    _, B, _, W, _, R, _, G,
    G, _, B, _, W, _, R, _,
    _, G, _, B, _, W, _, R,
]

sense = SenseHat()
sense.set_pixels(pattern)
print("Damier affiché. Regarde la fenêtre sense_emu_gui. Ctrl-C pour quitter.")

try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    sense.clear()
    print("\nÉcran effacé.")
