from datetime import datetime, timezone
from typing import Annotated

from pydantic import AfterValidator, BaseModel, ConfigDict, Field


def _como_utc(fecha: datetime) -> datetime:
    # MySQL devuelve fechas sin zona horaria; la API las guarda en UTC.
    return fecha.replace(tzinfo=timezone.utc) if fecha.tzinfo is None else fecha


FechaUTC = Annotated[datetime, AfterValidator(_como_utc)]

PATRON_CORREO = r"^[^@\s]+@[^@\s]+\.[^@\s]+$"


# USUARIOS

class RegistroUsuario(BaseModel):
    """Registro público desde la app: siempre crea usuarios regulares."""
    nom_usr: str = Field(min_length=2, max_length=100)
    mail: str = Field(min_length=5, max_length=150, pattern=PATRON_CORREO)
    password: str = Field(min_length=8, max_length=128)
    dir_usr: str | None = Field(default=None, max_length=200)


class UsuarioCrear(RegistroUsuario):
    """Alta hecha por un administrador: puede elegir el tipo de usuario."""
    tip_usu: int = Field(default=2, ge=1, le=2)


class UsuarioRespuesta(BaseModel):
    id_usr: int
    nom_usr: str
    mail: str
    dir_usr: str | None
    tip_usu: int

    model_config = ConfigDict(from_attributes=True)


class UsuarioPublico(BaseModel):
    """Datos visibles para cualquier usuario (sin correo ni dirección)."""
    id_usr: int
    nom_usr: str
    en_linea: bool = False

    model_config = ConfigDict(from_attributes=True)


class UsuarioActualizar(BaseModel):
    nom_usr: str = Field(min_length=2, max_length=100)
    mail: str = Field(min_length=5, max_length=150, pattern=PATRON_CORREO)
    dir_usr: str | None = Field(default=None, max_length=200)
    # Sólo se toma en cuenta si quien actualiza es administrador.
    tip_usu: int | None = Field(default=None, ge=1, le=2)


class CambiarPassword(BaseModel):
    password_actual: str = Field(min_length=1, max_length=128)
    password_nueva: str = Field(min_length=8, max_length=128)


# AUTENTICACIÓN

class LoginRequest(BaseModel):
    mail: str = Field(min_length=5, max_length=150)
    password: str = Field(min_length=1, max_length=128)


class TokenRespuesta(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expira_en: int
    usuario: UsuarioRespuesta


# BLOG

class BlogCrear(BaseModel):
    titulo: str = Field(min_length=1, max_length=150)
    descripcion: str | None = Field(default=None, max_length=20000)
    img: str | None = Field(default=None, max_length=500, pattern=r"^(https?://\S+)?$")
    tags: str | None = Field(default=None, max_length=255)


class BlogRespuesta(BaseModel):
    id_blog: int
    titulo: str
    descripcion: str | None = None
    img: str | None = None
    tags: str | None = None
    fecha: FechaUTC
    usr_id: int
    autor_nombre: str
    promedio: float | None = None
    total_calificaciones: int = 0
    mi_calificacion: int | None = None
    total_comentarios: int = 0


# COMENTARIOS

class ComentarioCrear(BaseModel):
    comentario: str = Field(min_length=1, max_length=1000)


class ComentarioRespuesta(BaseModel):
    id_com: int
    comentario: str
    fecha: FechaUTC
    usr_id: int
    blog_id: int
    autor_nombre: str


# CALIFICACIONES

class CalificacionCrear(BaseModel):
    estrellas: int = Field(ge=1, le=5)


class ResumenCalificacion(BaseModel):
    promedio: float | None
    total: int
    mi_calificacion: int | None


# CHAT

class MiembroRespuesta(BaseModel):
    id_usr: int
    nom_usr: str
    en_linea: bool = False


class MensajeCrear(BaseModel):
    contenido: str = Field(min_length=1, max_length=2000)


class MensajeRespuesta(BaseModel):
    id_msg: int
    conv_id: int
    usr_id: int
    autor_nombre: str
    contenido: str
    fecha: FechaUTC


class ConversacionRespuesta(BaseModel):
    id_conv: int
    nombre: str
    es_grupo: bool
    creador_id: int | None
    fecha: FechaUTC
    miembros: list[MiembroRespuesta]
    ultimo_mensaje: MensajeRespuesta | None = None
    no_leidos: int = 0


class DirectoCrear(BaseModel):
    usuario_id: int


class GrupoCrear(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)
    miembros: list[int] = Field(min_length=1, max_length=50)


class GrupoActualizar(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)


class MiembrosAgregar(BaseModel):
    usuarios: list[int] = Field(min_length=1, max_length=50)
