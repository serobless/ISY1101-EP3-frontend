# ISY1101-EP2 — Frontend Despachos

Frontend del sistema de gestión de despachos de **Innovatech Chile**, desarrollado como parte del proyecto semestral ISY1101 EP2. Permite visualizar y gestionar despachos y ventas en tiempo real, consumiendo dos microservicios backend independientes.

---

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| Framework UI | React 18 |
| Build tool | Vite |
| Lenguaje | JavaScript / JSX |
| Estilos | CSS / Tailwind (según config) |
| Servidor estático | Nginx Alpine |
| Contenedor | Docker (multi-stage) |
| CI/CD | GitHub Actions |
| Registry | Docker Hub |

---

## Requisitos previos

- Docker >= 24
- Node.js >= 20 (solo para desarrollo local sin Docker)

---

## Correr localmente con Docker

### Con Docker Compose (recomendado)

```bash
# Clonar el repositorio
git clone https://github.com/serobless/ISY1101-EP2-front-despacho.git
cd ISY1101-EP2-front-despacho

# Construir y levantar
docker compose up --build
```

El frontend quedará disponible en `http://localhost:80`.

### Sin Docker (desarrollo)

```bash
npm install
npm run dev
```

---

## Variables de entorno

Las variables se pasan como **build args** en tiempo de compilación porque Vite las embebe en el bundle JS estático. No son variables de runtime.

| Variable | Descripción | Ejemplo |
|---|---|---|
| `VITE_API_VENTAS_URL` | URL base del microservicio de ventas | `http://13.221.44.192:8080` |
| `VITE_API_DESPACHOS_URL` | URL base del microservicio de despachos | `http://54.164.16.35:8081` |

### En docker compose (local)

```yaml
build:
  args:
    VITE_API_VENTAS_URL: http://13.221.44.192:8080
    VITE_API_DESPACHOS_URL: http://54.164.16.35:8081
```

### En GitHub Actions (producción)

Configurar como secrets en el repositorio:
- `VITE_API_VENTAS_URL`
- `VITE_API_DESPACHOS_URL`

---

## Pipeline CI/CD

El workflow `.github/workflows/deploy.yml` se activa con cada push a la rama `deploy`.

```
push → deploy branch
        │
        ▼
  [build-and-push]
  ┌─────────────────────────────┐
  │ 1. Checkout código          │
  │ 2. Login a Docker Hub       │
  │ 3. docker build (con ARGs)  │
  │ 4. docker push → Docker Hub │
  └─────────────────────────────┘
        │
        ▼ (needs: build-and-push)
  [deploy]
  ┌─────────────────────────────┐
  │ 1. SSH a instancia EC2      │
  │ 2. docker pull              │
  │ 3. docker stop/rm anterior  │
  │ 4. docker run -p 80:80      │
  └─────────────────────────────┘
```

### Secrets requeridos en GitHub

| Secret | Descripción |
|---|---|
| `DOCKER_USERNAME` | Usuario de Docker Hub |
| `DOCKER_PASSWORD` | Token de acceso Docker Hub |
| `EC2_HOST` | IP pública de la instancia EC2 |
| `EC2_USER` | Usuario SSH (ej. `ec2-user`) |
| `EC2_SSH_KEY` | Clave privada SSH (contenido del `.pem`) |
| `VITE_API_VENTAS_URL` | URL del backend ventas |
| `VITE_API_DESPACHOS_URL` | URL del backend despachos |

---

## URL de producción

**http://35.175.207.34**

---

## Decisiones técnicas

### Multi-stage build

El Dockerfile usa dos stages: `builder` (Node 20 Alpine) compila el proyecto con Vite y genera el directorio `dist/`, y `runner` (Nginx Alpine) solo copia ese directorio estático. La imagen final no contiene Node.js, npm, ni código fuente — reduce el tamaño de imagen de ~400 MB a ~25 MB y elimina herramientas de desarrollo innecesarias en producción.

### Usuario no root

Nginx por defecto corre como root para bindear el puerto 80. Se crean los directorios temporales en `/tmp/nginx/` con `chown nginx:nginx` antes del `USER nginx`, permitiendo que el proceso corra sin privilegios. Esto sigue el principio de mínimo privilegio y es requisito en entornos con políticas de seguridad de contenedores (ej. Kubernetes PodSecurityPolicy).

### Named volumes vs bind mount

No aplica en este servicio: el frontend es estático y no tiene estado persistente. El contenido se embebe en la imagen durante el build.

### Docker Hub sobre ECR

Docker Hub fue elegido sobre Amazon ECR por simplicidad de configuración en GitHub Actions (un único secret `DOCKER_PASSWORD` vs. credenciales AWS + región + ARN) y porque las imágenes públicas no tienen costo de almacenamiento. ECR sería preferible en un entorno corporativo con VPC privada o políticas IAM estrictas.
