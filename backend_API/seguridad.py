"""Encriptación de contraseñas, tokens JWT y control de acceso."""
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pwdlib import PasswordHash
from sqlalchemy.orm import Session

from config import ALGORITMO_JWT, MINUTOS_TOKEN, SECRET_KEY
from database import obtener_sesion
from models import Usuario

TIPO_ADMIN = 1
TIPO_REGULAR = 2

# Argon2id con los parámetros recomendados por pwdlib.
password_hash = PasswordHash.recommended()

# Hash de relleno: se verifica cuando el correo no existe para que la
# respuesta tarde lo mismo y no se pueda adivinar qué correos están registrados.
_HASH_RELLENO = password_hash.hash("relleno-para-tiempo-constante")


def encriptar_password(password: str) -> str:
    return password_hash.hash(password)


def verificar_password(password: str, hash_guardado: str | None) -> bool:
    if hash_guardado is None:
        password_hash.verify(password, _HASH_RELLENO)
        return False
    try:
        return password_hash.verify(password, hash_guardado)
    except Exception:
        # Hash con formato desconocido o corrupto.
        return False


def crear_token(usuario: Usuario) -> tuple[str, int]:
    ahora = datetime.now(timezone.utc)
    payload = {
        "sub": str(usuario.id_usr),
        "tip": usuario.tip_usu,
        "iat": ahora,
        "exp": ahora + timedelta(minutes=MINUTOS_TOKEN),
    }
    token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITMO_JWT)
    return token, MINUTOS_TOKEN * 60


def usuario_desde_token(token: str, db: Session) -> Usuario | None:
    try:
        datos = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITMO_JWT],
            options={"require": ["exp", "sub"]},
        )
        usuario_id = int(datos["sub"])
    except (jwt.PyJWTError, ValueError, KeyError):
        return None
    # Se consulta la BD en cada petición: si el usuario fue eliminado
    # o cambió de rol, el token deja de darle los permisos anteriores.
    return db.get(Usuario, usuario_id)


esquema_bearer = HTTPBearer(auto_error=False)


def usuario_actual(
    credenciales: HTTPAuthorizationCredentials | None = Depends(esquema_bearer),
    db: Session = Depends(obtener_sesion),
) -> Usuario:
    if credenciales is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No has iniciado sesión",
            headers={"WWW-Authenticate": "Bearer"},
        )

    usuario = usuario_desde_token(credenciales.credentials, db)
    if usuario is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Sesión inválida o expirada",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return usuario


def solo_admin(usuario: Usuario = Depends(usuario_actual)) -> Usuario:
    if usuario.tip_usu != TIPO_ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Se requieren permisos de administrador",
        )
    return usuario


def es_admin(usuario: Usuario) -> bool:
    return usuario.tip_usu == TIPO_ADMIN
