"""Mensajería interna: chats directos y grupales.

Las operaciones de consulta y administración usan REST; la entrega de
mensajes en tiempo real, el indicador de "escribiendo" y el estado en línea
viajan por un WebSocket en /ws.

Protocolo del WebSocket (JSON):
  cliente -> servidor
    {"tipo": "auth", "token": "<JWT>"}            primer mensaje obligatorio
    {"tipo": "mensaje", "conversacion_id": 1, "contenido": "hola", "temp_id": "x"}
    {"tipo": "escribiendo", "conversacion_id": 1}
    {"tipo": "leido", "conversacion_id": 1}
    {"tipo": "ping"}
  servidor -> cliente
    {"tipo": "autenticado", "usuario_id": 1, "en_linea": [1, 2]}
    {"tipo": "mensaje", "mensaje": {...}, "temp_id": "x"}
    {"tipo": "conversacion", "conversacion": {...}}   creada o modificada
    {"tipo": "conversacion_eliminada", "conversacion_id": 1}
    {"tipo": "escribiendo", "conversacion_id": 1, "usuario_id": 2, "nombre": "Ana"}
    {"tipo": "presencia", "usuario_id": 2, "en_linea": true}
    {"tipo": "error", "detalle": "..."}
    {"tipo": "pong"}
"""
import asyncio
import json
import logging

from anyio.from_thread import run as ejecutar_en_bucle
from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect
from sqlalchemy import and_, func, select
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from database import SessionLocal, obtener_sesion
from gestor_conexiones import gestor
from models import Conversacion, ConversacionMiembro, Mensaje, Usuario
from schemas import (
    ConversacionRespuesta, DirectoCrear, GrupoActualizar, GrupoCrear,
    MensajeCrear, MensajeRespuesta, MiembroRespuesta, MiembrosAgregar,
)
from seguridad import usuario_actual, usuario_desde_token

router = APIRouter(tags=["Chat"])

MAX_CONTENIDO = 2000
SEGUNDOS_PARA_AUTENTICAR = 10

logger = logging.getLogger("uvicorn.error")


# UTILIDADES

def _mensaje_respuesta(m: Mensaje) -> MensajeRespuesta:
    return MensajeRespuesta(
        id_msg=m.id_msg,
        conv_id=m.conv_id,
        usr_id=m.usr_id,
        autor_nombre=m.autor.nom_usr,
        contenido=m.contenido,
        fecha=m.fecha,
    )


def _obtener_conversacion(db: Session, conv_id: int, usuario_id: int) -> Conversacion:
    conv = db.get(Conversacion, conv_id)
    # Se responde 404 también cuando no es miembro, para no revelar
    # la existencia de conversaciones ajenas.
    if conv is None or all(m.usr_id != usuario_id for m in conv.miembros):
        raise HTTPException(
            status_code=404,
            detail="Conversación no encontrada",
        )
    return conv


def _exigir_grupo(conv: Conversacion) -> None:
    if not conv.es_grupo:
        raise HTTPException(
            status_code=400,
            detail="Esta acción sólo aplica a grupos",
        )


def _validar_usuarios(db: Session, ids: set[int]) -> None:
    existentes = set(db.scalars(
        select(Usuario.id_usr).where(Usuario.id_usr.in_(ids))
    ).all())
    faltantes = ids - existentes
    if faltantes:
        raise HTTPException(
            status_code=404,
            detail=f"Usuarios no encontrados: {sorted(faltantes)}",
        )


def _serializar(
    db: Session,
    conversaciones: list[Conversacion],
    usuario_id: int,
) -> list[ConversacionRespuesta]:
    ids = [c.id_conv for c in conversaciones]
    if not ids:
        return []

    ultimos_ids = db.scalars(
        select(func.max(Mensaje.id_msg))
        .where(Mensaje.conv_id.in_(ids))
        .group_by(Mensaje.conv_id)
    ).all()
    ultimos = {
        m.conv_id: m
        for m in db.scalars(select(Mensaje).where(Mensaje.id_msg.in_(ultimos_ids)))
    } if ultimos_ids else {}

    no_leidos = dict(db.execute(
        select(Mensaje.conv_id, func.count())
        .join(
            ConversacionMiembro,
            and_(
                ConversacionMiembro.conv_id == Mensaje.conv_id,
                ConversacionMiembro.usr_id == usuario_id,
            ),
        )
        .where(
            Mensaje.conv_id.in_(ids),
            Mensaje.usr_id != usuario_id,
            Mensaje.id_msg > ConversacionMiembro.ultimo_leido_id,
        )
        .group_by(Mensaje.conv_id)
    ).all())

    resultado = []
    for conv in conversaciones:
        miembros = sorted(
            (
                MiembroRespuesta(
                    id_usr=m.usr_id,
                    nom_usr=m.usuario.nom_usr,
                    en_linea=gestor.en_linea(m.usr_id),
                )
                for m in conv.miembros
            ),
            key=lambda m: m.nom_usr.lower(),
        )
        if conv.es_grupo:
            nombre = conv.nombre or "Grupo"
        else:
            nombre = next(
                (m.nom_usr for m in miembros if m.id_usr != usuario_id),
                "Chat",
            )
        ultimo = ultimos.get(conv.id_conv)
        resultado.append(ConversacionRespuesta(
            id_conv=conv.id_conv,
            nombre=nombre,
            es_grupo=conv.es_grupo,
            creador_id=conv.creador_id,
            fecha=conv.fecha,
            miembros=miembros,
            ultimo_mensaje=_mensaje_respuesta(ultimo) if ultimo else None,
            no_leidos=no_leidos.get(conv.id_conv, 0),
        ))

    # Las conversaciones con actividad más reciente van primero.
    resultado.sort(
        key=lambda c: c.ultimo_mensaje.fecha if c.ultimo_mensaje else c.fecha,
        reverse=True,
    )
    return resultado


