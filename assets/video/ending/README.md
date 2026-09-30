# Cinemáticas finales

La versión final incluye dos vídeos alternativos Ogg Theora:

- `ending_01_guardian.ogv`: Final Normal con 1–2 fragmentos; tarjeta **FIN**.
- `ending_02_epilogue.ogv`: Final Verdadero con 3 fragmentos; tarjeta **CONTINUARÁ**.

`res://scripts/ui/ending_sequence.gd` selecciona **uno** según `GameState.fragments_collected`. El estado de 0 fragmentos usa el Final Normal como fallback defensivo, pero no es alcanzable en el recorrido normal porque recoger el Fragmento #3 forma parte del desenlace. Los archivos `.ogv` están versionados; revisar su audio/vídeo en el APK definitivo sigue siendo una prueba manual Android.
