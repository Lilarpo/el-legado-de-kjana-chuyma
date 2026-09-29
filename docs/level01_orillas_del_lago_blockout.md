# Nivel 1 — Orillas del Lago

Escena jugable: `res://scenes/levels/level01_orillas_del_lago.tscn`

## Recorrido

| Zona | Rango X aproximado | Contenido |
| --- | ---: | --- |
| 1. Entrada segura | 0–850 | Spawn, Mama Tika y Hoja #1 en plataformas opcionales |
| 2. Primeros encuentros | 1.030–1.900 | Primer enemigo y segundo encuentro espaciado |
| 3. Ascenso y desvío | 2.150–3.550 | Ruta que sube y baja, combate y camino a Hoja #2 |
| 4. Precipicio de plataformas | 3.550–4.100 | Tres apoyos a distintas alturas sobre el vacío |
| 5. Santuario | 4.100–6.000 | Combate previo y único santuario en X=5.400 |
| 6. Sed Blanca | 6.000–7.900 | Dos precipicios, hazards visibles, dos enemigos y Hoja #3 |
| 7. Encuentro y recompensa | 7.900–9.450 | Dos enemigos y Fragmento del Legado #1 |
| 8. Cierre | 9.450–10.800 | Kjana-Chuyma, prueba de doble salto y salida |

Los cinco sectores de caída están en X=850–1.030, 1.900–2.150, 3.550–4.100, 6.000–6.600 y 7.600–7.900. Los huecos anchos contienen apoyos de 180 px y desniveles de 60–80 px; la ruta previa a Kjana queda por debajo del alcance calculado del salto normal de Wayra (unos 138 px verticales y 290 px horizontales con carrera).

## Arte y backtracking

- `Terrain` se conserva oculto.
- `GroundVisual` conserva el TileSet de `inca_front.png` y está listo para pintarse sin cambiar las colisiones.
- Las colisiones viven en `Geometry`; sus polígonos marrones/grises son placeholders de blockout.
- `FutureDoubleJumpPlatform`, `FutureDoubleJumpLedge_02` y el arco del fondo señalan rutas futuras que no bloquean el recorrido obligatorio.
- `FutureFlyingEnemySpawn_01` reserva una posición sin añadir IA nueva.
- `SedBlanca_Hazard_01` y `SedBlanca_Hazard_02` reutilizan `KillZone`: son visibles, dañan y devuelven al último checkpoint.

## Salida pendiente

`LevelTransition_To_RuinasAncestrales` usa el componente reutilizable `LevelTransition` y ya apunta a `level02_ruinas_ancestrales.tscn`; el identificador de llegada es `FromOrillas`.

Mama Tika contextualiza el objetivo en X=360. La conversación final con Kjana-Chuyma en X=9.650 activa `GameState.unlocked_abilities["double_jump"]`; Wayra puede entonces hacer un segundo salto sin cambios en los valores del salto normal. `DoubleJumpTestPlatform`, en X=9.950, permite probarlo antes de la salida.
