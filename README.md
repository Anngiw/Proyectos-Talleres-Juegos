# 🎮 Base del Proyecto y Talleres - Godot Engine

Este repositorio contiene la **estructura base del mundo** para los talleres del equipo. 

⚠️ **REGLA DE ORO PARA EVITAR CONFLICTOS EN GIT:**
Para evitar que el código se rompa o existan conflictos de fusión (*merge conflicts*), **bajo ninguna circunstancia se debe trabajar directamente sobre la rama `main` ni modificar los archivos base de los compañeros**.

---

## 📂 Organización de Carpetas

* `res://scenes/characters/` $\rightarrow$ Escenas y scripts de personajes (Jugador, enemigos).
* `res://scenes/objets/` $\rightarrow$ Elementos interactivos del mapa (trampas, coleccionables, áreas).
* `res://scenes/ui/` $\rightarrow$ Interfaz gráfica (HUD, menús, pantallas).
* `res://scenes/world/` $\rightarrow$ Escenas de niveles y mundo principal.
* `res://assets/` $\rightarrow$ Recursos gráficos, modelos 3D, texturas y audios.

---

## 🌿 Flujo de Trabajo Obligatorio por Rama

Cada integrante debe desarrollar sus puntos asignados creando su propia rama independiente:

1. Actualizar antes de empezar:
   ```bash
   git pull origin main