from sqlalchemy import (
    Boolean, CheckConstraint, Column, DateTime, ForeignKey,
    Integer, SmallInteger, String, Text, UniqueConstraint, func,
)
from sqlalchemy.orm import relationship

from database import Base


class Usuario(Base):
    __tablename__ = "usuario"

    id_usr = Column(Integer, primary_key=True, index=True)
    nom_usr = Column(String(100), nullable=False)
    mail = Column(String(150), unique=True, nullable=False)
    pass_hash = Column("pass", String(255), nullable=False)
    dir_usr = Column(String(200), nullable=True)
    # 1 = administrador, 2 = usuario regular.
    tip_usu = Column(Integer, nullable=False, default=2)


class Blog(Base):
    __tablename__ = "blog"

    id_blog = Column(Integer, primary_key=True, index=True)
    titulo = Column(String(150), nullable=False)
    descripcion = Column("desc", Text, nullable=True)
    img = Column(String(500), nullable=True)
    tags = Column(String(255), nullable=True)
    fecha = Column(
        DateTime,
        nullable=False,
        server_default=func.current_timestamp(),
    )
    usr_id = Column(
        Integer,
        ForeignKey("usuario.id_usr", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    autor = relationship("Usuario", lazy="joined")


class Comentario(Base):
    __tablename__ = "comentarios"

    id_com = Column(Integer, primary_key=True, index=True)
    comentario = Column(Text, nullable=False)
    fecha = Column(
        DateTime,
        nullable=False,
        server_default=func.current_timestamp(),
    )
    # 1 = visible, 0 = eliminado (borrado lógico).
    estatus = Column(Integer, nullable=False, default=1)
    usr_id = Column(
        Integer,
        ForeignKey("usuario.id_usr", ondelete="CASCADE"),
        nullable=False,
    )
    blog_id = Column(
        Integer,
        ForeignKey("blog.id_blog", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    autor = relationship("Usuario", lazy="joined")


class Calificacion(Base):
    __tablename__ = "calificacion"
    __table_args__ = (
        UniqueConstraint("usr_id", "blog_id", name="uq_calificacion_usuario_blog"),
        CheckConstraint("estrellas BETWEEN 1 AND 5", name="ck_calificacion_estrellas"),
    )

    id_cal = Column(Integer, primary_key=True, index=True)
    estrellas = Column(SmallInteger, nullable=False)
    fecha = Column(
        DateTime,
        nullable=False,
        server_default=func.current_timestamp(),
        onupdate=func.current_timestamp(),
    )
    usr_id = Column(
        Integer,
        ForeignKey("usuario.id_usr", ondelete="CASCADE"),
        nullable=False,
    )
    blog_id = Column(
        Integer,
        ForeignKey("blog.id_blog", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )


class Conversacion(Base):
    __tablename__ = "conversacion"

    id_conv = Column(Integer, primary_key=True, index=True)
    # Sólo los grupos tienen nombre; los chats directos usan el del otro usuario.
    nombre = Column(String(100), nullable=True)
    es_grupo = Column(Boolean, nullable=False, default=False)
    creador_id = Column(
        Integer,
        ForeignKey("usuario.id_usr", ondelete="SET NULL"),
        nullable=True,
    )
    fecha = Column(
        DateTime,
        nullable=False,
        server_default=func.current_timestamp(),
    )

    miembros = relationship(
        "ConversacionMiembro",
        back_populates="conversacion",
        cascade="all, delete-orphan",
        lazy="selectin",
    )


class ConversacionMiembro(Base):
    __tablename__ = "conversacion_miembro"

    conv_id = Column(
        Integer,
        ForeignKey("conversacion.id_conv", ondelete="CASCADE"),
        primary_key=True,
    )
    usr_id = Column(
        Integer,
        ForeignKey("usuario.id_usr", ondelete="CASCADE"),
        primary_key=True,
        index=True,
    )
    fecha_union = Column(
        DateTime,
        nullable=False,
        server_default=func.current_timestamp(),
    )
    # Último mensaje leído por este miembro; sirve para contar no leídos.
    ultimo_leido_id = Column(Integer, nullable=False, default=0)

    conversacion = relationship("Conversacion", back_populates="miembros")
    usuario = relationship("Usuario", lazy="joined")


class Mensaje(Base):
    __tablename__ = "mensaje"

    id_msg = Column(Integer, primary_key=True, index=True)
    contenido = Column(Text, nullable=False)
    fecha = Column(
        DateTime,
        nullable=False,
        server_default=func.current_timestamp(),
    )
    conv_id = Column(
        Integer,
        ForeignKey("conversacion.id_conv", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    usr_id = Column(
        Integer,
        ForeignKey("usuario.id_usr", ondelete="CASCADE"),
        nullable=False,
    )

    autor = relationship("Usuario", lazy="joined")
