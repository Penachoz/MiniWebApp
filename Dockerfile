FROM python:3.11-slim

# Evitar prompts interactivos
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Primero dependencias (mejor cache)
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copiamos código de la app
COPY webapp/ /app/
COPY init.sql /app/init.sql

# Config de Flask
ENV FLASK_APP=run.py

EXPOSE 5000

# Usamos la ruta completa del binario de Flask (como en el README del profe)
CMD ["/usr/local/bin/flask", "run", "--host=0.0.0.0"]
