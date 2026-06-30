# ISY1101 EP3 - Frontend (Orquestación ECS)

## Descripción
Frontend React + Vite desplegado en AWS ECS Fargate como parte de la Evaluación Parcial N°3 de Introducción a Herramientas DevOps (ISY1101). Aplicación web "Despacho Dashboard" para gestión de órdenes de compra y despacho de Innovatech Chile.

## Arquitectura de despliegue

- **Servidor web**: Nginx (imagen `nginx:alpine`), corriendo como usuario no-root en el puerto **8080** (no 80, ya que el usuario `nginx` sin privilegios no puede hacer bind a puertos privilegiados <1024 en Fargate)
- **Build multi-stage**: stage 1 compila el bundle con Node 20, stage 2 sirve el build estático con nginx
- **Variables de entorno de build**: `VITE_API_VENTAS_URL` y `VITE_API_DESPACHOS_URL`, inyectadas como `--build-arg` en GitHub Actions, apuntando a la URL del Application Load Balancer del backend

## Componentes AWS utilizados
- **Amazon ECS (Fargate)**: orquestación de contenedores
- **Amazon ECR**: registro de imágenes Docker (`ep3-frontend`)
- **Application Auto Scaling**: Target Tracking sobre CPU (umbral 20%, min 1 - max 3 tareas)
- **CloudWatch Logs**: grupo `/ecs/ep3-frontend`

## Pipeline CI/CD (GitHub Actions)
Workflow `.github/workflows/deploy.yml`, disparado en cada push a `main`:
1. Checkout del código
2. Configuración de credenciales AWS (vía GitHub Secrets)
3. Login a Amazon ECR
4. Build de la imagen Docker con build-args de URLs del backend, push a ECR (tag `latest` y tag del commit SHA)
5. Descarga y actualización de la Task Definition con la nueva imagen
6. Deploy al servicio ECS con espera de estabilidad

## Cómo correr el proyecto localmente
```bash
npm install
npm run dev
```

## Problemas resueltos durante la implementación
1. **`bind() to 0.0.0.0:80 failed (Permission denied)`**: nginx como usuario no-root no puede escuchar en puertos <1024 dentro de Fargate. Se cambió la configuración (`nginx.conf` y `Dockerfile`) para escuchar en el puerto 8080.
2. **Conexión con el backend**: en el EP2 el frontend apuntaba a IPs fijas de instancias EC2. En el EP3 se reemplazó por la URL estable del Application Load Balancer del backend, inyectada en tiempo de build vía `--build-arg`, evitando depender de IPs de tareas Fargate que cambian en cada redeploy.
