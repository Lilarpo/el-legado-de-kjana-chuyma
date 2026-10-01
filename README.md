# El Legado de Kjana-Chuyma

Metroidvania 2D de aventura y combate ambientado en un mundo ficticio inspirado en paisajes andinos, ruinas ancestrales y un lago. **Plataformas: Android y PC. Estado: Semana 4, versión final jugable.** El autor confirmó la exportación del APK, su instalación y el arranque en un teléfono Android real.

## Enlaces de entrega

- **Repositorio:** https://github.com/Lilarpo/el-legado-de-kjana-chuyma
- **Gameplay/tráiler:** enlace no incluido en este repositorio; debe añadirse cuando el autor facilite la URL de entrega.
- **GDD Final:** no incluido en este repositorio; pendiente de enlazar al documento original.
- **Godot utilizado:** Godot 4.x; proyecto configurado con características de Godot 4.7 y validado localmente con Godot 4.7.2.
- **APK final:** disponible como archivo de entrega del autor; no hay enlace de descarga publicado aquí.

## Descripción

Wayra recorre tres mapas, habla con personajes, supera enemigos y reúne Fragmentos del Legado para llegar al Guardián Sediento. La exploración abre nuevas rutas mediante habilidades obtenidas durante la aventura. El desenlace depende de los fragmentos reunidos al terminar la pelea final.

## Objetivo del juego

Avanzar desde Orillas del Lago hasta Santuario Profundo, derrotar al Guardián Sediento, recoger el Fragmento #3 que aparece tras su muerte y alcanzar el final. Reunir también los dos fragmentos anteriores permite ver el Final Verdadero.

## Características principales

- Tres niveles: Orillas del Lago, Ruinas Ancestrales y Santuario Profundo.
- Combate con lanza, Parry y Perfect Parry, Doble Salto y Contraataque desbloqueables.
- Nueve Hojas de Coca, tres Fragmentos del Legado y dos Pociones de Protección naturales.
- Altares con checkpoint y guardado persistente, opción **Continuar** y pantalla **MORISTE**.
- Guardián Sediento de dos fases, música, efectos de sonido, opciones de volumen y dos cinemáticas finales alternativas.
- Teclado/mando en PC y botones táctiles independientes en Android; pantalla de Controles con pestañas **PC** y **ANDROID**.

## Mecánicas

**Perfect Parry:** al detener un ataque parryable durante su ventana, Wayra evita ese golpe y puede ganar postura contra el Guardián. El destello blanco del jefe anuncia la ventana. El bloqueo normal no otorga postura.

**Doble Salto:** habilidad obtenida durante la progresión; permite alcanzar las plataformas superiores de Ruinas Ancestrales y Santuario Profundo.

**Contraataque:** tras desbloquearlo, un Perfect Parry prepara el siguiente ataque que **realmente conecte**. Ese impacto inflige ×2 daño. Si el ataque falla, la carga permanece.

**Hojas de Coca:** cada grupo de tres se consume automáticamente para sumar **+1 corazón máximo permanente** y restaurar **toda la salud hasta el nuevo máximo**. Las nueve hojas permiten hasta tres corazones adicionales; los sobrantes se conservan para la siguiente mejora.

**Recompensas:** `RewardOverlay` presenta Doble Salto, Contraataque y Nuevo Corazón; pausa el gameplay y atenúa el fondo mientras continúa la música. La transición entre mapas utiliza una tarjeta negra de título para **MAPA 2 — RUINAS ANCESTRALES** y **MAPA 3 — SANTUARIO PROFUNDO**.

## Controles PC

La pantalla **Controles → PC** consulta `InputMap.action_get_events()` al abrirse, por lo que muestra las asignaciones actuales del proyecto. En la configuración versionada:

| Acción | Tecla |
|---|---|
| Izquierda / derecha | A / D o ← / → |
| Salto y Doble Salto | Espacio o W |
| Ataque | J |
| Parry / Perfect Parry | K |
| Interactuar | E |
| Usar Poción de Protección | Q |
| Pausa | Escape |

El mando tiene asignaciones de cruceta, salto, ataque, parry y poción en el `InputMap`. Los botones del menú principal son **Nueva Partida**, **Continuar**, **Opciones**, **Controles** y **Salir**. Pausa ofrece **Reanudar**, **Opciones**, **Controles** y **Salir al menú**.

## Controles Android

Dos botones separados **←** y **→** mueven a Wayra. **↑** salta o hace Doble Salto cuando está desbloqueado; **lanza** ataca; **escudo** ejecuta Parry/Perfect Parry; **mano** interactúa; **poción** usa una Poción de Protección; **Pausa** abre el menú. La pantalla **Controles → ANDROID** muestra los mismos iconos que la UI táctil.

El botón **Interactuar** solo aparece cerca de un elemento interactuable. El de **Poción** solo aparece cuando Wayra posee al menos una; si ya hay protección activa, se atenúa y no permite apilarla. El HUD de fragmentos, coca y pociones queda bajo Pausa con un margen de 22 px calculado desde el borde inferior real del botón.

