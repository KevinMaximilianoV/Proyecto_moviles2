from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from database import obtener_sesion
from gestor_conexiones import gestor
from models import Usuario
from schemas import (
    CambiarPassword, UsuarioActualizar, UsuarioCrear, UsuarioPublico, UsuarioRespuesta,
)
from seguridad import (
    encriptar_password, es_admin, solo_admin, usuario_actual, verificar_password,
)

router = APIRouter(prefix="/usuarios", tags=["Usuarios"])


def _obtener_usuario(db: Session, usuario_id: int) -> Usuario:
    usuario = db.get(Usuario, usuario_id)
    if usuario is None:
        raise HTTPException(
            status_code=404,
            detail="Usuario no encontrado",
        )
    return usuario


@router.get("", response_model=list[UsuarioRespuesta])
def listar_usuarios(
    db: Session = Depends(obtener_sesion),
    _: Usuario = Depends(solo_admin),
):
    return db.scalars(
        select(Usuario).order_by(Usuario.id_usr)
    ).all()


@router.get("/directorio", response_model=list[UsuarioPublico])
def directorio(
    db: Session = Depends(obtener_sesion),
    _: Usuario = Depends(usuario_actual),
):
    """Lista pública de usuarios (para iniciar chats) con su estado de conexión."""
    usuarios = db.scalars(
        select(Usuario).order_by(Usuario.nom_usr)
    ).all()
    return [
        UsuarioPublico(
            id_usr=u.id_usr,
            nom_usr=u.nom_usr,
            en_linea=gestor.en_linea(u.id_usr),
        )
        for u in usuarios
    ]


@router.post("", response_model=UsuarioRespuesta, status_code=201)
def crear_usuario(
    datos: UsuarioCrear,
    db: Session = Depends(obtener_sesion),
    _: Usuario = Depends(solo_admin),
):
    usuario = Usuario(
        nom_usr=datos.nom_usr.strip(),
        mail=datos.mail.strip().lower(),
        pass_hash=encriptar_password(datos.password),
        dir_usr=datos.dir_usr,
        tip_usu=datos.tip_usu,
    )

    db.add(usuario)

    try:
        db.commit()
        db.refresh(usuario)
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="El correo ya está registrado",
        )

    return usuario


@router.put("/{usuario_id}", response_model=UsuarioRespuesta)
def actualizar_usuario(
    usuario_id: int,
    datos: UsuarioActualizar,
    db: Session = Depends(obtener_sesion),
    actual: Usuario = Depends(usuario_actual),
):
    # Cada quien edita su perfil; el administrador puede editar a todos.
    if actual.id_usr != usuario_id and not es_admin(actual):
        raise HTTPException(
            status_code=403,
            detail="No puedes modificar a otro usuario",
        )

    usuario = _obtener_usuario(db, usuario_id)

    usuario.nom_usr = datos.nom_usr.strip()
    usuario.mail = datos.mail.strip().lower()
    usuario.dir_usr = datos.dir_usr
    # Sólo un administrador puede cambiar roles, y no el suyo propio
    # (evita quedarse sin administradores por accidente).
    if (
        datos.tip_usu is not None
        and es_admin(actual)
        and actual.id_usr != usuario_id
    ):
        usuario.tip_usu = datos.tip_usu

    try:
        db.commit()
        db.refresh(usuario)
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="El correo ya está registrado",
        )

    return usuario


@router.put("/{usuario_id}/password")
def cambiar_password(
    usuario_id: int,
    datos: CambiarPassword,
    db: Session = Depends(obtener_sesion),
    actual: Usuario = Depends(usuario_actual),
):
    if actual.id_usr != usuario_id:
        raise HTTPException(
            status_code=403,
            detail="Sólo puedes cambiar tu propia contraseña",
        )

    if not verificar_password(datos.password_actual, actual.pass_hash):
        raise HTTPException(
            status_code=400,
            detail="La contraseña actual es incorrecta",
        )

    actual.pass_hash = encriptar_password(datos.password_nueva)
    db.commit()

    return {"mensaje": "Contraseña actualizada"}


@router.delete("/{usuario_id}")
def eliminar_usuario(
    usuario_id: int,
    db: Session = Depends(obtener_sesion),
    actual: Usuario = Depends(solo_admin),
):
    if actual.id_usr == usuario_id:
        raise HTTPException(
            status_code=400,
            detail="No puedes eliminar tu propia cuenta",
        )

    usuario = _obtener_usuario(db, usuario_id)

    # Sus publicaciones, comentarios, calificaciones y mensajes
    # se eliminan en cascada desde la base de datos.
    db.delete(usuario)
    db.commit()

    return {"mensaje": "Usuario eliminado correctamente"}
