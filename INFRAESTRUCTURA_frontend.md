# Infraestructura AWS — Frontend (EP3)

Este documento registra los comandos AWS CLI ejecutados para aprovisionar la infraestructura del frontend en AWS ECS Fargate. Complementa el archivo equivalente del repositorio backend, donde está documentado el clúster, networking y Application Load Balancer compartidos.

> **Nota:** todos los comandos se ejecutaron desde AWS CloudShell en la región `us-east-1`, bajo la cuenta del AWS Academy Learner Lab.

---

## 1. Repositorio ECR

```bash
# Creado vía consola AWS (Amazon ECR → Crear repositorio privado)
# Nombre: ep3-frontend
# Mutabilidad: Mutable
# Cifrado: AES-256
```

URI resultante: `593376755101.dkr.ecr.us-east-1.amazonaws.com/ep3-frontend`

---

## 2. Security Group

```bash
aws ec2 create-security-group --group-name ep3-frontend-sg \
  --description "EP3 Frontend Security Group" --vpc-id vpc-05249474cb55efe84
# → sg-04d3232ded8fcdf76

aws ec2 authorize-security-group-ingress --group-id sg-04d3232ded8fcdf76 \
  --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id sg-04d3232ded8fcdf76 \
  --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id sg-04d3232ded8fcdf76 \
  --protocol tcp --port 8080 --cidr 0.0.0.0/0
```

> El puerto 8080 se agregó tras detectar que nginx, ejecutándose como usuario no-root dentro de Fargate, no puede hacer `bind` a puertos privilegiados (<1024) como el 80. Ver README, sección "Problemas resueltos".

---

## 3. Task Definition

Versión final (`ep3-frontend:4`), sirviendo en el puerto 8080:

```bash
aws ecs register-task-definition \
  --family ep3-frontend \
  --network-mode awsvpc \
  --requires-compatibilities FARGATE \
  --cpu 256 \
  --memory 512 \
  --execution-role-arn arn:aws:iam::593376755101:role/LabRole \
  --task-role-arn arn:aws:iam::593376755101:role/LabRole \
  --container-definitions '[{
    "name": "frontend",
    "image": "593376755101.dkr.ecr.us-east-1.amazonaws.com/ep3-frontend:latest",
    "portMappings": [{"containerPort": 8080, "protocol": "tcp"}],
    "essential": true,
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/ep3-frontend",
        "awslogs-region": "us-east-1",
        "awslogs-stream-prefix": "ecs",
        "awslogs-create-group": "true"
      }
    }
  }]'
```

---

## 4. Servicio ECS

```bash
aws ecs create-service \
  --cluster ep3-cluster \
  --service-name ep3-frontend-service \
  --task-definition ep3-frontend:4 \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-0f5c1a809cced7b33,subnet-01ed48dca89140505],securityGroups=[sg-04d3232ded8fcdf76],assignPublicIp=ENABLED}"
```

---

## 5. Auto Scaling (Target Tracking)

```bash
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/ep3-cluster/ep3-frontend-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 1 --max-capacity 3

aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/ep3-cluster/ep3-frontend-service \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name ep3-frontend-cpu-scaling \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 50.0,
    "PredefinedMetricSpecification": {"PredefinedMetricType": "ECSServiceAverageCPUUtilization"},
    "ScaleInCooldown": 60,
    "ScaleOutCooldown": 60
  }'
```

---

## 6. Obtener la IP pública de la tarea (cambia en cada redeploy)

```bash
TASK_ARN=$(aws ecs list-tasks --cluster ep3-cluster --service-name ep3-frontend-service --query 'taskArns[0]' --output text)
ENI_ID=$(aws ecs describe-tasks --cluster ep3-cluster --tasks $TASK_ARN --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --query 'NetworkInterfaces[0].Association.PublicIp' --output text
```

Acceso resultante: `http://[IP-PUBLICA]:8080`

> Ver el repositorio `ISY1101-EP3-backend` para la documentación del clúster ECS, networking base y Application Load Balancer, compartidos entre ambos servicios.
