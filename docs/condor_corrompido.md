# Cóndor Corrompido

Enemigo aéreo definitivo introducido en Ruinas Ancestrales y Santuario Profundo.

## Recursos

- Fuente intacta: `res://assets/sprites/enemies/condor_corrompido/condor_source.png`.
- Palette swap: `res://assets/sprites/enemies/condor_corrompido/condor_corrompido.png`.
- Ambos PNG miden `528x256`, conservan RGBA y una cuadrícula de `48x32`.
- El sprite definitivo usa filtro Nearest y la importación no genera mipmaps.

## Animaciones

Las coordenadas se expresan como `(columna, fila)`:

- `fly`: `(0..8, 6)`, 9 frames, loop, 12 FPS.
- `track`: `(0..8, 6)`, 9 frames, loop, 12 FPS.
- `dive_windup`: `(0..4, 5)`, 5 frames, no loop, 10 FPS.
- `dive`: `(0..8, 6)`, 9 frames, loop, 16 FPS.
- `hurt`: `(0..2, 0)`, 3 frames, no loop, 12 FPS.
- `stun`: `(2..3, 0)`, 2 frames, loop, 7 FPS.
- `death`: `(0..7, 0)`, 8 frames, no loop, 9 FPS.

No se incluyen las celdas transparentes finales de las filas.

## Balance inicial

- Vida: 3, equivalente a tres ataques normales de Wayra.
- Patrulla: 180 px a cada lado del origen, velocidad 60.
- Hover visual: 6 px, sin gravedad.
- Detección: 320 px horizontales y 230 px verticales.
- Tracking: 0,4–1,0 s.
- Windup: 0,45 s.
- Picada: velocidad 280 hacia una posición fijada al terminar el windup, sin homing.
- Recovery: 0,4 s.
- Regreso: velocidad 110 y leash de 420 px.
- Cooldown: 1,5–2,5 s.
- Stun por parry: 1,8 s.

## Colisiones y parry

El cuerpo principal solo consulta el terreno y no bloquea ni daña a Wayra. `HurtBox` recibe sus ataques. `AttackHitbox` se activa exclusivamente durante `DIVE_ATTACK` y es la única fuente de daño.

Si Wayra está en `PARRY`, el intento de daño reutiliza el sistema existente: el daño se cancela, se emite `parry_success`, la picada termina, el Cóndor entra en `STUN` y se conserva la compatibilidad con Contraataque.

## Integración

- Ruinas Ancestrales: `(3250, 210)`, `(7700, 120)`, `(10950, 120)`.
- Santuario Profundo: `(3350, 300)`, `(5250, 420)`, `(11150, 250)`, `(14900, 300)`.
- Orillas del Lago: ningún Cóndor.