## Niveles

| Mapa | Escena | Contenido principal |
|---|---|---|
| Orillas del Lago | [`level01_orillas_del_lago.tscn`](scenes/levels/level01_orillas_del_lago.tscn) | Introducción, Mama Tika, exploración inicial y Doble Salto. |
| Ruinas Ancestrales | [`level02_ruinas_ancestrales.tscn`](scenes/levels/level02_ruinas_ancestrales.tscn) | Plataformas verticales, Cóndor Corrompido y Contraataque. |
| Santuario Profundo | [`level03_santuario_profundo.tscn`](scenes/levels/level03_santuario_profundo.tscn) | Tramo final, arena y Guardián Sediento. |

`pueblo_wayra.tscn` es una escena de prototipo/pruebas presente en el repositorio y no se cuenta como cuarto nivel de la aventura principal.

## Enemigos

**Espectro Sediento** patrulla y ataca durante la exploración. **Cóndor Corrompido** añade presión aérea. Dos enemigos concretos tienen configurado un drop de Poción de Protección con identificadores únicos; los demás no aumentan ese suministro natural. Ambos tipos conservan su lógica de reaparición al restaurar el estado del checkpoint.

## Guardián Sediento

Jefe final de **12 HP** y dos fases. Cambia a Fase 2 alrededor del **50 %** de salud, con ataques más rápidos. Usa mordida/embestida, barrido, proyectiles y, en Fase 2, secuencias y zonas de corrupción. La mordida tiene una señal visual de Perfect Parry; no todos los ataques admiten parry. Su postura tiene **3 puntos**: **1 Perfect Parry = +1 punto** o **4 ataques normales conectados = +1 punto**. Al llegar a 3/3 entra en estado vulnerable durante **4 segundos**, cuando los ataques pueden reducir su HP; al terminar, la postura se restablece. La muerte completa libera el Fragmento #3.

## Sistema de progresión

Cada uno de los tres mapas principales contiene un Fragmento del Legado y tres Hojas de Coca. Las habilidades Doble Salto y Contraataque se obtienen durante el recorrido y se conservan en el guardado. El Fragmento #3 aparece solo después de terminar la muerte del Guardián. La salida final requiere haber derrotado al jefe y recogido ese fragmento; por eso una partida normal llega al desenlace con al menos un fragmento.

## Sistema de guardado

Interactuar con un altar restaura `health = max_health`, fija el checkpoint y guarda en `user://savegame.cfg`. **Continuar** desde el menú carga el último guardado válido, incluyendo escena, habilidades, vida máxima, coleccionables y pociones. La pantalla **MORISTE** ofrece **Continuar** o **Salir al menú**; al continuar, Wayra reaparece con la salud completa. Los drops de poción recogidos y consumidos se registran para evitar duplicaciones.

## Sistema de pociones

Hay **dos** Pociones de Protección disponibles naturalmente por partida, obtenidas como drops garantizados de dos enemigos específicos. Se guardan en inventario y se activan manualmente. Cada una absorbe **3 impactos válidos**; no se pueden apilar. El HUD muestra existencias y cargas restantes. Su progreso persiste en el guardado existente.

## Finales

| Fragmentos al activar el desenlace | Cinemática | Tarjeta final |
|---|---|---|
| **1 o 2** | `ending_01_guardian.ogv` | **FIN** |
| **3** | `ending_02_epilogue.ogv` | **CONTINUARÁ** |

Solo se reproduce **una** de las dos cinemáticas. El código trata 0 fragmentos como Final Normal de forma defensiva, pero ese estado no es alcanzable en el flujo jugable normal porque el Fragmento #3 es obligatorio tras el jefe.

## Plataforma y requisitos

Proyecto Godot 4.x/GDScript para PC y Android. Resolución base **1280×720**, interfaz horizontal, renderizador GL Compatibility y preset Android **arm64-v8a**. El autor verificó que el APK se genera, instala y abre en un teléfono Android real con orientación horizontal, controles táctiles y HUD visibles. El modelo, resolución y versión Android del dispositivo no están documentados en el repositorio.

## Cómo ejecutar el proyecto

1. Clonar este repositorio y abrir `project.godot` en Godot 4.7.x.
2. Esperar la importación de recursos.
3. Ejecutar la escena principal desde el editor; está configurada como `res://scenes/ui/main_menu.tscn`.
4. Para una comprobación automatizada local, ejecutar las escenas de `tests/` con `godot --headless --path . res://tests/<prueba>.tscn` usando un binario Godot compatible.

## Cómo generar el APK

1. Configurar en Godot el SDK de Android y las plantillas de exportación compatibles con la versión del editor.
2. Abrir **Proyecto → Exportar** y seleccionar el preset **Android** de `export_presets.cfg`.
3. Revisar el paquete `com.dani.ellegadodekjanachuyma` y el destino del APK; el preset actual apunta a `../android/El_Legado_de_Kjana_Chuyma.apk`.
4. Exportar para prueba o configurar una firma de publicación propia antes de exportar la versión de entrega. Mantener cualquier keystore y credenciales privadas fuera de Git.
5. Instalar el APK resultante en un dispositivo compatible y ejecutar la matriz de [QA Android](docs/qa_android_final.md).

