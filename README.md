# DevOps Challenge - CI/CD + Docker + AWS

Pipeline CI/CD automatizado con **GitHub Actions**, **Docker**, **ECR** y **AWS** (EC2, Auto Scaling, ALB).

## Arquitectura

```
GitHub Push (main)
       ↓
GitHub Actions Pipeline
  ├─ Build & Test
  ├─ Build Docker Image
  ├─ Push to ECR
  └─ Deploy to Auto Scaling Group
       ↓
AWS Infrastructure
  ├─ ECR (Docker Registry)
  ├─ Application Load Balancer
  ├─ Auto Scaling Group (1-4 instances)
  └─ CloudWatch (Logs + Metrics)
```

## Estructura del Proyecto

```
devops-challenge/
├── app/                     # Aplicación Node.js
│   ├── server.js
│   ├── package.json
│   └── test/
├── docker/
│   └── Dockerfile           # Multi-stage build
├── terraform/               # Infrastructure as Code
│   ├── main.tf              # VPC, networking
│   ├── app.tf               # ECR, ALB, ASG
│   ├── variables.tf
│   ├── outputs.tf
│   └── user_data.sh
├── .github/workflows/
│   └── ci-cd.yaml           # GitHub Actions
└── scripts/
    ├── deploy.sh
    └── cleanup.sh
```

## Quick Start

### 1. Ejecutar Local

```bash
cd app
npm install
npm test
npm start

# Probar endpoints
curl http://localhost:3000/health
curl http://localhost:3000/metrics
```

### 2. Build Docker Local

```bash
docker build -f docker/Dockerfile -t devops-challenge:local .
docker run -p 3000:3000 devops-challenge:local
curl http://localhost:3000/health
```

### 3. Deploy Infraestructura

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars

terraform init
terraform plan
terraform apply
```

### 4. Configurar GitHub Actions

Agregar estos secrets en GitHub (Settings → Secrets):

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## Endpoints

| Endpoint   | Descripción           |
|------------|-----------------------|
| `/`        | Info de la API        |
| `/health`  | Health check          |
| `/metrics` | Métricas del sistema  |

## Pipeline CI/CD

El pipeline se ejecuta en cada push a `main`:

1. **Build and Test**: Instala dependencias, ejecuta tests, construye imagen Docker
2. **Push to ECR**: Sube la imagen a Amazon ECR
3. **Deploy**: Inicia instance refresh en el Auto Scaling Group

## Comandos Útiles

```bash
# Ver logs
aws logs tail /aws/ec2/devops-challenge --follow

# Ver instancias
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*devops-challenge*" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]'

# Ver URL de la aplicación
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName,'devops-challenge')].DNSName" \
  --output text

# Destruir infraestructura
cd terraform && terraform destroy
```

## Seguridad

- Non-root user en Docker
- Secrets en GitHub Actions (no hardcodeados)
- IAM roles con permisos mínimos
- Security groups restrictivos
- IMDS v2 en EC2

## Autor

jgomez - DevOps Challenge
