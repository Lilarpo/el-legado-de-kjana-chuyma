# Semana 4 — continuación y validación final

Fecha: 2026-09-26. Motor probado: Godot 4.7.2 estable.

## Ya estaba implementado al retomar

Se inspeccionaron los archivos actuales y la copia `/tmp/week4_before` conservada por la ejecución anterior. Gran parte del proyecto todavía figura como archivos sin seguimiento en Git; el diff de Git por sí solo no representa esta pasada.

- Contraataque como carga booleana única, sin caducidad: daño ×2 transmitido en la señal del golpe y consumo solamente cuando disminuye la vida del objetivo.
- Parry perfecto separado del bloqueo: confirmación al pulsar dentro del destello, con comprobación de alcance y orientación. El contacto y mantener Parry desde antes no conceden recompensa.
- Destellos de mordida, mordida doble y coletazo, en ambas fases del Guardián. Proyectiles y corrupción quedan excluidos.
- Postura del Guardián: exactamente tres confirmaciones; vulnerabilidad de 4 segundos; recuperación a postura cero.
- Spawn del Guardián en X=17660, a 340 px de la pared final. Cámara temporal de presentación para mantener visibles a Wayra y al jefe; se restaura al acercarse, al reintentar o al morir el jefe.
- Presentación conservada: emergencia de aproximadamente 1 s, pose de 0.9 s y espera inicial de 0.55 s antes de seleccionar un ataque. No hay un golpe inmediato.
- Eliminación de las llamas repetidas de Sed Blanca, conservando superficie, borde, dimensiones, daño y colisión.
- Tres hojas consumidas por mejora: +1 salud máxima y +1 salud actual, conservando sobrantes. Nueve hojas únicas permiten +3 corazones. Los IDs recogidos y las mejoras persisten al morir.
- Escenas de Pausa y Muerte; Theme, Opciones y Controles extraídos para compartirlos con Main Menu; conexiones a los callbacks de respawn existentes.
- Música y sonidos de interfaz configurados para procesarse durante la pausa.

No se reconstruyeron estos sistemas.

## Correcciones realizadas al retomar

1. **HUD al cargar niveles:** la señal inicial de Wayra llegaba antes de inicializarse los nodos del HUD. `update_from_player()` ahora espera a que el HUD esté listo; su `_ready()` conserva la actualización inicial. Se eliminó la referencia nula reproducida en los tres niveles.
2. **Salir rápidamente al menú:** una transición musical pendiente podía reemplazar posteriormente la música del menú. Una petición de la pista que ya está sonando ahora cancela la transición pendiente y restaura su volumen sin reiniciar la reproducción.
3. **Paneles de pausa:** el contenido central de Pausa se oculta mientras Opciones o Controles están abiertos y reaparece al volver. Evita texto superpuesto y foco en botones que quedan detrás del panel.
4. **Muerte:** los botones indican `Continuar` y `Salir al menú`, evitando que `SALIR` sugiera cerrar la aplicación.
5. Se añadió una prueba reproducible que recorre las escenas reales y sus señales, e inspección renderizada mediante Godot MCP.

### Archivos modificados en esta continuación

- `scripts/ui/hud.gd`
- `scripts/autoload/music_manager.gd`
- `scripts/ui/pause_menu.gd`
- `scenes/ui/death_screen.tscn`

### Archivos creados en esta continuación

- `tests/week4_polish_smoke.gd` y su UID de Godot.
- `tests/week4_polish_smoke.tscn`
- `docs/semana4_validacion_final.md`

### Archivos compartidos que ya existían al retomar

- `scenes/ui/menu_theme.tres`
- `scenes/ui/menu_panels.tscn` y `scripts/ui/menu_panels.gd`
- `scenes/ui/death_screen.tscn` y `scripts/ui/death_screen.gd`
- `scenes/ui/pause_menu.tscn` y `scripts/ui/pause_menu.gd`

Las escenas de los mapas, NPCs, diálogos, arte, AudioSettings y estadísticas del jefe no se editaron en esta continuación.

## Comportamiento final

**Pausa:** Escape; fundido de 0.2 s; Reanudar, Opciones, Controles y Salir al menú. Sin Reiniciar. Los paneles comparten la misma escena y Theme con Main Menu y los mismos tres volúmenes de AudioSettings. Volver regresa a Pausa. La música sigue avanzando.

**Muerte:** gameplay detenido inmediatamente a 0 HP; animación existente de daño durante 0.5 s y fundido negro de 0.6 s; después MORISTE. Wayra no tiene una animación específica de muerte en los recursos actuales, por lo que se conserva `hurt` como presentación previa. Continuar invoca el respawn del nivel, recupera salud completa y control, conserva progreso y limpia/restablece el encuentro. Salir al menú desactiva la pausa y recupera `main_menu.mp3`.