def _notificar_conversacion(db: Session, conv: Conversacion) -> None:
    """Envía a cada miembro conectado la versión actualizada de la conversación.
    Se llama desde endpoints síncronos (hilos del threadpool)."""
    for miembro in conv.miembros:
        if not gestor.en_linea(miembro.usr_id):
            continue
        datos = _serializar(db, [conv], miembro.usr_id)[0]
        ejecutar_en_bucle(
            gestor.enviar,
            [miembro.usr_id],
            {"tipo": "conversacion", "conversacion": datos.model_dump(mode="json")},
        )


def _guardar_mensaje(
    db: Session,
    conv_id: int,
    usuario_id: int,
    contenido: str,
) -> tuple[MensajeRespuesta, list[int]]:
    texto = contenido.strip()
    if not texto:
        raise HTTPException(status_code=422, detail="El mensaje no puede estar vacío")
    if len(texto) > MAX_CONTENIDO:
        raise HTTPException(
            status_code=422,
            detail=f"El mensaje no puede superar {MAX_CONTENIDO} caracteres",
        )

    conv = _obtener_conversacion(db, conv_id, usuario_id)
    mensaje = Mensaje(conv_id=conv_id, usr_id=usuario_id, contenido=texto)
    db.add(mensaje)
    db.flush()

    # Lo que uno mismo envía se considera leído.
    remitente = db.get(ConversacionMiembro, (conv_id, usuario_id))
    remitente.ultimo_leido_id = mensaje.id_msg
    db.commit()
    db.refresh(mensaje)

    return _mensaje_respuesta(mensaje), [m.usr_id for m in conv.miembros]


def _marcar_leido(db: Session, conv_id: int, usuario_id: int) -> None:
    _obtener_conversacion(db, conv_id, usuario_id)
    ultimo = db.scalar(
        select(func.max(Mensaje.id_msg)).where(Mensaje.conv_id == conv_id)
    ) or 0
    miembro = db.get(ConversacionMiembro, (conv_id, usuario_id))
    if ultimo > miembro.ultimo_leido_id:
        miembro.ultimo_leido_id = ultimo
        db.commit()


# REST

