# Espectro Sediento

Escena: `res://scenes/enemies/espectro_sediento.tscn`

Script: `res://scripts/enemies/espectro_sediento.gd`

## Animaciones

El spritesheet mide 576×384 px, con una cuadrícula de 9×6 y frames de 64×64 px. Se reproduce con `AnimatedSprite2D`, `SpriteFrames`, tamaño original y filtrado nearest.

| Animación | Coordenadas del atlas | FPS |
| --- | --- | ---: |
| `idle` | fila 0, columnas 5–8 | 5 |
| `move` | filas 1 y 2 completas, 18 frames continuos | 14 |
| `attack` | fila 3 completa; arco blanco en columnas 3–6 | 8 |
| `hurt` | fila 4, columnas 0–3 | 12 |
| `stun` | fila 4, columnas 0–3 reutilizadas | 8 |
| `death` | fila 5, columnas 0–4 | 9 |

## Valores iniciales

- Vida: 4 HP, equivalente a cuatro ataques normales de Wayra.
- Patrulla: ±180 px a 45 px/s.
- Detección: 250 px, con comprobación simple de pared y tolerancia vertical de 96 px.
- Persecución: 75 px/s.
- Leash: 330 px desde `spawn_position`.
- Ataque: 50 px de rango.
- Espera aleatoria: 0,6–1,4 s.
- Windup legible: 0,5 s.
- Ventana activa: 0,3 s.
- Recovery: 0,6 s.
- Stun por parry: 1,4 s.

## Colisiones y parry

- El sprite usa escala `2.25`, quedando apenas más alto que Wayra, y está desplazado verticalmente para que sus pies coincidan con el piso.
- La `HurtBox` está centrada sobre la silueta visible ampliada y permanece separada del collider físico.
El `CharacterBody2D` usa la capa 3 (`enemies`) y bloquea físicamente a Wayra mediante un collider de `28x46`; ese cuerpo no causa daño, no recibe ataques y no activa parry. `HurtBox` recibe el ataque de Wayra mediante `Area2D`. `AttackHitbox` se activa exclusivamente en `ATTACK_ACTIVE`, daña al cuerpo de Wayra y es la única fuente del parry.

Si Wayra está en estado `PARRY` cuando entra el golpe, `take_damage` cancela el daño, emite `parry_success(self)` y el Espectro entra en `STUN`; la hitbox queda desactivada y, si la habilidad está desbloqueada, Wayra obtiene su ventana existente de contraataque.

## Integración

- Orillas del Lago: 8 placeholders reemplazados.
- Ruinas Ancestrales: 10 placeholders reemplazados.
- Santuario Profundo: 11 placeholders reemplazados.
- `enemy_base.tscn` se conserva para mapas de prueba y futuras bases.
- Todos los markers de Cóndor permanecen intactos.
