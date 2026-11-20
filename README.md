# Blog móvil con chat en tiempo real

Aplicación móvil en **Flutter** que consume una **API en FastAPI** con base de datos **MySQL**.

| Funcionalidad | Detalle |
|---|---|
| Registro e inicio de sesión | Desde la app; contraseñas con **Argon2id**, sesión con **JWT** guardado en almacenamiento seguro del dispositivo |
| Control de acceso | Usuarios regulares y administradores; la API valida permisos en cada petición |
| Blog | Ver publicaciones propias y de otros, crear, editar y borrar las propias |
| Comentarios | Leer, crear y borrar comentarios en cada publicación |
| ⭐ Calificaciones *(opcional)* | 1 a 5 estrellas por usuario y publicación, con promedio |
| 💬 Mensajería interna *(opcional)* | Chats directos y **grupos** por **WebSocket**, indicador de "escribiendo", mensajes no leídos y estado **en línea / desconectado** |

```
proyectobackend/
├── docker-compose.yml      # Servidor completo: MySQL + API
├── .env.example            # Variables del servidor (copiar como .env)
├── docs/arquitectura.md    # Diagramas, modelo de datos y seguridad
├── backend_API/            # API FastAPI
│   ├── main.py             # Arranque, CORS, manejo de errores
│   ├── config.py           # Variables de entorno
│   ├── database.py         # Conexión a MySQL (SQLAlchemy)
│   ├── models.py           # Tablas
│   ├── schemas.py          # Validación de entrada/salida (Pydantic)
│   ├── seguridad.py        # Argon2, JWT y dependencias de permisos
│   ├── gestor_conexiones.py# Conexiones WebSocket activas
│   ├── routers/            # auth, usuarios, blog, chat
│   ├── bd.sql              # Script de creación de la base de datos
│   └── Dockerfile
└── flutter_application_3/  # App Flutter
    └── lib/
        ├── config/         # URL del servidor, navegación global
        ├── models/         # Usuario, post, comentario, chat
        ├── services/       # Cliente HTTP, sesión, servicios REST y WebSocket
        ├── screens/        # Pantallas
        ├── widgets/        # Componentes reutilizables
        └── utils/          # Formato de fechas
```

---

## 1. Levantar el servidor (laptop o Raspberry Pi)

Requisitos: **Docker** con el plugin **compose**. En Raspberry Pi se necesita un sistema de **64 bits** (Raspberry Pi OS 64-bit, Pi 4 o 5), porque la imagen de MySQL 8 sólo existe para arm64.

```bash
cd proyectobackend
cp .env.example .env
# Edita .env: pon contraseñas propias y genera la SECRET_KEY con
python3 -c "import secrets; print(secrets.token_urlsafe(48))"

docker compose up -d --build
```

La primera vez MySQL ejecuta `backend_API/bd.sql` (tablas + datos de prueba); puede tardar 1–3 minutos en una Raspberry Pi. Para revisar:

```bash
docker compose ps            # ambos servicios deben verse "healthy" / "Up"
docker compose logs -f api   # debe mostrar "Conexión a MySQL verificada"
curl http://localhost:8000/  # {"mensaje":"API funcionando correctamente"}
```

- Documentación interactiva de la API: `http://IP_DEL_SERVIDOR:8000/docs`
- Para reiniciar la base de datos desde cero: `docker compose down -v && docker compose up -d`
- Los datos persisten en el volumen `mysql_datos` aunque se reinicie el equipo (`restart: unless-stopped`).

### Encontrar la IP del servidor

Los celulares deben estar en la **misma red Wi-Fi** que el servidor.

```bash
hostname -I     # Linux / Raspberry Pi  → p. ej. 192.168.1.50
ipconfig        # Windows
```

Si la laptop tiene firewall, abre el puerto 8000 (p. ej. `sudo ufw allow 8000/tcp`).

### Usuarios de prueba

| Correo | Contraseña | Tipo |
|---|---|---|
| admin@ejemplo.com | `Admin123!` | Administrador |
| adriana@ejemplo.com | `Usuario123!` | Regular |
| carlos@ejemplo.com | `Usuario123!` | Regular |

### Alternativa sin Docker