@router.get("/chats", response_model=list[ConversacionRespuesta])
def listar_conversaciones(
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    conversaciones = db.scalars(
        select(Conversacion)
        .join(ConversacionMiembro)
        .where(ConversacionMiembro.usr_id == usuario.id_usr)
    ).all()
    return _serializar(db, list(conversaciones), usuario.id_usr)


@router.get("/chats/{conv_id}", response_model=ConversacionRespuesta)
def obtener_conversacion(
    conv_id: int,
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    conv = _obtener_conversacion(db, conv_id, usuario.id_usr)
    return _serializar(db, [conv], usuario.id_usr)[0]


@router.post("/chats/directo", response_model=ConversacionRespuesta)
def abrir_chat_directo(
    datos: DirectoCrear,
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    """Devuelve el chat directo con otro usuario; lo crea si no existe."""
    if datos.usuario_id == usuario.id_usr:
        raise HTTPException(
            status_code=400,
            detail="No puedes abrir un chat contigo mismo",
        )
    _validar_usuarios(db, {datos.usuario_id})

    mis_conversaciones = select(ConversacionMiembro.conv_id).where(
        ConversacionMiembro.usr_id == usuario.id_usr
    )
    conv = db.scalar(
        select(Conversacion)
        .join(ConversacionMiembro)
        .where(
            Conversacion.es_grupo.is_(False),
            Conversacion.id_conv.in_(mis_conversaciones),
            ConversacionMiembro.usr_id == datos.usuario_id,
        )
    )

    if conv is None:
        conv = Conversacion(es_grupo=False, creador_id=usuario.id_usr)
        conv.miembros = [
            ConversacionMiembro(usr_id=usuario.id_usr),
            ConversacionMiembro(usr_id=datos.usuario_id),
        ]
        db.add(conv)
        db.commit()
        db.refresh(conv)
        _notificar_conversacion(db, conv)

    return _serializar(db, [conv], usuario.id_usr)[0]


@router.post("/chats/grupo", response_model=ConversacionRespuesta, status_code=201)
def crear_grupo(
    datos: GrupoCrear,
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    miembros = set(datos.miembros) | {usuario.id_usr}
    if len(miembros) < 2:
        raise HTTPException(
            status_code=400,
            detail="Un grupo necesita al menos otro integrante",
        )
    _validar_usuarios(db, miembros)

    conv = Conversacion(
        nombre=datos.nombre.strip(),
        es_grupo=True,
        creador_id=usuario.id_usr,
    )
    conv.miembros = [ConversacionMiembro(usr_id=uid) for uid in miembros]
    db.add(conv)
    db.commit()
    db.refresh(conv)
    _notificar_conversacion(db, conv)

    return _serializar(db, [conv], usuario.id_usr)[0]


@router.put("/chats/{conv_id}", response_model=ConversacionRespuesta)
def renombrar_grupo(
    conv_id: int,
    datos: GrupoActualizar,
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    conv = _obtener_conversacion(db, conv_id, usuario.id_usr)
    _exigir_grupo(conv)

    conv.nombre = datos.nombre.strip()
    db.commit()
    _notificar_conversacion(db, conv)

    return _serializar(db, [conv], usuario.id_usr)[0]


@router.post("/chats/{conv_id}/miembros", response_model=ConversacionRespuesta)
def agregar_miembros(
    conv_id: int,
    datos: MiembrosAgregar,
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    conv = _obtener_conversacion(db, conv_id, usuario.id_usr)
    _exigir_grupo(conv)

    nuevos = set(datos.usuarios) - {m.usr_id for m in conv.miembros}
    if nuevos:
        _validar_usuarios(db, nuevos)
        # Los nuevos integrantes ven el historial como ya leído.
        ultimo = db.scalar(
            select(func.max(Mensaje.id_msg)).where(Mensaje.conv_id == conv_id)
        ) or 0
        for uid in nuevos:
            conv.miembros.append(
                ConversacionMiembro(usr_id=uid, ultimo_leido_id=ultimo)
            )
        db.commit()
        db.refresh(conv)
        _notificar_conversacion(db, conv)

    return _serializar(db, [conv], usuario.id_usr)[0]


@router.delete("/chats/{conv_id}/miembros/yo")
def salir_de_grupo(
    conv_id: int,
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    conv = _obtener_conversacion(db, conv_id, usuario.id_usr)
    _exigir_grupo(conv)

    conv.miembros = [m for m in conv.miembros if m.usr_id != usuario.id_usr]
    if conv.miembros:
        db.commit()
        db.refresh(conv)
        _notificar_conversacion(db, conv)
    else:
        db.delete(conv)
        db.commit()

    ejecutar_en_bucle(
        gestor.enviar,
        [usuario.id_usr],
        {"tipo": "conversacion_eliminada", "conversacion_id": conv_id},
    )
    return {"mensaje": "Saliste del grupo"}


@router.get("/chats/{conv_id}/mensajes", response_model=list[MensajeRespuesta])
def listar_mensajes(
    conv_id: int,
    antes_de: int | None = Query(default=None, description="Paginación: id_msg más antiguo ya cargado"),
    limite: int = Query(default=50, ge=1, le=200),
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    _obtener_conversacion(db, conv_id, usuario.id_usr)

    consulta = select(Mensaje).where(Mensaje.conv_id == conv_id)
    if antes_de is not None:
        consulta = consulta.where(Mensaje.id_msg < antes_de)
    mensajes = db.scalars(
        consulta.order_by(Mensaje.id_msg.desc()).limit(limite)
    ).all()

    # Se consultan del más nuevo al más viejo y se devuelven en orden cronológico.
    return [_mensaje_respuesta(m) for m in reversed(mensajes)]


@router.post(
    "/chats/{conv_id}/mensajes",
    response_model=MensajeRespuesta,
    status_code=201,
)
def enviar_mensaje(
    conv_id: int,
    datos: MensajeCrear,
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    """Alternativa REST al WebSocket: guarda y reparte el mensaje."""
    mensaje, miembros = _guardar_mensaje(db, conv_id, usuario.id_usr, datos.contenido)
    ejecutar_en_bucle(
        gestor.enviar,
        miembros,
        {"tipo": "mensaje", "mensaje": mensaje.model_dump(mode="json")},
    )
    return mensaje


@router.post("/chats/{conv_id}/leido")
def marcar_leido(
    conv_id: int,
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    _marcar_leido(db, conv_id, usuario.id_usr)
    return {"mensaje": "Conversación marcada como leída"}


# WEBSOCKET

def _con_sesion(funcion, *args):
    """Ejecuta una función de BD con su propia sesión (se llama en un hilo)."""
    db = SessionLocal()
    try:
        return funcion(db, *args)
    finally:
        db.close()


def _autenticar_ws(db: Session, token: str) -> tuple[int, str] | None:
    usuario = usuario_desde_token(token, db)
    return (usuario.id_usr, usuario.nom_usr) if usuario else None


def _miembros_de(db: Session, conv_id: int, usuario_id: int) -> list[int]:
    conv = _obtener_conversacion(db, conv_id, usuario_id)
    return [m.usr_id for m in conv.miembros]


async def _esperar_autenticacion(ws: WebSocket) -> tuple[int, str] | None:
    """El token se manda como primer mensaje (y no en la URL) para que
    no quede registrado en los logs del servidor."""
    try:
        texto = await asyncio.wait_for(ws.receive_text(), SEGUNDOS_PARA_AUTENTICAR)
        datos = json.loads(texto)
    except (asyncio.TimeoutError, json.JSONDecodeError, WebSocketDisconnect):
        return None
    if not isinstance(datos, dict) or datos.get("tipo") != "auth":
        return None
    token = datos.get("token")
    if not isinstance(token, str):
        return None
    return await run_in_threadpool(_con_sesion, _autenticar_ws, token)


async def _procesar(ws: WebSocket, usuario_id: int, nombre: str, datos: dict) -> None:
    tipo = datos.get("tipo")

    if tipo == "ping":
        await ws.send_json({"tipo": "pong"})
        return

    conv_id = datos.get("conversacion_id")
    if not isinstance(conv_id, int):
        await ws.send_json({"tipo": "error", "detalle": "conversacion_id inválido"})
        return

    if tipo == "mensaje":
        contenido = datos.get("contenido")
        if not isinstance(contenido, str):
            await ws.send_json({"tipo": "error", "detalle": "contenido inválido"})
            return
        mensaje, miembros = await run_in_threadpool(
            _con_sesion, _guardar_mensaje, conv_id, usuario_id, contenido,
        )
        await gestor.enviar(miembros, {
            "tipo": "mensaje",
            "mensaje": mensaje.model_dump(mode="json"),
            "temp_id": datos.get("temp_id"),
        })

    elif tipo == "escribiendo":
        miembros = await run_in_threadpool(
            _con_sesion, _miembros_de, conv_id, usuario_id,
        )
        await gestor.enviar(
            (uid for uid in miembros if uid != usuario_id),
            {
                "tipo": "escribiendo",
                "conversacion_id": conv_id,
                "usuario_id": usuario_id,
                "nombre": nombre,
            },
        )

    elif tipo == "leido":
        await run_in_threadpool(_con_sesion, _marcar_leido, conv_id, usuario_id)

    else:
        await ws.send_json({"tipo": "error", "detalle": f"Tipo desconocido: {tipo}"})


@router.websocket("/ws")
async def websocket_chat(ws: WebSocket):
    await ws.accept()

    sesion = await _esperar_autenticacion(ws)
    if sesion is None:
        await ws.close(code=1008, reason="Autenticación requerida")
        return
    usuario_id, nombre = sesion

    if gestor.conectar(usuario_id, ws):
        await gestor.difundir(
            {"tipo": "presencia", "usuario_id": usuario_id, "en_linea": True},
            excepto=usuario_id,
        )
    await ws.send_json({
        "tipo": "autenticado",
        "usuario_id": usuario_id,
        "en_linea": sorted(gestor.usuarios_en_linea()),
    })

    try:
        while True:
            texto = await ws.receive_text()
            try:
                datos = json.loads(texto)
                if not isinstance(datos, dict):
                    raise ValueError
            except ValueError:
                await ws.send_json({"tipo": "error", "detalle": "JSON inválido"})
                continue

            try:
                await _procesar(ws, usuario_id, nombre, datos)
            except HTTPException as error:
                await ws.send_json({
                    "tipo": "error",
                    "detalle": error.detail,
                    "temp_id": datos.get("temp_id"),
                })
            except WebSocketDisconnect:
                raise
            except Exception:
                logger.exception("Error procesando evento de WebSocket")
                await ws.send_json({
                    "tipo": "error",
                    "detalle": "Error interno del servidor",
                    "temp_id": datos.get("temp_id"),
                })
    except WebSocketDisconnect:
        pass
    finally:
        if gestor.desconectar(usuario_id, ws):
            await gestor.difundir(
                {"tipo": "presencia", "usuario_id": usuario_id, "en_linea": False},
            )