## Estructura del proyecto

| Ruta | Contenido |
|---|---|
| `assets/` | Sprites, UI, música, SFX y vídeos finales. |
| `scenes/` | Niveles, jugador, enemigos, jefe, objetos, UI y VFX. |
| `scripts/` | Estado, guardado, niveles, combate, audio y menús. |
| `tests/` | Pruebas automatizadas de regresión. |
| `docs/` | Blockouts, notas de validación y matriz QA Android. |
| `project.godot`, `export_presets.cfg` | Configuración de Godot y exportación Android. |

## Evidencias del Checklist

El **checklist oficial con los nombres exactos de sus 10 criterios no está en este repositorio**. Por eso se numeran las filas sin atribuirles un nombre inventado. Las evidencias de los criterios 6, 7 y 8 siguen las descripciones proporcionadas por el autor; la asociación del resto requiere el checklist original. No se asignan timestamps sin el vídeo de entrega.

| # | Criterio | Evidencia en el proyecto | Evidencia documental / video |
|---|---|---|---|
| 1 | Nombre oficial pendiente de checklist | Por vincular al criterio oficial. | GDD Final no disponible aquí. |
| 2 | Nombre oficial pendiente de checklist | Por vincular al criterio oficial. | GDD Final no disponible aquí. |
| 3 | Nombre oficial pendiente de checklist | Por vincular al criterio oficial. | GDD Final no disponible aquí. |
| 4 | Nombre oficial pendiente de checklist | Por vincular al criterio oficial. | GDD Final no disponible aquí. |
| 5 | Nombre oficial pendiente de checklist | Por vincular al criterio oficial. | GDD Final no disponible aquí. |
| 6 | Nombre oficial pendiente; demostración funcional según el encargo | [`main_menu.tscn`](scenes/ui/main_menu.tscn) y los tres niveles. | Gameplay/tráiler entregado por el autor; URL y timestamps por añadir. |
| 7 | Nombre oficial pendiente; flujo de juego según el encargo | `GameState`, niveles, altares, jefe y [`ending_sequence.gd`](scripts/ui/ending_sequence.gd). | Sección **Flujo de juego**; gameplay/tráiler sin URL aquí. |
| 8 | Nombre oficial pendiente; dificultad técnica según el encargo | [`guardian_sediento.gd`](scripts/bosses/guardian_sediento.gd), [`player.gd`](scenes/player/player.gd), [`ParryFlash.tscn`](scenes/vfx/ParryFlash.tscn). | Sección **Dificultad técnica y solución**; gameplay/tráiler sin URL aquí. |
| 9 | Nombre oficial pendiente de checklist | Por vincular al criterio oficial. | GDD Final no disponible aquí. |
| 10 | Nombre oficial pendiente de checklist | Por vincular al criterio oficial. | GDD Final no disponible aquí. |

## Flujo de juego

```text
Explorar
  ↓
Combatir / utilizar Perfect Parry
  ↓
Recolectar coca, fragmentos y recursos
  ↓
Desbloquear habilidades
  ↓
Activar checkpoint
  ↓
Superar obstáculos
  ↓
Avanzar al siguiente nivel
  ↓
Enfrentar al Guardián Sediento
  ↓
Final según fragmentos
```

La exploración y el combate alimentan la progresión: las recompensas abren nuevas rutas, los altares conservan el avance y la victoria sobre el jefe desemboca en **FIN** o **CONTINUARÁ** según los fragmentos. La demostración funcional se realizó mediante el gameplay/tráiler entregado por el autor; falta incorporar su enlace al repositorio. No se presupone una defensa en vivo.

## Dificultad técnica y solución

El reto principal fue sincronizar el destello de Perfect Parry del Guardián con la ventana en la que el golpe puede bloquearse. Si el jugador pulsaba Parry al ver la señal, el orden entre la `AttackHitbox`, el daño por contacto y la ventana podía causar daño. La solución actual inicia el destello junto con la ventana, da prioridad al Perfect Parry, marca el ataque como resuelto y aplica un breve margen contra el daño de contacto del mismo evento. Otro reto fue adaptar el `InputMap` a botones táctiles independientes para multitouch y acciones contextuales sin alterar el control de PC.

## QA / Pruebas

La [matriz QA Android](docs/qa_android_final.md) distingue hechos confirmados por el autor, verificaciones automatizadas de Godot y acciones que aún necesitan una sesión manual en el teléfono. En este repositorio hay pruebas para controles móviles, jefe, finales y regresión de Semana 4. No se inventan resultados de usuarios externos ni datos del dispositivo.

## Tecnologías

Godot 4.x, GDScript, escenas `tscn`, pixel art, audio del juego y cinemáticas `.ogv` Ogg Theora. Git/GitHub conserva el historial de desarrollo.

## Autor

**Daniel Antonio Arias Poma.** Proyecto: *El Legado de Kjana-Chuyma*.
