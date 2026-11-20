import threading
import time

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from config import MAX_INTENTOS_LOGIN, SEGUNDOS_BLOQUEO_LOGIN
from database import obtener_sesion
from models import Usuario
from schemas import LoginRequest, RegistroUsuario, TokenRespuesta, UsuarioRespuesta
from seguridad import (
    TIPO_REGULAR, crear_token, encriptar_password, usuario_actual, verificar_password,
)

router = APIRouter(tags=["Autenticación"])

# correo -> (intentos fallidos, momento en que termina el bloqueo)
_intentos_fallidos: dict[str, tuple[int, float]] = {}
_candado_intentos = threading.Lock()


def _verificar_bloqueo(correo: str) -> None:
    with _candado_intentos:
        _, bloqueado_hasta = _intentos_fallidos.get(correo, (0, 0.0))
    restante = int(bloqueado_hasta - time.monotonic())
    if restante > 0:
        raise HTTPException(
            status_code=429,
            detail=f"Demasiados intentos fallidos. Intenta de nuevo en {restante} segundos",
        )


def _registrar_fallo(correo: str) -> None:
    with _candado_intentos:
        intentos, _ = _intentos_fallidos.get(correo, (0, 0.0))
        intentos += 1
        if intentos >= MAX_INTENTOS_LOGIN:
            _intentos_fallidos[correo] = (0, time.monotonic() + SEGUNDOS_BLOQUEO_LOGIN)
        else:
            _intentos_fallidos[correo] = (intentos, 0.0)


@router.post("/login", response_model=TokenRespuesta)
def iniciar_sesion(
    datos: LoginRequest,
    db: Session = Depends(obtener_sesion),
):
    correo = datos.mail.strip().lower()
    _verificar_bloqueo(correo)

    usuario = db.scalar(
        select(Usuario).where(Usuario.mail == correo)
    )

    # Se utiliza el mismo mensaje para no revelar
    # si el correo está registrado.
    if not verificar_password(
        datos.password,
        usuario.pass_hash if usuario else None,
    ):
        _registrar_fallo(correo)
        raise HTTPException(
            status_code=401,
            detail="Correo o contraseña incorrectos",
        )

    with _candado_intentos:
        _intentos_fallidos.pop(correo, None)

    token, expira_en = crear_token(usuario)
    return TokenRespuesta(
        access_token=token,
        expira_en=expira_en,
        usuario=UsuarioRespuesta.model_validate(usuario),
    )


@router.post("/auth/registro", response_model=UsuarioRespuesta, status_code=201)
def registrar(
    datos: RegistroUsuario,
    db: Session = Depends(obtener_sesion),
):
    usuario = Usuario(
        nom_usr=datos.nom_usr.strip(),
        mail=datos.mail.strip().lower(),
        pass_hash=encriptar_password(datos.password),
        dir_usr=datos.dir_usr.strip() if datos.dir_usr and datos.dir_usr.strip() else None,
        # El registro público nunca puede crear administradores.
        tip_usu=TIPO_REGULAR,
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


@router.get("/auth/yo", response_model=UsuarioRespuesta)
def usuario_en_sesion(usuario: Usuario = Depends(usuario_actual)):
    """Valida el token guardado en la app y devuelve los datos actuales."""
    return usuario