```bash
cd backend_API
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # y llena los datos de tu MySQL/MariaDB
mysql -u root -p < bd.sql     # si ya existía la BD: DROP DATABASE bd_aplicacion_movil; antes
uvicorn main:app --host 0.0.0.0 --port 8000
```

> La API debe correr con **un solo worker** (como en el Dockerfile): las conexiones del chat se guardan en memoria del proceso.

---

## 2. Ejecutar la app Flutter

```bash
cd flutter_application_3
flutter pub get
flutter run
```

En la pantalla de inicio de sesión, toca la dirección del servidor (debajo de "Registrarse") y escribe la del equipo que corre la API, por ejemplo `http://192.168.1.50:8000`. Se guarda en el dispositivo.

| Dónde corre la app | URL del servidor |
|---|---|
| Celular físico | `http://IP_DEL_SERVIDOR:8000` |
| Emulador de Android | `http://10.0.2.2:8000` (si la API está en la misma PC) |
| Linux / Web en la misma PC | `http://127.0.0.1:8000` (valor por defecto) |

También se puede fijar al compilar:

```bash
flutter run --dart-define=API_URL=http://192.168.1.50:8000
flutter build apk --dart-define=API_URL=http://192.168.1.50:8000
```

### Pruebas

```bash
flutter test                                 # pruebas unitarias
# Extremo a extremo (requiere el servidor con datos de prueba recién creados):
docker compose down -v && docker compose up -d --wait
flutter test integration_test -d linux
```

---

## 3. Uso

1. **Registrarse** o iniciar sesión con un usuario de prueba. La sesión se recuerda hasta que vence (12 h por defecto) o se cierra desde el menú.
2. **Blog**: pestañas *Todas* y *Mis publicaciones*. Botón **Publicar** para crear una entrada.
3. Al abrir una publicación: toca las **estrellas** para calificar (tocar la misma estrella quita la calificación) y escribe **comentarios** abajo. El autor puede editar o borrar su publicación desde el menú ⋮.
4. **Mensajes** (menú lateral): botón ✎ para iniciar un **chat** con alguien o crear un **grupo**. El punto verde indica quién está en línea. En un grupo, toca el nombre para ver integrantes, agregar personas, renombrarlo o salir.
5. Los **administradores** ven además *Gestión de usuarios* y *Registrar usuario* (pueden crear otros administradores).

---

## 4. Resumen de la API

Todas las rutas, salvo `/login` y `/auth/registro`, requieren el encabezado `Authorization: Bearer <token>`.

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/login` | Devuelve `access_token` y datos del usuario |
| POST | `/auth/registro` | Registro público (siempre usuario regular) |
| GET | `/auth/yo` | Usuario de la sesión actual |
| GET/POST | `/usuarios` | Listar / crear usuarios *(admin)* |
| GET | `/usuarios/directorio` | Nombres y estado en línea (para el chat) |
| PUT | `/usuarios/{id}` | Editar perfil propio (o cualquiera si es admin) |
| PUT | `/usuarios/{id}/password` | Cambiar la contraseña propia |
| DELETE | `/usuarios/{id}` | Eliminar usuario *(admin)* |
| GET/POST | `/blog` | Listar (`?autor_id=`) / crear publicaciones |
| GET/PUT/DELETE | `/blog/{id}` | Ver / editar / borrar *(autor o admin)* |
| GET/POST | `/blog/{id}/comentarios` | Leer / crear comentarios |
| DELETE | `/comentarios/{id}` | Borrar comentario *(su autor, el del post o admin)* |
| PUT/DELETE | `/blog/{id}/calificacion` | Calificar 1–5 / quitar calificación |
| GET | `/chats` | Conversaciones con último mensaje y no leídos |
| POST | `/chats/directo` | Abrir (o crear) chat con un usuario |
| POST | `/chats/grupo` | Crear grupo |
| PUT | `/chats/{id}` | Renombrar grupo |
| POST | `/chats/{id}/miembros` | Agregar integrantes |
| DELETE | `/chats/{id}/miembros/yo` | Salir del grupo |
| GET/POST | `/chats/{id}/mensajes` | Historial paginado (`?antes_de=&limite=`) / enviar |
| POST | `/chats/{id}/leido` | Marcar como leído |
| WS | `/ws` | Tiempo real (ver `docs/arquitectura.md`) |
