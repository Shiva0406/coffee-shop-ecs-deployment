# Coffee Shop - Amazon ECS Fargate Deployment

AWS architecture we'll build
I'll use ECS Fargate + Application Load Balancer + Amazon RDS MySQL. RDS is a better choice than running MySQL as a temporary ECS container because your orders and products need persistent database storage.

<img width="800" height="553" alt="Screenshot 2026-11-17 193211" src="https://github.com/user-attachments/assets/a427e84e-87df-4c16-8133-94213c93ba08" />



Deployment flow: Docker Hub → ECS Fargate → Load Balancer → Browser, with the backend connected privately to RDS.


Deploy the existing React + FastAPI + MySQL Coffee Shop application to AWS ECS Fargate.

## Architecture

- **Application Load Balancer (ALB):** public entry point.
- **ECS Fargate frontend:** React served by Nginx.
- **ECS Fargate backend:** FastAPI.
- **Amazon RDS MySQL:** persistent database, not publicly accessible.
- **Secrets Manager:** generated database password.
- **CloudWatch Logs:** container logs.
- **CloudFormation:** creates the AWS resources.

The ALB sends `/api` and `/api/*` requests to FastAPI. Other requests go to the frontend. The frontend must call relative URLs such as `/api/products`, not `localhost`.

## Folder structure

```text
ecs-deployment/
├── cloudformation/
│   └── ecs-stack.yaml
├── scripts/
│   ├── deploy.sh
│   └── destroy.sh
└── README.md
```

## Prerequisites

1. AWS CLI v2 installed and configured: `aws configure`.
2. IAM identity allowed to create VPC security groups, ECS, IAM roles, ALB, RDS, Secrets Manager, CloudWatch, and CloudFormation resources.
3. A default VPC with two subnets in different Availability Zones in the selected region.
4. Public Docker Hub images:
   - `shiva029/coffee-shop-frontend:v2`
   - `shiva029/coffee-shop-backend:v2`
5. Backend image must include `cryptography` in `requirements.txt`.
6. Backend health endpoint must return HTTP 200 at `/api/health`.
7. Backend must read `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_DB`, `MYSQL_USER`, and `MYSQL_PASSWORD`.

## Step 1 - Verify AWS CLI

```bash
aws --version
aws sts get-caller-identity
```

## Step 2 - Verify images

```bash
docker pull shiva029/coffee-shop-frontend:v2
docker pull shiva029/coffee-shop-backend:v2
```

The Docker Hub repositories must be public for this simple setup.

## Step 3 - Deploy

Run from this `ecs-deployment` directory:

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

Default region is `ap-south-1`. To change region or image tag:

```bash
AWS_REGION=ap-south-1 DOCKERHUB_USERNAME=shiva029 IMAGE_TAG=v2 ./scripts/deploy.sh
```

The script finds the default VPC and two public subnets in different Availability Zones, then deploys the CloudFormation stack. Provisioning may take 10-20 minutes, mainly because of RDS and the load balancer.

## Step 4 - Open the application

The script prints the ALB URL, for example:

```text
http://coffee-shop-alb-xxxxxxxx.ap-south-1.elb.amazonaws.com
```

Open it in your browser.

## Step 5 - Verify services and logs

```bash
aws ecs list-services --cluster coffee-shop-cluster --region ap-south-1

aws logs tail /ecs/coffee-shop/backend --since 15m --follow --region ap-south-1
```

In another terminal:

```bash
aws logs tail /ecs/coffee-shop/frontend --since 15m --follow --region ap-south-1
```

AWS Console locations:
- ECS → Clusters → `coffee-shop-cluster`
- EC2 → Load Balancers → `coffee-shop-alb`
- RDS → Databases
- CloudWatch → Log groups

## Networking

- Internet users reach the ALB on HTTP port 80.
- ECS task ports 80 and 8000 accept traffic only from the ALB security group.
- RDS accepts MySQL port 3306 only from the ECS task security group.
- RDS has `PubliclyAccessible: false`.
- ECS tasks run in public subnets with public IPs so they can pull public Docker Hub images and send CloudWatch logs without a NAT Gateway. Their inbound application ports are still restricted by security groups.

For production, use HTTPS with ACM, private ECS subnets with NAT or VPC endpoints, backups, and tighter access controls.

## Cost warning

ALB, Fargate tasks, RDS, storage, public IPv4, CloudWatch logs, and data transfer can incur charges. This is not guaranteed to be free tier. Check AWS pricing for your region. Delete the stack when finished.

## Delete everything

**This deletes the RDS database and its data. Export anything important first.**

```bash
./scripts/destroy.sh
```

Type `DELETE` when prompted.

## Troubleshooting

- **ECS task stops:** inspect ECS service Events and CloudWatch backend logs.
- **Backend cannot connect to MySQL:** check RDS status, security groups, and DB environment variables.
- **ALB returns 502/503:** check ECS task status and target group health.
- **API fails:** browser Developer Tools → Network; confirm requests go to `http://<ALB-DNS>/api/...`.
- **Image pull fails:** confirm Docker Hub repositories are public and image tags exist.

Happy learning! ☕
