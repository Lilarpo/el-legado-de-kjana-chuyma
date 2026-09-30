# QA Android — versión final

El autor confirmó que el APK fue generado, instalado y ejecutado en un teléfono Android real; la orientación horizontal, los controles táctiles y el HUD se vieron correctamente. En esta sesión no hubo dispositivo conectado por ADB, por lo que no se registran fabricante, modelo, resolución ni versión de Android. Una prueba automatizada de escritorio o Godot headless no sustituye la interacción física.

| ID | Prueba | Resultado esperado | Estado | Observación |
|---|---|---|---|---|
| QA-01 | Inicio APK | Se instala y abre el juego. | **Cumple (informado por autor)** | APK real ejecutado; sin registro de modelo. |
| QA-02 | Escalado Android | Orientación horizontal, HUD y controles visibles sin solaparse. | **Cumple (informado por autor)** | El autor confirmó orientación/HUD/controles; la nueva separación de 22 px requiere verificación física tras volver a exportar. |
| QA-03 | Multitouch | Mantener movimiento mientras se salta o ataca. | **Por validar en dispositivo** | La prueba automatizada de controles verifica acciones simultáneas; falta tacto real. |
| QA-04 | Ataque | El botón de lanza ejecuta el ataque. | **Por validar en dispositivo** | Acción vinculada en `MobileControls.tscn`. |
| QA-05 | Perfect Parry | El escudo activa Parry y permite el timing del destello. | **Por validar en dispositivo** | El timing real exige jugar en teléfono. |
| QA-06 | Interacción contextual | La mano aparece cerca de NPC, altar o mecanismo y permite interactuar. | **Por validar en dispositivo** | Visibilidad/contexto cubiertos por prueba automatizada. |
| QA-07 | Pociones | Drop visible, botón contextual, uso manual y absorción de tres impactos. | **Por validar en dispositivo** | Inventario y botón tienen prueba automatizada. |
| QA-08 | Pausa | Botón Pausa abre y cierra menú; HUD no lo tapa. | **Por validar en dispositivo** | Geometría relativa probada en Godot headless. |
| QA-09 | Audio | Música, SFX y sliders funcionan en el teléfono. | **Por validar en dispositivo** | Requiere escucha humana. |
| QA-10 | Checkpoint/Save | Altar cura al máximo y guarda el avance persistente. | **Por validar en dispositivo** | Revisar tras cerrar app. |
| QA-11 | Continuar | El menú recupera partida y progreso al reiniciar la aplicación. | **Por validar en dispositivo** | Confirmar en el mismo dispositivo. |
| QA-12 | Muerte/Respawn | MORISTE permite continuar con `health=max_health`. | **Por validar en dispositivo** | Confirmar pantalla y reaparición. |
| QA-13 | Cinemática Final Normal | Con 1–2 fragmentos se ve `ending_01_guardian.ogv` y FIN. | **Por validar en dispositivo** | Verificar vídeo y audio. |
| QA-14 | Cinemática Final Verdadero | Con 3 fragmentos se ve `ending_02_epilogue.ogv` y CONTINUARÁ. | **Por validar en dispositivo** | Verificar vídeo y audio. |

Los estados «Cumple» identifican **declaraciones del autor**, no una medición ADB ni una prueba ejecutada por este agente. La evaluación audiovisual se realiza mediante el gameplay/tráiler entregado por el autor, cuyo enlace aún no figura en el repositorio. No consta una prueba externa documentada con tres usuarios; no se atribuyen resultados a participantes inexistentes.

## Lista para la próxima prueba física

- [ ] Mantener derecha + pulsar salto.
- [ ] Mantener izquierda + atacar.
- [ ] Ejecutar Perfect Parry mediante touch.
- [ ] Interactuar con NPC, altar y puerta/mecanismo.
- [ ] Obtener poción, comprobar botón, usarla y recibir tres golpes.
- [ ] Abrir/cerrar Pausa y cambiar volumen.
- [ ] Activar checkpoint, cerrar juego y usar Continuar.
- [ ] Morir y reaparecer con `health=max_health`.
- [ ] Ver Final Normal con 1–2 fragmentos → FIN.
- [ ] Ver Final Verdadero con 3 fragmentos → CONTINUARÁ.
- [ ] Confirmar audio y vídeo de ambas cinemáticas.
- [ ] Revisar la nueva separación HUD/Pausa y ambas pestañas de Controles en 16:9, 18:9, 19.5:9 y 20:9 cuando haya dispositivos disponibles.
