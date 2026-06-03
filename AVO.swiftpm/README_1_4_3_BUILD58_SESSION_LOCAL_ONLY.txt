AVO Performance Horse 1.4.3 BUILD58

Cambios principales:
- SESSION no sincroniza al abrir. Solo carga cache local.
- REFRESH/SYNC conecta al servidor manualmente.
- Sync usa primero /api/sessions/index_light?horseId=HORSE_001&limit=20.
- Fallback seguro: /api/sessions/index?horseId=HORSE_001&limit=20&light=1.
- Guarda sesiones por ID real: Mi app/Sessions/HORSE_001/<sessionId>/.
- Lezama dreams queda solo como nombre visual de UI, no como carpeta tecnica.
- Migracion automatica: copia Sessions/LEZAMA_DREAMS/* a Sessions/HORSE_001/* si existe.
- Al abrir analisis usa session.json local si existe; si falta, descarga una sola vez /api/session_light/<sessionId> y lo guarda local.
- Version Apple revisada: 1.4.3 / build 58.
