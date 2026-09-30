# Última pasada de gameplay y preparación del final

Proyecto: EL LEGADO DE KJANA-CHUYMA. Validado con Godot 4.7.2 estable el 26-09-2026.

> **Nota histórica:** este informe describe la implementación intermedia del 26-09-2026. La versión final ya incluye `ending_01_guardian.ogv` y `ending_02_epilogue.ogv`, seleccionados de forma alternativa; véase el [README actual](../README.md#finales).

## Proyectil del Guardián

La estela procedía de `GuardianCorruptionTrailVFX.tscn`: cada disparo creaba un `Line2D` separado y añadía puntos sobre el suelo mientras avanzaba. Se quitó la creación y actualización de ese VFX en `guardian_corruption_projectile.gd`. La escena antigua permanece en el proyecto sin referencias activas, para no borrar otros recursos ajenos al cambio. Se conservó el método `cancel_visuals()` como punto de compatibilidad con el reseteo del jefe.

La bola mantiene su núcleo, brillo, collider circular de radio 16, velocidad 520 px/s, dirección, daño 1, lifetime de 4 s y desaparición al impactar. La implementación anterior no tenía una explosión separada; no se añadió una nueva.

## Daño al tocar enemigos

`ContactDamage` es un `Area2D` de capa 0 y máscara del jugador (2), con script común `scripts/enemies/contact_damage.gd`. Comprueba solapamientos físicos desde cualquier dirección y llama a `Wayra.take_damage(..., contact=true)`. Esta llamada no pasa por la recompensa de parry; tocar el cuerpo no suma postura ni prepara Contraataque. `AttackHitbox` continúa separado para ataques intencionales.

Wayra tiene 0.7 s de invulnerabilidad después de un golpe efectivo, tanto para contacto como para ataques normales. El bloqueo de un ataque no consume esa ventana. El knockback existente de Wayra se conserva (velocidad horizontal de 150 px/s al recibir daño). Tras los 0.7 s, un contacto mantenido puede volver a hacer daño. Al reaparecer se limpia el temporizador.

El cuerpo del Espectro y el del Cóndor solo dejan de causar daño en `DEAD`. La zona del Guardián requiere además que `active` sea verdadero, para que el jefe oculto no dañe antes del encuentro. Se desactiva durante `INTRO`, `STAGGER`, `VULNERABLE`, transición de fase y `DEAD`; la vulnerabilidad queda utilizable para atacar al jefe sin recibir daño corporal.

## Tamaño y hitboxes

| Elemento | Antes | Ahora |
| --- | --- | --- |
| Espectro, escala visual | 2.25 | 2.65 (+17.8 %) |
| Espectro, cuerpo | 28×46 | 34×68, centro Y −11 |
| Espectro, hurtbox | 32×60, Y −7 | 38×72, Y −13 |
| Espectro, AttackHitbox | 58×44, X 40/Y 0 | 68×52, X 46/Y −5 |
| Espectro, zona de contacto | inexistente | 38×78, Y −10 |
| Cóndor, escala visual | 1.5 | 1.75 (+16.7 %) |
| Cóndor, cuerpo | 54×28 | 64×34 |
| Cóndor, hurtbox | 68×44 | 80×52 |
| Cóndor, AttackHitbox | 76×46 | 90×54 |
| Cóndor, zona de contacto | inexistente | 74×44 |
| Guardián, zona de contacto | inexistente | 154×184, Y 8; sin alterar su cuerpo ni hurtbox |

El sprite del Espectro subió de Y −49 a −62 para que sus pies sigan en el mismo suelo. Su comprobación de borde y la posición del `FloorRay` avanzaron de 24 a 28 px; el destello y la hitbox de ataque se desplazaron con la silueta. En el Cóndor, el destello se movió de 28 a 33 px hacia el pico. Se mantiene `texture_filter = nearest` y no se escalan los nodos raíz. El Cóndor no usa nodos de raycast para terreno; su detección de línea de visión ya existía y se conservó.

## Cóndor más agresivo

| Parámetro | Antes | Ahora |
| --- | ---: | ---: |
| Detección horizontal | 320 px | 384 px (+20 %) |
| Detección vertical | 230 px | 276 px (+20 %) |
| Cooldown mínimo | 1.50 s | 1.23 s (−18 %) |
| Cooldown máximo | 2.50 s | 2.05 s (−18 %) |
| Seguimiento mínimo | 0.40 s | 0.35 s |
| Seguimiento máximo | 1.00 s | 0.85 s |
| Velocidad de retorno | 110 px/s | 126 px/s |

La velocidad de picada sigue en 280 px/s. Su windup de 0.45 s, destello durante los últimos 0.15 s, ventana de Perfect Parry y recuperación de 0.4 s no se acortaron. El retorno más rápido y el cooldown menor permiten redetectar y presionar antes.

## Final preparado

El flujo conserva la recompensa indispensable:

1. El Guardián llega a 0 HP, completa su animación de muerte, limpia ataques temporales y emite `defeated` tras su pulso final.
2. El nivel abre la arena y crea el Fragmento #3. Al recogerlo, `GameState.try_begin_finale()` activa una sola vez la flag ya existente `finale_triggered`.
3. Se bloquea el movimiento, se ocultan HUD, barra del jefe y menú de pausa, y se detiene la música del combate. Después de 0.5 s, `EndingSequence.tscn` sustituye al nivel, por lo que no quedan gameplay ni HUD durante el vídeo.
4. Si existe `res://assets/video/ending/ending_cinematic.ogv`, la escena lo carga automáticamente en un `VideoStreamPlayer` a pantalla completa. Al emitir `finished`, pasa a la tarjeta final.
5. Si falta el vídeo, salta directamente a negro. `CONTINUARÁ` aparece en 1.1 s, permanece solo 3.5 s y después aparece **Volver al menú**. El botón carga Main Menu, quita cualquier pausa y Main Menu inicia su música.

**Actualización de versión final:** la instrucción anterior de añadir `ending_cinematic.ogv` quedó sustituida por las dos cinemáticas ya incluidas en `assets/video/ending/`. `ending_sequence.gd` elige una sola según los fragmentos: `ending_01_guardian.ogv` → **FIN** con 1–2; `ending_02_epilogue.ogv` → **CONTINUARÁ** con 3. La prueba física de reproducción en el APK definitivo sigue pendiente. [Documentación oficial de Godot sobre reproducción de vídeo](https://docs.godotengine.org/en/4.4/tutorials/animation/playing_videos.html).

No se crearon créditos, vídeo de muestra ni personajes nuevos.

## Archivos

Creados:

- `scripts/enemies/contact_damage.gd`
- `scripts/ui/ending_sequence.gd`
- `scenes/ui/EndingSequence.tscn`
- `assets/video/ending/README.md`
- `tests/final_gameplay_smoke.gd` y `tests/final_gameplay_smoke.tscn` (más el UID generado por Godot).
- Este informe.

Modificados:

- `scripts/bosses/guardian_corruption_projectile.gd`
- `scenes/player/player.gd`
- `scripts/enemies/espectro_sediento.gd` y `scenes/enemies/espectro_sediento.tscn`
- `scripts/enemies/condor_corrompido.gd` y `scenes/enemies/CondorCorrompido.tscn`
- `scenes/bosses/GuardianSediento.tscn`
- `scripts/levels/level03_santuario_profundo.gd`

## Validación

La prueba nueva se ejecuta con:

```sh
godot --headless --path . res://tests/final_gameplay_smoke.tscn
```

Cubre contacto por arriba, lados, abajo y diagonal en Espectro y Cóndor; daño único durante los i-frames y repetición tras expirar; contacto con el jefe y excepción en vulnerabilidad; conservación del proyectil sin estela; telegraph de Cóndor; muerte completa del jefe; aparición y recogida del Fragmento #3; activación única de la secuencia; ausencia del vídeo; silencio durante el final; tarjeta CONTINUARÁ y regreso musical al menú. La prueba headless final completó **49 comprobaciones y 0 fallos**, incluyendo el jefe inactivo; la ejecución gráfica mediante Godot MCP completó **48 comprobaciones y 0 fallos** antes de añadir esa comprobación puramente lógica. Se revisaron capturas de los dos enemigos dentro del nivel, la bola sin estela y la tarjeta final.

La regresión anterior `tests/week4_polish_smoke.tscn` completó **110 comprobaciones y 0 fallos** tras estos cambios, incluyendo parry perfecto, Contraataque, coca, pausa, muerte y reintento del jefe. No hubo errores de parseo ni referencias nulas en los recorridos finales.

Pendiente de prueba manual cuando exista el vídeo: confirmar que el archivo real se importa, que su audio y duración son correctos y que la señal `finished` muestra CONTINUARÁ. También conviene jugar unos encuentros completos para juzgar el ritmo subjetivo del Cóndor y la comodidad del nuevo contacto. Las pruebas automatizadas sí comprobaron los estados, colisiones y tiempos descritos; no se afirma haber jugado una partida completa con mando o teclado.
