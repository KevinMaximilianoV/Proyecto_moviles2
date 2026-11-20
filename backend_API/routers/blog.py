from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from database import obtener_sesion
from models import Blog, Calificacion, Comentario, Usuario
from schemas import (
    BlogCrear, BlogRespuesta, CalificacionCrear, ComentarioCrear,
    ComentarioRespuesta, ResumenCalificacion,
)
from seguridad import es_admin, usuario_actual

router = APIRouter(tags=["Blog"])


def _texto_opcional(valor: str | None) -> str | None:
    return valor.strip() if valor and valor.strip() else None


def _consulta_blogs(usuario_id: int):
    """Publicaciones con autor, promedio de estrellas, comentarios
    y la calificación del usuario en sesión, en una sola consulta."""
    calificaciones = (
        select(
            Calificacion.blog_id,
            func.avg(Calificacion.estrellas).label("promedio"),
            func.count().label("total"),
        )
        .group_by(Calificacion.blog_id)
        .subquery()
    )
    comentarios = (
        select(
            Comentario.blog_id,
            func.count().label("total"),
        )
        .where(Comentario.estatus == 1)
        .group_by(Comentario.blog_id)
        .subquery()
    )
    mia = (
        select(Calificacion.blog_id, Calificacion.estrellas)
        .where(Calificacion.usr_id == usuario_id)
        .subquery()
    )
    return (
        select(
            Blog,
            calificaciones.c.promedio,
            calificaciones.c.total,
            comentarios.c.total,
            mia.c.estrellas,
        )
        .outerjoin(calificaciones, calificaciones.c.blog_id == Blog.id_blog)
        .outerjoin(comentarios, comentarios.c.blog_id == Blog.id_blog)
        .outerjoin(mia, mia.c.blog_id == Blog.id_blog)
    )


def _a_respuesta(fila) -> BlogRespuesta:
    blog, promedio, total_cal, total_com, mi_cal = fila
    return BlogRespuesta(
        id_blog=blog.id_blog,
        titulo=blog.titulo,
        descripcion=blog.descripcion,
        img=blog.img,
        tags=blog.tags,
        fecha=blog.fecha,
        usr_id=blog.usr_id,
        autor_nombre=blog.autor.nom_usr,
        promedio=round(float(promedio), 2) if promedio is not None else None,
        total_calificaciones=total_cal or 0,
        mi_calificacion=mi_cal,
        total_comentarios=total_com or 0,
    )


def _obtener_blog(db: Session, blog_id: int) -> Blog:
    publicacion = db.get(Blog, blog_id)
    if publicacion is None:
        raise HTTPException(
            status_code=404,
            detail="Publicación no encontrada",
        )
    return publicacion


def _blog_respuesta(db: Session, blog_id: int, usuario_id: int) -> BlogRespuesta:
    fila = db.execute(
        _consulta_blogs(usuario_id).where(Blog.id_blog == blog_id)
    ).first()
    if fila is None:
        raise HTTPException(
            status_code=404,
            detail="Publicación no encontrada",
        )
    return _a_respuesta(fila)


def _verificar_dueno(publicacion: Blog, usuario: Usuario) -> None:
    if publicacion.usr_id != usuario.id_usr and not es_admin(usuario):
        raise HTTPException(
            status_code=403,
            detail="Sólo el autor o un administrador puede modificar esta publicación",
        )


# BLOG

