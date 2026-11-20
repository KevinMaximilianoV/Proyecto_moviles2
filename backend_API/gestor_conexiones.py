"""Registro de conexiones WebSocket activas por usuario.

Vive en memoria del proceso, por eso la API debe ejecutarse con un solo
worker de uvicorn (suficiente para una Raspberry Pi o una laptop).
"""
from collections import defaultdict
from collections.abc import Iterable

from fastapi import WebSocket


class GestorConexiones:
    def __init__(self) -> None:
        # Un usuario puede tener varias conexiones (celular + web, por ejemplo).
        self._conexiones: dict[int, set[WebSocket]] = defaultdict(set)

    def conectar(self, usuario_id: int, ws: WebSocket) -> bool:
        """Registra la conexión. Devuelve True si es la primera del usuario."""
        primera = not self._conexiones[usuario_id]
        self._conexiones[usuario_id].add(ws)
        return primera

    def desconectar(self, usuario_id: int, ws: WebSocket) -> bool:
        """Quita la conexión. Devuelve True si el usuario quedó desconectado."""
        conexiones = self._conexiones.get(usuario_id)
        if conexiones is None:
            return False
        conexiones.discard(ws)
        if conexiones:
            return False
        del self._conexiones[usuario_id]
        return True

    def en_linea(self, usuario_id: int) -> bool:
        return usuario_id in self._conexiones

    def usuarios_en_linea(self) -> set[int]:
        return set(self._conexiones)

    async def enviar(self, usuarios: Iterable[int], payload: dict) -> None:
        for usuario_id in set(usuarios):
            for ws in list(self._conexiones.get(usuario_id, ())):
                try:
                    await ws.send_json(payload)
                except Exception:
                    # Conexión rota; se limpiará cuando su bucle termine.
                    pass

    async def difundir(self, payload: dict, excepto: int | None = None) -> None:
        await self.enviar(
            (uid for uid in self._conexiones if uid != excepto),
            payload,
        )


gestor = GestorConexiones()
