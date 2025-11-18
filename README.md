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

## 4. Despliegue Local con Docker

### 4.1. Requisitos
```text
Docker y Docker Compose instalados.

OpenSSL para generar certificados (solo la primera vez).
```

### 4.2. Generar certificado SSL (self-signed)

Desde la raíz del proyecto:

```text
mkdir -p certs

openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout certs/miniwebapp.key \
  -out certs/miniwebapp.crt \
  -subj "/CN=localhost"
```

### 4.3. Levantar la aplicación + monitoreo + Grafana
```text
docker compose up -d
```

## 5. Despliegue en la Nube con AWS EC2

### 5.1. Creación de la instancia
```text
1. Crear instancia EC2 (Ubuntu 22.04/24.04).

2. Seleccionar un Key Pair y descargar el .pem.

3. Configurar el Security Group con reglas de entrada:

TCP 22 – SSH (solo desde IP propia).

TCP 80 – HTTP (0.0.0.0/0).

TCP 443 – HTTPS (0.0.0.0/0).

TCP 9090 – Prometheus (opcional, para pruebas).

TCP 3000 – Grafana (opcional, para pruebas).
```

## 5.2. Conexión por SSH

```text
chmod 600 cloudnova-miniwebapp.pem

ssh -i cloudnova-miniwebapp.pem ubuntu@IP_PUBLICA

En este caso use -> ssh -i ~/.ssh/cloudnova-miniwebapp.pem ubuntu@ec2-3-83-188-189.compute-1.amazonaws.com
```

### 5.3. Instalación de Docker y Docker Compose (en EC2)

```text
sudo apt update
sudo apt install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER
newgrp docker
```

### 5.4. Clonar repositorio y levantar servicios

```text
git clone https://github.com/Penachoz/MiniWebApp.git
cd MiniWebApp

docker compose up -d
docker ps

Comprobación desde el navegador:

Aplicación:
http://http://3.83.188.189 → redirige a https://http://3.83.188.189
(aceptar el certificado self-signed).

Prometheus:
http://http://3.83.188.189:9090

Grafana:
http://http://3.83.188.189:3000
```

## 6. Monitoreo con Prometheus + Node Exporter

### 6.1. Configuración de Prometheus

```text

Archivo prometheus/prometheus.yml:

global:
  scrape_interval: 15s

rule_files:
  - /etc/prometheus/alerts.yml

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['prometheus:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']


prometheus → se auto-scrapea.

node-exporter → expone métricas de la instancia (CPU, memoria, disco).
```

### 6.2. Node Exporter

```text
node-exporter:
  image: prom/node-exporter:latest
  container_name: node-exporter
  volumes:
    - /proc:/host/proc:ro
    - /sys:/host/sys:ro
    - /:/rootfs:ro
  command:
    - '--path.rootfs=/rootfs'
  ports:
    - "9100:9100"
  restart: unless-stopped
```

## 7. Métricas Documentadas (3 ejemplos claves)

### 7.1. Uso de CPU (%)

```text
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

Significado:
Calcula el porcentaje de CPU utilizada, restando al 100% el tiempo que la CPU pasa en modo idle.
Utilidad: permite detectar sobrecarga sostenida (por ejemplo, > 80%), lo que indica necesidad de optimización o escalamiento.
```
### 7.2. Uso de Memoria RAM (%)

```text
100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)

Significado:
Porcentaje de memoria RAM usada (no disponible) en el sistema.
Utilidad: ayuda a anticipar situaciones donde el servidor se queda sin memoria y empieza a usar swap, degradando el rendimiento.
```
### 7.3. Uso de Disco (%)

```text
100 * (1 - node_filesystem_avail_bytes{mountpoint="/"} 
           / node_filesystem_size_bytes{mountpoint="/"})

Significado:
Porcentaje de espacio en disco utilizado en el sistema de archivos raíz /.

40 → 40% del disco ocupado (60% libre).

90 → 90% del disco ocupado, riesgo alto de quedarse sin espacio.

Utilidad: previene incidentes por falta de espacio (logs, bases de datos, nuevos despliegues).
```

## 8. Alertas Básicas en Prometheus

```text
Archivo prometheus/alerts.yml:

groups:
  - name: general-alerts
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "CPU alta en {{ $labels.instance }}"
          description: "Uso de CPU mayor a 80% durante 5 minutos."

Esta alerta se dispara cuando el uso de CPU supera el 80% por más de 5 minutos.
```

## 9. Visualización con Grafana

### 9.1. Data Source Prometheus

```text
En Grafana:

Ir a Connections → Add data source → Prometheus.

Configurar:

Name: Prometheus

URL: http://prometheus:9090

Guardar y probar (Save & test).
```

### 9.2. Dashboard Propio (2 paneles requeridos)

```text
Panel 1 – Uso de CPU y Memoria (Time Series)
Data source: Prometheus.
Query A (CPU):
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

Panel 2 – Gauge de Uso de Disco
Tipo: Gauge.
Query:
100 * (1 - node_filesystem_avail_bytes{mountpoint="/"} 
           / node_filesystem_size_bytes{mountpoint="/"})
```

### 9.3. Dashboard Importado desde Grafana.com

```text
Se importó el dashboard oficial:

ID: 3662 – Prometheus 2.0 Overview
https://grafana.com/grafana/dashboards/3662-prometheus-2-0-overview/

Pasos:

En Grafana: Dashboards → New → Import.

Ingresar el ID 3662.

Seleccionar el data source Prometheus.

Importar y verificar que los gráficos muestren datos.
```

# Conclusión Técnica

## ¿Qué aprendí al integrar Docker, AWS y Prometheus?

Aprendí a empaquetar la aplicación web en contenedores reproducibles con Docker y a desplegarla en un servidor real en AWS EC2 reutilizando el mismo `docker-compose.yml`. Al integrar Prometheus y Node Exporter entendí cómo recolectar métricas de infraestructura (CPU, memoria, disco) y cómo usar esas métricas para definir alertas y alimentar dashboards en Grafana. Esto convierte la aplicación en un sistema observable, no solo “que funciona”.

## ¿Qué fue lo más desafiante y cómo lo resolvería en un entorno real?

Lo más desafiante fue coordinar todos los servicios (Nginx, aplicación Flask, Prometheus, Node Exporter y Grafana) para que se comunicaran correctamente, exponiendo puertos y volúmenes adecuados tanto localmente como en EC2. En un entorno real usaría herramientas de infraestructura como código (Terraform, Ansible) y orquestadores como Kubernetes para automatizar despliegues, además de automatizar certificados SSL con Let’s Encrypt y configurar Alertmanager para enviar notificaciones a canales de incidentes (correo, Slack, etc.).

## ¿Qué beneficio aporta la observabilidad en el ciclo DevOps?

La observabilidad permite ver en tiempo real cómo se comporta la aplicación y la infraestructura después de cada cambio: uso de CPU, memoria, disco, errores, latencias, etc. Esto reduce el tiempo de detección y resolución de problemas (MTTD/MTTR), facilita analizar el impacto de cada despliegue y ayuda a tomar decisiones informadas sobre escalamiento, capacidad y optimización. En DevOps, la observabilidad es clave para mantener la confiabilidad del servicio mientras se entregan nuevas funcionalidades de manera continua.
