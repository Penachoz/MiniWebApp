# CloudNova – Despliegue Seguro, Monitoreo y Visualización

Examen final – DevOps / Servicios en la Nube  
Proyecto basado en la MiniWebApp del profesor, desplegada de forma segura en Docker, AWS EC2 y monitoreada con Prometheus, Node Exporter y Grafana.

---

## 1. Descripción General

La empresa ficticia **CloudNova** desea llevar su aplicación web desde un entorno de desarrollo a un entorno de producción **seguro, disponible y observable**.

Este repositorio contiene:

- Empaquetado de la MiniWebApp en **Docker**.
- Servidor **Nginx** usando **HTTPS** (con redirección HTTP → HTTPS).
- Despliegue en una instancia **AWS EC2** mediante `docker compose`.
- **Monitoreo** del servidor con **Prometheus + Node Exporter**.
- **Visualización** de métricas con **Grafana** (dashboards propios + dashboard importado desde grafana.com).

---

## 2. Arquitectura

Servicios principales orquestados con `docker-compose`:

- **app**: aplicación Flask MiniWebApp.
- **miniwebapp-nginx**: Nginx como reverse proxy con SSL (HTTPS) hacia `app`.
- **prometheus**: recolector de métricas.
- **node-exporter**: exposición de métricas de sistema (CPU, RAM, disco) del host.
- **grafana**: visualización de métricas y dashboards.

Flujo:

```text
Cliente → Nginx (HTTPS 443) → Flask (app:5000)
             │
             ├─ Prometheus (9090) ← Node Exporter (9100)
             └─ Grafana (3000) → lee métricas desde Prometheus

```

## 3. Estructura del Proyecto

```text
MiniWebApp/
├─ webapp/                  # Código de la MiniWebApp (Flask)
│  ├─ run.py
│  ├─ config.py
│  └─ ...
├─ nginx/
│  └─ default.conf          # Configuración Nginx con HTTPS + proxy_pass
├─ certs/
│  ├─ miniwebapp.crt        # Certificado SSL (self-signed para pruebas)
│  └─ miniwebapp.key        # Clave privada
├─ prometheus/
│  ├─ prometheus.yml        # Configuración de scrapes
│  └─ alerts.yml            # Reglas de alerta
├─ grafana/
│  └─ dashboards/
│     └─ 3662-prometheus-2.0-overview.json  # Dashboard importado (ID 3662)
├─ Dockerfile               # Imagen de la app Flask
├─ docker-compose.yml       # Orquestación de la solución completa
├─ requirements.txt         # Dependencias de Python (Flask, SQLAlchemy, etc.)
└─ init.sql                 # Script SQL de la MiniWebApp (opcional)
```
