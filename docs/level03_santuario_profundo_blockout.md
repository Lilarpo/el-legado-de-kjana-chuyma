# Nivel 3 — Santuario Profundo

Escena jugable: `res://scenes/levels/level03_santuario_profundo.tscn`

## Recorrido

| Zona | Rango X aproximado | Contenido |
| --- | ---: | --- |
| Entrada y descenso | 0–1.700 | Entrada elevada y caída controlada por cuatro plataformas |
| Descenso profundo | 1.700–3.700 | Dos enemigos, Hoja #1 y ascenso obligatorio con doble salto |
| Pasillos de corrupción | 3.700–5.600 | Dos enemigos, Sed Blanca y tercer precipicio |
| Cámara de combate | 5.600–7.500 | Dos enemigos separados, Hoja #2 y salida vertical |
| Último santuario | 7.500–9.000 | Zona segura y único checkpoint en X=8.500 |
| Santuario corrompido | 9.000–12.800 | Dos secuencias difíciles, tres enemigos y Hoja #3 |
| Gauntlet final | 12.800–15.300 | Dos hazards, dos enemigos y prueba final de plataformas |
| Antesala | 15.300–16.000 | Sala segura con markers para música y cierre futuro |
| Arena | 16.000–18.000 | Cámara amplia sin precipicios ni enemigos activos |

## Dificultad y riesgos

Los ocho precipicios principales están en X=1.000–1.700, 3.000–3.700, 5.000–5.600, 6.800–7.500, 9.000–9.800, 10.800–11.650, 12.800–13.500 y 14.600–15.300.

Las subidas obligatorias usan desniveles de 160–200 px: superan el salto normal de aproximadamente 138 px, pero conservan margen frente al alcance vertical aproximado de 276 px del doble salto. `DeathPlane_Precipices` y los tres charcos de Sed Blanca reutilizan `KillZone`.

## Coleccionables y checkpoint

- Hoja #1: X=2.500/Y=615, ruta superior lateral.
- Hoja #2: X=6.660/Y=617, ascenso opcional junto a la cámara de combate.
- Hoja #3: X=11.400/Y=-13, ruta extrema de tres saltos después del checkpoint.
- Santuario único: X=8.500/Y=977.
- No existe una instancia activa del Fragmento #3.

## Arena del Guardián Sediento

La arena tiene 2.000 px de suelo continuo y altura suficiente para doble salto. Contiene:

- `PlayerBossEntrance`
- `BossSpawn_GuardianSediento`
- `BossCenter`
- `BossAttackPoint_Left` y `BossAttackPoint_Right`
- `BossCorruptionPoint_01..03`
- `BossArenaEntrance`, `MusicChangePoint` y `FutureDoorClosePoint` en la antesala

`PostBoss/Fragment3Spawn_AfterBoss` y `PostBoss/EndGameTrigger_AfterBoss` son solamente `Marker2D`. El Fragmento #3 y la victoria no pueden activarse antes de implementar el jefe.

## Contenido futuro

- `CondorSpawn_Level3_01..04` reserva posiciones sobre zonas verticales y precipicios.
- El Guardián, el cierre de la arena, música, fases, ataques, aparición del fragmento y finales quedan deliberadamente sin lógica.
- La salida de Ruinas Ancestrales ya apunta a este nivel con el spawn `FromRuinas`.
