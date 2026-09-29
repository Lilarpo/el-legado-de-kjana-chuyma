# Nivel 2 — Ruinas Ancestrales

Escena jugable: `res://scenes/levels/level02_ruinas_ancestrales.tscn`

## Recorrido

| Zona | Rango X aproximado | Contenido |
| --- | ---: | --- |
| Entrada | 0–1.750 | Zona segura, barrera obligatoria de doble salto y primer precipicio |
| Ascenso | 1.750–3.500 | Dos enemigos, Hoja #1 y acceso escalonado a la cámara central |
| Cámara central | 3.500–6.100 | Rutas A/B, Hoja #2, dos mecanismos y Puerta Ancestral |
| Acceso al santuario | 6.100–8.300 | Plataformas verticales y único checkpoint en X=8.200 |
| Ruinas profundas | 8.300–12.500 | Descensos, cadenas de doble salto, placeholders de púas y Hoja #3 |
| Prueba final | 12.500–13.500 | Séptimo precipicio y último enemigo |
| Recompensa y cierre | 13.500–15.000 | Fragmento #2, Kjana-Chuyma, sala de prueba y salida |

La cámara permite seguir a Wayra entre Y=-720 y Y=900. Los ascensos obligatorios de 150–240 px exigen doble salto, mientras que ningún salto usa el límite máximo aproximado de 276 px.

## Puzzle central

- `Mechanism_A` se alcanza por la ruta superior de plataformeo.
- `Mechanism_B` está después de las plataformas marcadas con `WindZone_01` y `WindZone_02`.
- Ambos emiten `activated(id)` hacia `AncientDoor`.
- La puerta mantiene su colisión hasta registrar dos identificadores diferentes.
- Los componentes `RuinsMechanism` y `AncientDoor` son escenas reutilizables.

## Contenido y placeholders

- Hojas: X=2.380, X=4.300/Y=-133 y X=10.740/Y=-95.
- Santuario único: X=8.200.
- Fragmento #2: X=13.900.
- Kjana-Chuyma: X=14.350; desbloquea la bandera `counterattack`.
- Sala de práctica: `FutureCounterattackTarget` en X=14.620.
- Salida a Santuario Profundo: X=14.900, conectada a `level03_santuario_profundo.tscn` mediante el spawn `FromRuinas`.
- `MovingSpikes_01..03`, `CondorSpawn_01..03` y `WindZone_01..02` son marcadores sin mecánica nueva.
- `FutureSealedLedge_01` y `FutureSealedLedge_02` sugieren rutas futuras inaccesibles incluso con doble salto.

## Precipicios

Los siete sectores principales están en X=1.300–1.750, 3.000–3.500, 4.800–5.400, 7.400–8.050, 9.000–9.600, 10.600–11.350 y 12.500–13.100. Todos reutilizan `DeathPlane_Precipices` y el respawn existente.

El contraataque conserva la preparación previa del controlador: tras desbloquearse, un parry habilita `can_counterattack` durante su ventana existente. No se añadieron daño, input ni animación nuevos para esa habilidad.
