import logging
import os
import secrets

from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger("uvicorn.error")

# Clave con la que se firman los tokens JWT. Debe ser larga y secreta.
SECRET_KEY = os.getenv("SECRET_KEY", "")
if len(SECRET_KEY) < 32:
    SECRET_KEY = secrets.token_urlsafe(48)
    logger.warning(
        "SECRET_KEY no definida o muy corta: se generó una temporal. "
        "Las sesiones se invalidarán al reiniciar la API."
    )

ALGORITMO_JWT = "HS256"
MINUTOS_TOKEN = int(os.getenv("MINUTOS_TOKEN", "720"))

# Orígenes permitidos para CORS (Flutter Web). "*" permite cualquiera;
# es seguro porque la autenticación viaja en el encabezado Authorization,
# no en cookies.
CORS_ORIGINS = [
    origen.strip()
    for origen in os.getenv("CORS_ORIGINS", "*").split(",")
    if origen.strip()
]

# Protección contra fuerza bruta en el inicio de sesión.
MAX_INTENTOS_LOGIN = int(os.getenv("MAX_INTENTOS_LOGIN", "5"))
SEGUNDOS_BLOQUEO_LOGIN = int(os.getenv("SEGUNDOS_BLOQUEO_LOGIN", "300"))