@router.get("/blog", response_model=list[BlogRespuesta])
def listar_blog(
    autor_id: int | None = Query(default=None, description="Filtra por autor"),
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    consulta = _consulta_blogs(usuario.id_usr)
    if autor_id is not None:
        consulta = consulta.where(Blog.usr_id == autor_id)
    consulta = consulta.order_by(Blog.fecha.desc(), Blog.id_blog.desc())
    return [_a_respuesta(fila) for fila in db.execute(consulta).all()]


@router.get("/blog/{blog_id}", response_model=BlogRespuesta)
def obtener_blog(
    blog_id: int,
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    return _blog_respuesta(db, blog_id, usuario.id_usr)


@router.post("/blog", response_model=BlogRespuesta, status_code=201)
def crear_blog(
    datos: BlogCrear,
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    publicacion = Blog(
        titulo=datos.titulo.strip(),
        descripcion=_texto_opcional(datos.descripcion),
        img=_texto_opcional(datos.img),
        tags=_texto_opcional(datos.tags),
        # El autor siempre es quien tiene la sesión, nunca un dato del cliente.
        usr_id=usuario.id_usr,
    )

    db.add(publicacion)
    db.commit()

    return _blog_respuesta(db, publicacion.id_blog, usuario.id_usr)


@router.put("/blog/{blog_id}", response_model=BlogRespuesta)
def actualizar_blog(
    blog_id: int,
    datos: BlogCrear,
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    publicacion = _obtener_blog(db, blog_id)
    _verificar_dueno(publicacion, usuario)

    publicacion.titulo = datos.titulo.strip()
    publicacion.descripcion = _texto_opcional(datos.descripcion)
    publicacion.img = _texto_opcional(datos.img)
    publicacion.tags = _texto_opcional(datos.tags)
    db.commit()

    return _blog_respuesta(db, blog_id, usuario.id_usr)


@router.delete("/blog/{blog_id}")
def eliminar_blog(
    blog_id: int,
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    publicacion = _obtener_blog(db, blog_id)
    _verificar_dueno(publicacion, usuario)

    db.delete(publicacion)
    db.commit()

    return {"mensaje": "Publicación eliminada correctamente"}


# COMENTARIOS

def _comentario_respuesta(c: Comentario) -> ComentarioRespuesta:
    return ComentarioRespuesta(
        id_com=c.id_com,
        comentario=c.comentario,
        fecha=c.fecha,
        usr_id=c.usr_id,
        blog_id=c.blog_id,
        autor_nombre=c.autor.nom_usr,
    )


@router.get(
    "/blog/{blog_id}/comentarios",
    response_model=list[ComentarioRespuesta],
)
def listar_comentarios(
    blog_id: int,
    db: Session = Depends(obtener_sesion),
    _: Usuario = Depends(usuario_actual),
):
    _obtener_blog(db, blog_id)
    comentarios = db.scalars(
        select(Comentario)
        .where(Comentario.blog_id == blog_id, Comentario.estatus == 1)
        .order_by(Comentario.fecha, Comentario.id_com)
    ).all()
    return [_comentario_respuesta(c) for c in comentarios]


@router.post(
    "/blog/{blog_id}/comentarios",
    response_model=ComentarioRespuesta,
    status_code=201,
)
def crear_comentario(
    blog_id: int,
    datos: ComentarioCrear,
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    texto = datos.comentario.strip()
    if not texto:
        raise HTTPException(
            status_code=422,
            detail="El comentario no puede estar vacío",
        )

    _obtener_blog(db, blog_id)

    nuevo = Comentario(
        comentario=texto,
        usr_id=usuario.id_usr,
        blog_id=blog_id,
        estatus=1,
    )

    db.add(nuevo)
    db.commit()
    db.refresh(nuevo)

    return _comentario_respuesta(nuevo)


@router.delete("/comentarios/{comentario_id}")
def eliminar_comentario(
    comentario_id: int,
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    comentario = db.get(Comentario, comentario_id)
    if comentario is None or comentario.estatus != 1:
        raise HTTPException(
            status_code=404,
            detail="Comentario no encontrado",
        )

    # Puede borrarlo su autor, el autor de la publicación o un administrador.
    autor_blog = db.scalar(
        select(Blog.usr_id).where(Blog.id_blog == comentario.blog_id)
    )
    if usuario.id_usr not in (comentario.usr_id, autor_blog) and not es_admin(usuario):
        raise HTTPException(
            status_code=403,
            detail="No puedes eliminar este comentario",
        )

    # Borrado lógico: se conserva el registro con estatus 0.
    comentario.estatus = 0
    db.commit()

    return {"mensaje": "Comentario eliminado"}


# CALIFICACIONES

def _resumen(db: Session, blog_id: int, usuario_id: int) -> ResumenCalificacion:
    promedio, total = db.execute(
        select(func.avg(Calificacion.estrellas), func.count())
        .where(Calificacion.blog_id == blog_id)
    ).one()
    mia = db.scalar(
        select(Calificacion.estrellas).where(
            Calificacion.blog_id == blog_id,
            Calificacion.usr_id == usuario_id,
        )
    )
    return ResumenCalificacion(
        promedio=round(float(promedio), 2) if promedio is not None else None,
        total=total,
        mi_calificacion=mia,
    )


@router.put(
    "/blog/{blog_id}/calificacion",
    response_model=ResumenCalificacion,
)
def calificar_blog(
    blog_id: int,
    datos: CalificacionCrear,
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    """Crea o actualiza la calificación (1 a 5 estrellas) del usuario."""
    publicacion = _obtener_blog(db, blog_id)
    if publicacion.usr_id == usuario.id_usr:
        raise HTTPException(
            status_code=400,
            detail="No puedes calificar tu propia publicación",
        )

    existente = db.scalar(
        select(Calificacion).where(
            Calificacion.blog_id == blog_id,
            Calificacion.usr_id == usuario.id_usr,
        )
    )
    if existente is None:
        db.add(Calificacion(
            blog_id=blog_id,
            usr_id=usuario.id_usr,
            estrellas=datos.estrellas,
        ))
    else:
        existente.estrellas = datos.estrellas

    try:
        db.commit()
    except IntegrityError:
        # Dos peticiones simultáneas del mismo usuario: gana la última.
        db.rollback()
        db.execute(
            Calificacion.__table__.update()
            .where(
                Calificacion.blog_id == blog_id,
                Calificacion.usr_id == usuario.id_usr,
            )
            .values(estrellas=datos.estrellas)
        )
        db.commit()

    return _resumen(db, blog_id, usuario.id_usr)


@router.delete(
    "/blog/{blog_id}/calificacion",
    response_model=ResumenCalificacion,
)
def quitar_calificacion(
    blog_id: int,
    db: Session = Depends(obtener_sesion),
    usuario: Usuario = Depends(usuario_actual),
):
    _obtener_blog(db, blog_id)
    existente = db.scalar(
        select(Calificacion).where(
            Calificacion.blog_id == blog_id,
            Calificacion.usr_id == usuario.id_usr,
        )
    )
    if existente is not None:
        db.delete(existente)
        db.commit()

    return _resumen(db, blog_id, usuario.id_usr)