**Parry del Guardián:** el destello cubre el frame inmediatamente anterior al golpe. Duraciones nominales:

| Ataque | Fase 1 | Fase 2 |
| --- | ---: | ---: |
| Mordida y cada mordida doble | 0.154 s | 0.118 s |
| Coletazo | 0.133 s | 0.100 s |

Pulsar durante la ventana, al alcance y mirando hacia el enemigo, concede una confirmación. Un bloqueo normal no aumenta postura ni prepara Contraataque. Tres confirmaciones abren 4 s de vulnerabilidad. La carga de Contraataque no se acumula, no se consume al fallar ni ante invulnerabilidad; el siguiente golpe dañino aplica ×2 y los posteriores vuelven al daño normal.

**Coca:** 2 hojas → sin mejora; tercera → contador 0 y nuevo corazón; cuarta total → contador 1. Las 9 hojas únicas de los tres niveles elevan el máximo de 3 a 6. Reintentar no vuelve a otorgar hojas ya consumidas.

## Validación ejecutada

Ejecutar desde la raíz del proyecto:

```sh
godot --headless --path . res://tests/week4_polish_smoke.tscn
```

También puede abrirse `tests/week4_polish_smoke.tscn` y ejecutarse con F6. Esta escena inicia una partida de prueba y finaliza automáticamente; no debe configurarse como escena principal. Restaura los valores de volumen que encuentra antes de modificarlos durante la prueba.

La prueba realiza transiciones reales de escena, activa señales de botones/recogida y callbacks de diálogo, e inyecta el input de pausa. Para los casos límite del combate posiciona a Wayra y controla frames; por separado deja avanzar las animaciones para medir la ventana natural. Es una prueba automatizada, no una partida manual completa.

- Main Menu → Nueva partida → nivel 1 → nivel 2 → nivel 3, sin errores de parseo, recursos faltantes ni referencias nulas en el recorrido final.
- Pausa repetida con input; Reanudar; los tres sliders; Volver desde Opciones y Controles; Salir al menú; música avanzando sin pausa.
- Tres hojas en cada nivel, mejora al pasar 2→3, resto de una con cuatro, HUD y Wayra sincronizados, duplicados rechazados, progreso conservado al morir.
- Desbloqueos existentes de Doble Salto y Contraataque mediante finalización de los diálogos de Kjana-Chuyma.
- Sed Blanca mantiene colisión y daño y carece de los sprites de llamas repetidas.
- Spawn lejano e introducción sin hitbox activa.
- Animaciones naturales de los tres ataques parryables en ambas fases: apertura del destello antes del golpe y cierre al activarse el ataque.
- Parry temprano, tardío, por contacto y fuera de alcance sin recompensa. Parry dentro del destello suma exactamente uno; una confirmación no puede repetirse.
- Tres parries, vulnerabilidad, recuperación de postura, Contraataque fallido/conectado/normal y golpe contra invulnerabilidad.
- Transición al 50 % de HP y Fase 2 conservadas.
- Daño ×2 y siguiente golpe normal en Espectro y Cóndor, respetando su invulnerabilidad de daño existente.
- Muerte durante el encuentro; MORISTE; música avanzando; Continuar al checkpoint; salud completa; jefe a 12 HP, Fase 1, postura cero; puerta abierta y trigger rearmado.
- Destrucción de proyectiles, zonas y VFX del encuentro anterior. Nueva entrada con un solo Guardián. Segunda muerte y salida al menú.

Resultado headless final: **110 comprobaciones aprobadas, 0 fallos; registro sin errores ni advertencias**. La cantidad incluye las comprobaciones individuales de los nodos temporales que permanecen vivos al iniciar el reintento.

La ejecución gráfica mediante **Godot MCP también completó 110 comprobaciones con 0 fallos**. Se inspeccionaron capturas de Pausa, Opciones, Controles, MORISTE, Sed Blanca, presentación del Guardián y destello del coletazo. La medición estricta en segundos se hace headless; en la ejecución gráfica se comprueba la correspondencia entre ventana y frames, y las capturas se realizan por separado para no distorsionar esa medición.

## Revisión manual recomendada

Queda la valoración humana del ritmo: combatir usando teclado/mando para decidir si la ventana se siente cómoda y la presentación del jefe suficientemente épica. También escuchar la mezcla en el equipo del jugador; la prueba verifica reproducción, continuidad y buses, pero no sustituye una escucha humana. No queda una corrección funcional conocida pendiente de esta pasada.
