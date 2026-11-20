# Imagen multiplataforma: funciona en x86_64 (laptop) y arm64 (Raspberry Pi 4/5).
FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# La API no corre como root dentro del contenedor.
RUN useradd --create-home --uid 1000 api
USER api

EXPOSE 8000

# Un solo worker: las conexiones WebSocket del chat viven en memoria del proceso.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--proxy-headers"]
