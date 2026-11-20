from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError, OperationalError

from config import CORS_ORIGINS, logger
from database import engine
from routers import auth, blog, chat, usuarios


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Verifica la conexión a MySQL al arrancar para detectar
    # errores de configuración de inmediato.
    try:
        with engine.connect() as conexion:
            conexion.execute(text("SELECT 1"))
        logger.info("Conexión a MySQL verificada")
    except OperationalError as error:
        logger.error("No se pudo conectar a MySQL: %s", error.orig)
    yield

app = FastAPI(
    title="API de aplicación móvil",
    description="Blog con comentarios, calificaciones y mensajería en tiempo real.",
    version="2.0.0",
    lifespan=lifespan,
)

# Permitir la comunicación con Flutter Web
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Manejo centralizado de errores de base de datos: el cliente recibe
# un mensaje claro y nunca el detalle interno de MySQL.
@app.exception_handler(IntegrityError)
async def error_integridad(request: Request, exc: IntegrityError):
    logger.warning("IntegrityError en %s: %s", request.url.path, exc.orig)
    return JSONResponse(
        status_code=409,
        content={"detail": "La operación entra en conflicto con datos existentes"},
    )


@app.exception_handler(OperationalError)
async def error_operacional(request: Request, exc: OperationalError):
    logger.error("Error de base de datos en %s: %s", request.url.path, exc.orig)
    return JSONResponse(
        status_code=503,
        content={"detail": "Base de datos no disponible, intenta más tarde"},
    )


@app.get("/", tags=["Estado"])
def inicio():
    return {"mensaje": "API funcionando correctamente"}


app.include_router(auth.router)
app.include_router(usuarios.router)
app.include_router(blog.router)
app.include_router(chat.router)
