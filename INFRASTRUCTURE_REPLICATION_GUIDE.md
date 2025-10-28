# Infrastructure as Code Replication Guide

> **Purpose**: This document provides a complete blueprint for replicating the Terraform infrastructure setup used in this project. It's designed to be copied and applied to other projects with minimal adaptation.

---

## Table of Contents

1. [Overview & Philosophy](#overview--philosophy)
2. [Directory Structure](#directory-structure)
3. [Terraform State Management](#terraform-state-management)
4. [Module Pattern](#module-pattern)
5. [Stack Pattern](#stack-pattern)
6. [Stack Configurations Deep Dive](#stack-configurations-deep-dive)
7. [Standard File Patterns](#standard-file-patterns)
8. [Tagging Strategy](#tagging-strategy)
9. [Security & IAM Approach](#security--iam-approach)
10. [Deployment Order & Dependencies](#deployment-order--dependencies)
11. [Adapting for Your Project](#adapting-for-your-project)

---

## Overview & Philosophy

### Core Principles

1. **Stack-Based Architecture**: Infrastructure is decomposed into independent, loosely-coupled stacks that can be planned and applied separately
2. **State Isolation**: Each stack maintains its own state file in S3, preventing blast radius and enabling parallel development
3. **Remote State Data Sharing**: Stacks communicate via `terraform_remote_state` data sources, creating clear dependency chains
4. **Module Reusability**: Common patterns are extracted into modules for consistency and DRY principles
5. **Environment Parity**: Each environment (dev/staging/prod) uses the same stack structure with environment-specific variables
6. **Security by Default**: Private subnets, encrypted storage, TLS enforcement, and least-privilege IAM from day one

### Technology Stack

- **Terraform**: `>= 1.13.0` for native S3 state locking
- **AWS Provider**: `~> 5.50`
- **Region**: `ap-southeast-2` (configurable per environment)
- **State Backend**: S3 with native locking (no DynamoDB required)
- **Compute**: ECS Fargate (primary), EC2 (optional)
- **Database**: RDS PostgreSQL
- **Storage**: S3
- **Container Registry**: ECR
- **Load Balancing**: Application Load Balancer with ACM certificates
- **DNS**: Route53
- **CI/CD**: CodePipeline + CodeBuild
- **Secrets**: AWS Secrets Manager + SSM Parameter Store

---

## Directory Structure

```
infrastructure/
└── terraform/
    ├── modules/                       # Reusable infrastructure components
    │   ├── state_bucket/             # S3 bucket for Terraform state
    │   │   ├── main.tf
    │   │   ├── outputs.tf
    │   │   ├── variables.tf
    │   │   └── README.md
    │   └── ecr-repository/           # ECR repository module
    │       ├── main.tf
    │       ├── outputs.tf
    │       ├── variables.tf
    │       └── README.md
    ├── state-bootstrap/              # Bootstrap state bucket (local state only)
    │   ├── backend.tf
    │   ├── main.tf
    │   ├── providers.tf
    │   └── variables.tf
    └── stacks/                       # Environment-specific stacks
        └── development/              # Environment name (dev, staging, prod)
            ├── README.md             # Stack documentation
            ├── core-networking/      # Network foundation
            │   ├── backend.tf
            │   ├── providers.tf
            │   ├── locals.tf
            │   ├── variables.tf
            │   └── networking.tf
            ├── security/             # IAM roles & secrets
            │   ├── backend.tf
            │   ├── providers.tf
            │   ├── locals.tf
            │   ├── variables.tf
            │   ├── main.tf
            │   └── remote_state.tf
            ├── storage/              # S3 buckets
            ├── container-registry/   # ECR repositories
            ├── database/             # RDS instances
            ├── compute-ecs-cluster/  # ECS cluster
            ├── compute-ecs-alb/      # Application Load Balancer
            ├── compute-ecs-demo-app/ # ECS service definition
            ├── route53-records/      # DNS records
            ├── cicd/                 # CodePipeline
            └── observability/        # CloudWatch logs/alarms
```

### Key Directories Explained

- **`modules/`**: Self-contained, reusable Terraform modules with their own variables, outputs, and documentation
- **`state-bootstrap/`**: Special directory that creates the shared S3 state bucket; uses local state (never migrated to S3)
- **`stacks/<environment>/`**: Environment-specific deployments; each subdirectory is an independently deployable unit with its own state key

---

## Terraform State Management

### The Bootstrap Process

**Step 1: Create the State Bucket** (One-time setup)

```bash
cd infrastructure/terraform/state-bootstrap
terraform init
terraform apply
```

This creates an S3 bucket with:
- Versioning enabled
- Server-side encryption (AES256)
- Public access blocked
- Lifecycle policies for old versions

**State Bucket Module** (`modules/state_bucket/main.tf`):

```hcl
resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  count                   = var.block_public_access ? 1 : 0
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

**Step 2: Migrate Stacks to Remote State**

After the state bucket exists, each stack is initialized with:

```bash
cd infrastructure/terraform/stacks/development/core-networking
terraform init -migrate-state
```

### Backend Configuration Pattern

**Every stack** (except `state-bootstrap`) uses this `backend.tf` pattern:

```hcl
terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }

  backend "s3" {
    bucket       = "YOUR-PROJECT-terraform-state"  # Change per project
    key          = "development/STACK-NAME.tfstate" # Change per stack
    region       = "ap-southeast-2"
    profile      = "your-aws-profile"               # Change per AWS account
    encrypt      = true
    use_lockfile = true  # Native S3 locking (Terraform >= 1.13)
  }
}
```

**Key Points**:
- `use_lockfile = true` enables native S3 state locking without DynamoDB
- Each stack has a unique `key` like `development/core-networking.tfstate`
- Bucket name convention: `<project-name>-terraform-state`
- State objects are encrypted at rest

### State Locking

- Terraform 1.13+ uses `.tflock` objects in S3 for locking
- No DynamoDB table required
- If a process crashes, manually delete the `.tflock` object from S3 to release the lock

---

## Module Pattern

### Module Structure

Each module follows this structure:

```
modules/example-module/
├── main.tf       # Primary resource definitions
├── variables.tf  # Input variables
├── outputs.tf    # Exported values
└── README.md     # Usage documentation
```

### Example: ECR Repository Module

**`modules/ecr-repository/main.tf`**:

```hcl
resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.encryption_type == "KMS" ? var.kms_key_arn : null
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Retain last ${var.lifecycle_keep_count} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.lifecycle_keep_count
      }
      action = { type = "expire" }
    }]
  })
}
```

**`modules/ecr-repository/variables.tf`**:

```hcl
variable "name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "image_tag_mutability" {
  description = "Image tag mutability setting (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Encryption type (AES256 or KMS)"
  type        = string
  default     = "AES256"
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption (only if encryption_type = KMS)"
  type        = string
  default     = null
}

variable "lifecycle_keep_count" {
  description = "Number of images to retain"
  type        = number
  default     = 10
}
```

**`modules/ecr-repository/outputs.tf`**:

```hcl
output "repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.this.name
}
```

### Module Usage Pattern

In a stack (e.g., `container-registry/main.tf`):

```hcl
module "app_ecr" {
  source = "../../../modules/ecr-repository"

  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"
  lifecycle_keep_count = 15
}

output "ecr_repository_url" {
  value = module.app_ecr.repository_url
}

output "ecr_repository_name" {
  value = module.app_ecr.repository_name
}
```

---

## Stack Pattern

### What is a Stack?

A **stack** is:
- An independently deployable unit of infrastructure
- Has its own state file in S3
- Can depend on other stacks via `terraform_remote_state`
- Scoped to a single environment (dev/staging/prod)

### Standard Stack Structure

Every stack contains these files:

```
stack-name/
├── backend.tf       # S3 backend configuration
├── providers.tf     # AWS provider with default tags
├── locals.tf        # Local variables and computed values
├── variables.tf     # Input variables
├── main.tf          # Primary resource definitions
├── remote_state.tf  # Dependencies on other stacks (if any)
└── outputs.tf       # Values exported for downstream stacks
```

### Stack Dependencies via Remote State

**Pattern**: Stacks read outputs from other stacks using `terraform_remote_state`.

**Example** (`compute-ecs-demo-app/remote_state.tf`):

```hcl
data "terraform_remote_state" "core_networking" {
  backend = "s3"
  config = {
    bucket  = "aws-lab-java-terraform-state"
    key     = "development/core-networking.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

data "terraform_remote_state" "ecs_cluster" {
  backend = "s3"
  config = {
    bucket  = "aws-lab-java-terraform-state"
    key     = "development/compute-ecs-cluster.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket  = "aws-lab-java-terraform-state"
    key     = "development/security.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}
```

**Usage in `main.tf`**:

```hcl
resource "aws_ecs_service" "app" {
  cluster         = data.terraform_remote_state.ecs_cluster.outputs.cluster_id
  task_definition = aws_ecs_task_definition.app.arn
  
  network_configuration {
    security_groups = [data.terraform_remote_state.core_networking.outputs.security_group_ids.ecs]
    subnets         = keys(data.terraform_remote_state.core_networking.outputs.private_subnets)
  }
}
```

**Key Benefits**:
- Clear dependency graph
- Type-safe data sharing between stacks
- Independent planning and applying
- Prevents circular dependencies

---

## Stack Configurations Deep Dive

### 1. Core Networking Stack

**Purpose**: Foundation for all network resources

**Responsibilities**:
- Data source lookups for existing VPC/subnets
- Security group definitions (ALB, ECS, EC2, database, bastion)
- VPC endpoint references (S3, ECR, SSM, CloudWatch, Secrets Manager)
- Outputs network metadata for downstream stacks

**Key Resources** (`core-networking/networking.tf`):

```hcl
# VPC lookup (existing VPC)
data "aws_vpc" "shared" {
  id = var.vpc_id
}

# Subnet lookups
data "aws_subnet" "public" {
  for_each = toset(var.public_subnet_ids)
  id       = each.value
}

data "aws_subnet" "private" {
  for_each = toset(var.private_subnet_ids)
  id       = each.value
}

# Security groups
resource "aws_security_group" "alb" {
  name        = "${local.sg_name_prefix}-alb"
  description = "Ingress security group for the application load balancers"
  vpc_id      = data.aws_vpc.shared.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_service" {
  name        = "${local.sg_name_prefix}-ecs"
  description = "Security group for ECS application tasks"
  vpc_id      = data.aws_vpc.shared.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "database" {
  name        = "${local.sg_name_prefix}-database"
  description = "Security group for the shared PostgreSQL database"
  vpc_id      = data.aws_vpc.shared.id
}

# Security group rules
resource "aws_security_group_rule" "alb_https_ingress" {
  description       = "Allow HTTPS"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "ecs_from_alb" {
  description              = "Allow ALB to reach ECS tasks"
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs_service.id
}

resource "aws_security_group_rule" "database_from_ecs" {
  description              = "Allow ECS tasks to reach PostgreSQL"
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_service.id
  security_group_id        = aws_security_group.database.id
}
```

**Outputs** (`core-networking/networking.tf`):

```hcl
output "security_group_ids" {
  description = "Map of shared security groups for downstream stacks"
  value = {
    alb      = aws_security_group.alb.id
    ecs      = aws_security_group.ecs_service.id
    ec2      = aws_security_group.ec2_service.id
    database = aws_security_group.database.id
    bastion  = aws_security_group.bastion.id
  }
}

output "vpc_id" {
  description = "VPC identifier reused by the environment"
  value       = data.aws_vpc.shared.id
}

output "public_subnets" {
  description = "Public subnet IDs with AZ metadata"
  value = {
    for id, subnet in data.aws_subnet.public : id => {
      availability_zone = subnet.availability_zone
      cidr_block        = subnet.cidr_block
    }
  }
}

output "private_subnets" {
  description = "Private subnet IDs with AZ metadata"
  value = {
    for id, subnet in data.aws_subnet.private : id => {
      availability_zone = subnet.availability_zone
      cidr_block        = subnet.cidr_block
    }
  }
}
```

**Variables** (`core-networking/variables.tf`):

```hcl
variable "vpc_id" {
  description = "Pre-provisioned VPC ID reused by the environment"
  type        = string
  default     = "vpc-xxxxx"  # Replace with your VPC
}

variable "public_subnet_ids" {
  description = "Pre-provisioned public subnet IDs"
  type        = list(string)
  default     = ["subnet-xxxxx", "subnet-yyyyy"]
}

variable "private_subnet_ids" {
  description = "Pre-provisioned private subnet IDs"
  type        = list(string)
  default     = ["subnet-zzzzz", "subnet-aaaaa"]
}
```

---

### 2. Security Stack

**Purpose**: IAM roles, secrets, and parameters

**Responsibilities**:
- ECS task execution role (pulls images, reads secrets)
- ECS task role (application runtime permissions)
- EC2 instance role and profile
- Application auth tokens (Secrets Manager + SSM)
- Least-privilege IAM policies

**Key Resources** (`security/main.tf`):

```hcl
# Generate application auth token
resource "random_password" "auth_token" {
  length           = 32
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!#$%&*+-=?@^_"
}

# Store in Secrets Manager
resource "aws_secretsmanager_secret" "app_auth_token" {
  name        = "aws-lab-java/${var.environment}/app-auth-token"
  description = "Application auth token"
}

resource "aws_secretsmanager_secret_version" "app_auth_token" {
  secret_id     = aws_secretsmanager_secret.app_auth_token.id
  secret_string = random_password.auth_token.result
}

# Store in SSM Parameter Store
resource "aws_ssm_parameter" "app_auth_token" {
  name        = "/app/aws-lab-java/${var.environment}/DEMO_AUTH_TOKEN"
  type        = "SecureString"
  value       = random_password.auth_token.result
  description = "Application auth token"
}

# ECS Task Execution Role (for ECS agent)
data "aws_iam_policy_document" "ecs_task_execution_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "aws-lab-java-${var.environment}-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume.json
}

# Policy for reading secrets and parameters
data "aws_iam_policy_document" "ecs_task_execution" {
  statement {
    sid    = "ReadParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/app/aws-lab-java/${var.environment}/*"
    ]
  }

  statement {
    sid    = "ReadSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:aws-lab-java/${var.environment}*"
    ]
  }
}

resource "aws_iam_role_policy" "ecs_task_execution" {
  name   = "ecs-task-execution-secrets"
  role   = aws_iam_role.ecs_task_execution.id
  policy = data.aws_iam_policy_document.ecs_task_execution.json
}

# Attach AWS managed policy for ECR and CloudWatch Logs
resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role (for application runtime)
data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs_task" {
  name               = "aws-lab-java-${var.environment}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

# Application permissions (S3, secrets, etc.)
data "aws_iam_policy_document" "ecs_task" {
  statement {
    sid    = "S3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      data.terraform_remote_state.storage.outputs.widget_metadata_bucket_arn,
      "${data.terraform_remote_state.storage.outputs.widget_metadata_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "ReadParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/app/aws-lab-java/${var.environment}/*"
    ]
  }
}

resource "aws_iam_role_policy" "ecs_task" {
  name   = "ecs-task-app"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task.json
}

# EC2 Instance Role
resource "aws_iam_role" "ec2_service" {
  name               = "aws-lab-java-${var.environment}-ec2-service"
  assume_role_policy = data.aws_iam_policy_document.ec2_instance_assume.json
}

# Attach SSM managed policy for Session Manager
resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2_service.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile for EC2
resource "aws_iam_instance_profile" "ec2_service" {
  name = "aws-lab-java-${var.environment}-ec2-service"
  role = aws_iam_role.ec2_service.name
}
```

**Outputs** (`security/main.tf`):

```hcl
output "ecs_task_execution_role_arn" {
  description = "IAM role ARN used by ECS task execution"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "IAM role ARN assigned to the ECS task definition"
  value       = aws_iam_role.ecs_task.arn
}

output "ec2_instance_profile_name" {
  description = "Instance profile name for EC2 workloads"
  value       = aws_iam_instance_profile.ec2_service.name
}

output "app_auth_token_parameter_name" {
  description = "SSM parameter name containing the auth token"
  value       = aws_ssm_parameter.app_auth_token.name
}
```

---

### 3. Storage Stack

**Purpose**: S3 buckets for application data

**Key Resources** (`storage/main.tf`):

```hcl
resource "aws_s3_bucket" "app_data" {
  bucket        = "your-project-${var.environment}-app-data"
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket                  = aws_s3_bucket.app_data.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enforce TLS-only access
data "aws_iam_policy_document" "app_data_tls" {
  statement {
    sid    = "EnforceTLS"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [
      aws_s3_bucket.app_data.arn,
      "${aws_s3_bucket.app_data.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  policy = data.aws_iam_policy_document.app_data_tls.json
}
```

---

### 4. Container Registry Stack

**Purpose**: ECR repositories for Docker images

**Key Resources** (`container-registry/main.tf`):

```hcl
module "app_ecr" {
  source = "../../../modules/ecr-repository"

  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"
  lifecycle_keep_count = 15
}

output "ecr_repository_url" {
  value = module.app_ecr.repository_url
}

output "ecr_repository_name" {
  value = module.app_ecr.repository_name
}

output "ecr_repository_arn" {
  value = module.app_ecr.repository_arn
}
```

---

### 5. Database Stack

**Purpose**: RDS PostgreSQL database

**Key Resources** (`database/main.tf`):

```hcl
# Generate database password
resource "random_password" "db_master" {
  length           = 20
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!#$%&*+-=?@^_"
}

# Subnet group
resource "aws_db_subnet_group" "postgres" {
  name        = "${local.name_prefix}-db-subnets"
  description = "Private subnets for the PostgreSQL instance"
  subnet_ids  = local.private_subnet_ids
}

# Parameter group
resource "aws_db_parameter_group" "postgres" {
  name   = "${local.name_prefix}-postgres"
  family = "postgres15"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }
}

# RDS instance
resource "aws_db_instance" "postgres" {
  identifier                            = "${local.name_prefix}-postgres"
  engine                                = "postgres"
  engine_version                        = "15.4"
  instance_class                        = "db.t4g.micro"
  allocated_storage                     = 20
  max_allocated_storage                 = 100
  storage_type                          = "gp3"
  db_name                               = "appdb"
  username                              = "dbadmin"
  password                              = random_password.db_master.result
  port                                  = 5432
  db_subnet_group_name                  = aws_db_subnet_group.postgres.name
  vpc_security_group_ids                = [local.database_security_group_id]
  parameter_group_name                  = aws_db_parameter_group.postgres.name
  publicly_accessible                   = false
  storage_encrypted                     = true
  backup_retention_period               = 7
  copy_tags_to_snapshot                 = true
  auto_minor_version_upgrade            = true
  multi_az                              = false  # Enable for prod
  deletion_protection                   = false  # Enable for prod
  skip_final_snapshot                   = true   # Change for prod
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
}

# Store credentials in Secrets Manager
resource "aws_secretsmanager_secret" "database_credentials" {
  name        = "aws-lab-java/${var.environment}/database/postgresql"
  description = "Database credentials for PostgreSQL instance"
}

resource "aws_secretsmanager_secret_version" "database_credentials" {
  secret_id = aws_secretsmanager_secret.database_credentials.id
  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.postgres.address
    port     = 5432
    dbname   = "appdb"
    username = "dbadmin"
    password = random_password.db_master.result
  })
}

# Store connection strings in SSM Parameter Store
resource "aws_ssm_parameter" "datasource_url" {
  name  = "/app/aws-lab-java/${var.environment}/DATABASE_URL"
  type  = "String"
  value = "postgresql://${aws_db_instance.postgres.address}:5432/appdb"
}

resource "aws_ssm_parameter" "datasource_username" {
  name  = "/app/aws-lab-java/${var.environment}/DATABASE_USERNAME"
  type  = "String"
  value = "dbadmin"
}

resource "aws_ssm_parameter" "datasource_password" {
  name  = "/app/aws-lab-java/${var.environment}/DATABASE_PASSWORD"
  type  = "SecureString"
  value = random_password.db_master.result
}
```

---

### 6. Compute ECS Cluster Stack

**Purpose**: Shared ECS cluster for Fargate services

**Key Resources** (`compute-ecs-cluster/main.tf`):

```hcl
resource "aws_ecs_cluster" "this" {
  name = "aws-lab-java-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      logging = "DEFAULT"
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

output "cluster_id" {
  value = aws_ecs_cluster.this.id
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}
```

---

### 7. Compute ECS ALB Stack

**Purpose**: Application Load Balancer for ECS services

**Key Resources** (`compute-ecs-alb/main.tf`):

```hcl
# Route53 zone lookup
data "aws_route53_zone" "primary" {
  name         = "your-domain.com"
  private_zone = false
}

# ACM certificate
resource "aws_acm_certificate" "ecs" {
  domain_name       = "app.your-domain.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation records
resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for option in aws_acm_certificate.ecs.domain_validation_options :
    option.domain_name => {
      name  = option.resource_record_name
      type  = option.resource_record_type
      value = option.resource_record_value
    }
  }

  zone_id         = data.aws_route53_zone.primary.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.value]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "ecs" {
  certificate_arn         = aws_acm_certificate.ecs.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
}

# Application Load Balancer
resource "aws_lb" "ecs" {
  name               = "your-project-${var.environment}-ecs"
  load_balancer_type = "application"
  security_groups    = [data.terraform_remote_state.core_networking.outputs.security_group_ids.alb]
  subnets            = keys(data.terraform_remote_state.core_networking.outputs.public_subnets)
  idle_timeout       = 60
}

# HTTP listener (redirect to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ecs.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      status_code = "HTTP_301"
      protocol    = "HTTPS"
      port        = "443"
    }
  }
}

# HTTPS listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.ecs.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.ecs.arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not configured"
      status_code  = "404"
    }
  }

  depends_on = [aws_acm_certificate_validation.ecs]
}

output "alb_arn" {
  value = aws_lb.ecs.arn
}

output "alb_dns_name" {
  value = aws_lb.ecs.dns_name
}

output "alb_https_listener_arn" {
  value = aws_lb_listener.https.arn
}
```

---

### 8. Compute ECS Service Stack

**Purpose**: ECS Fargate service definition for your application

**Key Resources** (`compute-ecs-demo-app/main.tf`):

```hcl
locals {
  service_name       = "your-project-${var.environment}-service"
  container_name     = "your-app"
  container_port     = 3000  # Change for NestJS
  log_group_name     = "/aws/ecs/${local.service_name}"
  ecr_repository_url = data.terraform_remote_state.container_registry.outputs.ecr_repository_url
}

# CloudWatch log group
resource "aws_cloudwatch_log_group" "service" {
  name              = local.log_group_name
  retention_in_days = 30
}

# Target group
resource "aws_lb_target_group" "service" {
  name        = "your-project-${var.environment}-tg"
  port        = local.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.terraform_remote_state.core_networking.outputs.vpc_id

  health_check {
    path                = "/health"  # Change for your app
    matcher             = "200-299"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }
}

# Listener rule
resource "aws_lb_listener_rule" "service" {
  listener_arn = data.terraform_remote_state.ecs_alb.outputs.alb_https_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

# Task definition
resource "aws_ecs_task_definition" "app" {
  family                   = "your-project-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = data.terraform_remote_state.security.outputs.ecs_task_execution_role_arn
  task_role_arn            = data.terraform_remote_state.security.outputs.ecs_task_role_arn

  container_definitions = jsonencode([{
    name      = local.container_name
    image     = "${local.ecr_repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = local.container_port
      hostPort      = local.container_port
      protocol      = "tcp"
    }]
    environment = [
      { name = "NODE_ENV", value = var.environment },
      { name = "PORT", value = tostring(local.container_port) }
    ]
    secrets = [
      {
        name      = "DATABASE_URL"
        valueFrom = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/app/your-project/${var.environment}/DATABASE_URL"
      }
    ]
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${local.container_port}/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.service.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# ECS service
resource "aws_ecs_service" "app" {
  name                               = local.service_name
  cluster                            = data.terraform_remote_state.ecs_cluster.outputs.cluster_id
  task_definition                    = aws_ecs_task_definition.app.arn
  desired_count                      = 1
  launch_type                        = "FARGATE"
  enable_execute_command             = true
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60

  network_configuration {
    assign_public_ip = false
    security_groups  = [data.terraform_remote_state.core_networking.outputs.security_group_ids.ecs]
    subnets          = keys(data.terraform_remote_state.core_networking.outputs.private_subnets)
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.service.arn
    container_name   = local.container_name
    container_port   = local.container_port
  }

  depends_on = [aws_lb_listener_rule.service]
}
```

---

### 9. Route53 Records Stack

**Purpose**: DNS records pointing to load balancers

**Key Resources** (`route53-records/main.tf`):

```hcl
data "aws_route53_zone" "primary" {
  name         = var.zone_name
  private_zone = false
}

resource "aws_route53_record" "ecs_service" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "app.your-domain.com"
  type    = "A"

  alias {
    name                   = data.terraform_remote_state.ecs_alb.outputs.alb_dns_name
    zone_id                = data.aws_lb.ecs.zone_id
    evaluate_target_health = true
  }
}
```

---

### 10. CI/CD Stack

**Purpose**: CodePipeline and CodeBuild for automated deployments

**Key Resources** (`cicd/main.tf`):

```hcl
# Artifact bucket
resource "aws_s3_bucket" "artifacts" {
  bucket = "your-project-${var.environment}-cicd-artifacts-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# CodeBuild IAM role
resource "aws_iam_role" "codebuild" {
  name = "your-project-${var.environment}-codebuild"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# CodeBuild permissions
resource "aws_iam_role_policy" "codebuild" {
  role = aws_iam_role.codebuild.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLogging"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        Sid      = "AllowEcrAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "AllowEcrPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = data.terraform_remote_state.container_registry.outputs.ecr_repository_arn
      }
    ]
  })
}

# CodeBuild project
resource "aws_codebuild_project" "image_builder" {
  name          = "your-project-${var.environment}-build"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 30

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "IMAGE_REPO_URI"
      value = data.terraform_remote_state.container_registry.outputs.ecr_repository_url
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspecs/build-image.yml"
  }
}

# CodePipeline IAM role
resource "aws_iam_role" "codepipeline" {
  name = "your-project-${var.environment}-codepipeline"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# CodePipeline
resource "aws_codepipeline" "image_pipeline" {
  name     = "your-project-${var.environment}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceOutput"]
      configuration = {
        ConnectionArn        = var.codestar_connection_arn
        FullRepositoryId     = "your-github-org/your-repo"
        BranchName           = "main"
        OutputArtifactFormat = "CODEBUILD_CLONE_REF"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["BuildOutput"]
      configuration = {
        ProjectName = aws_codebuild_project.image_builder.name
      }
    }
  }
}
```

**BuildSpec** (`buildspecs/build-image.yml`):

```yaml
version: 0.2

phases:
  install:
    commands:
      - echo "Installing dependencies"
      - aws --version
      - docker --version
  pre_build:
    commands:
      - echo "Logging in to Amazon ECR"
      - ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
      - aws ecr get-login-password --region "$AWS_DEFAULT_REGION" | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"
      - COMMIT_HASH=$(echo "$CODEBUILD_RESOLVED_SOURCE_VERSION" | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:-latest}
      - export IMAGE_URI="$IMAGE_REPO_URI:$IMAGE_TAG"
  build:
    commands:
      - echo "Building Docker image"
      - docker build --platform linux/amd64 -t "$IMAGE_URI" -t "$IMAGE_REPO_URI:latest" .
  post_build:
    commands:
      - echo "Pushing Docker images"
      - docker push "$IMAGE_URI"
      - docker push "$IMAGE_REPO_URI:latest"
      - printf '{"ImageURI":"%s"}' "$IMAGE_URI" > imageDetail.json

artifacts:
  files:
    - imageDetail.json
```

---

## Standard File Patterns

### 1. `backend.tf` (Every Stack)

```hcl
terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }

  backend "s3" {
    bucket       = "YOUR-PROJECT-terraform-state"
    key          = "ENVIRONMENT/STACK-NAME.tfstate"
    region       = "ap-southeast-2"
    profile      = "your-aws-profile"
    encrypt      = true
    use_lockfile = true
  }
}
```

### 2. `providers.tf` (Every Stack)

```hcl
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = merge(local.base_tags, var.additional_tags)
  }
}
```

### 3. `locals.tf` (Every Stack)

```hcl
locals {
  base_tags = {
    Owner       = "Your Name"
    Environment = var.environment
    Project     = "your-project"
    App         = "your-app"
    ManagedBy   = "Terraform"
  }
  
  name_prefix = "your-project-${var.environment}"
}
```

### 4. `variables.tf` (Every Stack)

```hcl
variable "aws_region" {
  description = "AWS region for the environment"
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "your-profile"
}

variable "environment" {
  description = "Environment name used for tagging and resource naming"
  type        = string
  default     = "development"
}

variable "additional_tags" {
  description = "Optional additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

### 5. `remote_state.tf` (Stacks with Dependencies)

```hcl
data "terraform_remote_state" "core_networking" {
  backend = "s3"
  config = {
    bucket  = "YOUR-PROJECT-terraform-state"
    key     = "development/core-networking.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

# Add more remote state sources as needed
```

---

## Tagging Strategy

### Default Tags (via Provider)

All resources automatically inherit these tags through the provider's `default_tags`:

```hcl
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = merge(local.base_tags, var.additional_tags)
  }
}
```

### Base Tags (locals.tf)

```hcl
locals {
  base_tags = {
    Owner       = "Your Name"
    Environment = var.environment
    Project     = "your-project-name"
    App         = "your-app-name"
    ManagedBy   = "Terraform"
  }
}
```

### Component-Specific Tags

Individual resources can add component-specific tags:

```hcl
resource "aws_s3_bucket" "example" {
  bucket = "example-bucket"

  tags = merge(local.base_tags, {
    Component = "storage"
    Purpose   = "application-data"
  })
}
```

---

## Security & IAM Approach

### Principles

1. **Least Privilege**: Grant only the permissions required for the specific workload
2. **Separation of Concerns**: 
   - ECS Task Execution Role: For ECS agent (pull images, fetch secrets)
   - ECS Task Role: For application runtime (S3, DynamoDB, etc.)
3. **Explicit Deny for Unsafe Operations**: Use bucket policies to enforce TLS-only access
4. **Secrets Management**: Use Secrets Manager for structured secrets, SSM Parameter Store for configuration
5. **Audit Trail**: Enable CloudTrail and CloudWatch Logs for all critical resources

### IAM Role Patterns

**ECS Task Execution Role** (pulls images and secrets):

```hcl
data "aws_iam_policy_document" "ecs_task_execution_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.name_prefix}-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
```

**ECS Task Role** (application runtime permissions):

```hcl
data "aws_iam_policy_document" "ecs_task" {
  statement {
    sid    = "S3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.app_data.arn,
      "${aws_s3_bucket.app_data.arn}/*"
    ]
  }
}

resource "aws_iam_role" "ecs_task" {
  name               = "${local.name_prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy" "ecs_task" {
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task.json
}
```

### S3 Security Pattern

```hcl
# Enforce TLS-only access
data "aws_iam_policy_document" "bucket_tls" {
  statement {
    sid    = "EnforceTLS"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [
      aws_s3_bucket.example.arn,
      "${aws_s3_bucket.example.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "example" {
  bucket = aws_s3_bucket.example.id
  policy = data.aws_iam_policy_document.bucket_tls.json
}

# Block public access
resource "aws_s3_bucket_public_access_block" "example" {
  bucket                  = aws_s3_bucket.example.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "example" {
  bucket = aws_s3_bucket.example.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

---

## Deployment Order & Dependencies

### Dependency Graph

```
state-bootstrap (local state)
    ↓
core-networking
    ↓
    ├─→ security ──────────────────┐
    ├─→ storage ───────────────────┤
    ├─→ container-registry ────────┤
    ├─→ compute-ecs-cluster ───────┤
    ├─→ compute-ecs-alb ───────────┤
    └─→ database ──────────────────┤
                                   ↓
                        compute-ecs-demo-app
                                   ↓
                           route53-records
                                   ↓
                                 cicd
                                   ↓
                            observability
```

### Deployment Sequence

**Phase 1: Foundation**

```bash
# 1. Bootstrap state bucket (one-time)
cd infrastructure/terraform/state-bootstrap
terraform init
terraform apply

# 2. Core networking
cd ../stacks/development/core-networking
terraform init -migrate-state
terraform apply
```

**Phase 2: Shared Resources**

```bash
# 3-7. Apply in parallel (no dependencies between these)
cd ../security && terraform init -migrate-state && terraform apply
cd ../storage && terraform init -migrate-state && terraform apply
cd ../container-registry && terraform init -migrate-state && terraform apply
cd ../database && terraform init -migrate-state && terraform apply
cd ../compute-ecs-cluster && terraform init -migrate-state && terraform apply
cd ../compute-ecs-alb && terraform init -migrate-state && terraform apply
```

**Phase 3: Application**

```bash
# 8. ECS service (depends on all Phase 2 stacks)
cd ../compute-ecs-demo-app
terraform init -migrate-state
terraform apply
```

**Phase 4: DNS & CI/CD**

```bash
# 9. Route53 records
cd ../route53-records
terraform init -migrate-state
terraform apply

# 10. CI/CD pipeline
cd ../cicd
terraform init -migrate-state
terraform apply
```

**Phase 5: Observability**

```bash
# 11. Monitoring and alarms
cd ../observability
terraform init -migrate-state
terraform apply
```

### Quick Deploy Script

```bash
#!/bin/bash
set -e

ENV="development"
STACKS_DIR="infrastructure/terraform/stacks/$ENV"

# Phase 1: Core
echo "==> Deploying core-networking..."
(cd "$STACKS_DIR/core-networking" && terraform apply -auto-approve)

# Phase 2: Shared resources (parallel)
echo "==> Deploying shared resources..."
for stack in security storage container-registry database compute-ecs-cluster compute-ecs-alb; do
  (cd "$STACKS_DIR/$stack" && terraform apply -auto-approve) &
done
wait

# Phase 3: Application
echo "==> Deploying application..."
(cd "$STACKS_DIR/compute-ecs-demo-app" && terraform apply -auto-approve)

# Phase 4: DNS and CI/CD
echo "==> Deploying DNS and CI/CD..."
(cd "$STACKS_DIR/route53-records" && terraform apply -auto-approve)
(cd "$STACKS_DIR/cicd" && terraform apply -auto-approve)

# Phase 5: Observability
echo "==> Deploying observability..."
(cd "$STACKS_DIR/observability" && terraform apply -auto-approve)

echo "==> Deployment complete!"
```

---

## Adapting for Your Project

### Checklist: Setting Up a New Project

#### 1. Global Replacements

Search and replace these values across all files:

| Current Value | Replace With |
|--------------|--------------|
| `aws-lab-java` | `your-project-name` |
| `devops-sandbox` | `your-aws-profile` |
| `ap-southeast-2` | `your-aws-region` |
| `Dean Lofts` | `Your Name` |
| `aws.deanlofts.xyz` | `your-domain.com` |

#### 2. State Bucket

Update `infrastructure/terraform/state-bootstrap/variables.tf`:

```hcl
variable "bucket_name" {
  description = "Name of the Terraform state bucket"
  type        = string
  default     = "YOUR-PROJECT-terraform-state"  # Make globally unique
}
```

#### 3. VPC and Subnets

Update `stacks/development/core-networking/variables.tf` with your VPC details:

```hcl
variable "vpc_id" {
  description = "Pre-provisioned VPC ID"
  type        = string
  default     = "vpc-YOUR-VPC-ID"
}

variable "public_subnet_ids" {
  description = "Public subnet IDs"
  type        = list(string)
  default     = ["subnet-XXXXX", "subnet-YYYYY"]
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
  default     = ["subnet-ZZZZZ", "subnet-AAAAA"]
}
```

#### 4. Application Port

For NestJS (default port 3000), update `compute-ecs-demo-app/main.tf`:

```hcl
locals {
  container_port = 3000  # Change from 8080
}
```

And update security group rules in `core-networking/networking.tf`:

```hcl
resource "aws_security_group_rule" "ecs_from_alb" {
  from_port                = 3000  # Change from 8080
  to_port                  = 3000
  # ... rest of the rule
}
```

#### 5. Health Check Endpoint

Update `compute-ecs-demo-app/main.tf` target group:

```hcl
health_check {
  path = "/health"  # Or "/api/health" for NestJS
}
```

#### 6. Container Image Build

For TypeScript/Node.js projects, update `buildspecs/build-image.yml`:

```yaml
build:
  commands:
    - echo "Building Docker image"
    - docker build --platform linux/amd64 -t "$IMAGE_URI" -t "$IMAGE_REPO_URI:latest" .
    # Note: Change directory if your Dockerfile is not in repo root
```

#### 7. Environment Variables

Update task definition environment variables in `compute-ecs-demo-app/main.tf`:

```hcl
environment = [
  { name = "NODE_ENV", value = var.environment },
  { name = "PORT", value = tostring(local.container_port) },
  { name = "LOG_LEVEL", value = "info" }
]
```

#### 8. Database Configuration

For different database engines, update `database/main.tf`:

```hcl
resource "aws_db_instance" "main" {
  engine         = "postgres"  # or "mysql"
  engine_version = "15.4"      # adjust version
  db_name        = "yourdb"
  # ... rest of config
}
```

#### 9. CI/CD Integration

Update `cicd/main.tf` with your repository:

```hcl
configuration = {
  ConnectionArn    = var.codestar_connection_arn
  FullRepositoryId = "your-org/your-repo"  # Change
  BranchName       = "main"
}
```

#### 10. Domain Names

Update `compute-ecs-alb/main.tf`:

```hcl
resource "aws_acm_certificate" "ecs" {
  domain_name = "app.your-domain.com"  # Change
}
```

And `route53-records/main.tf`:

```hcl
resource "aws_route53_record" "ecs_service" {
  name = "app.your-domain.com"  # Change
}
```

---

## Additional Best Practices

### 1. Use Terraform Workspaces (Optional Alternative)

Instead of separate stack directories per environment, you can use workspaces:

```bash
terraform workspace new staging
terraform workspace select staging
terraform apply -var-file="staging.tfvars"
```

**Our approach**: Separate directories per environment for better isolation and clarity.

### 2. Remote State Locking Troubleshooting

If a lock is stuck:

```bash
# List lock objects
aws s3 ls s3://your-project-terraform-state/ --recursive | grep .tflock

# Remove a stuck lock (use with caution)
aws s3 rm s3://your-project-terraform-state/development/stack-name.tfstate.tflock
```

### 3. Cost Optimization

- **Development**: Use `db.t4g.micro`, single AZ, FARGATE_SPOT
- **Production**: Use `db.m6g.large`, Multi-AZ, FARGATE with autoscaling

### 4. Multi-Environment Promotion

To promote to staging/production:

1. Copy `stacks/development/` to `stacks/staging/`
2. Update `backend.tf` keys: `staging/stack-name.tfstate`
3. Update `variables.tf` defaults for environment-specific values
4. Create `staging.tfvars` with overrides

### 5. Secrets Rotation

Integrate AWS Secrets Manager rotation for database credentials:

```hcl
resource "aws_secretsmanager_secret_rotation" "database" {
  secret_id           = aws_secretsmanager_secret.database_credentials.id
  rotation_lambda_arn = aws_lambda_function.rotate_secret.arn

  rotation_rules {
    automatically_after_days = 30
  }
}
```

### 6. Blue/Green Deployments

Enable CodeDeploy for ECS blue/green deployments:

```hcl
deployment_controller {
  type = "CODE_DEPLOY"
}
```

---

## Summary: Key Takeaways

1. **Stack-Based Architecture**: Each stack is independently deployable with its own state file
2. **Remote State Sharing**: Stacks communicate via `terraform_remote_state` data sources
3. **S3 Native Locking**: Terraform 1.13+ eliminates the need for DynamoDB state locking
4. **Consistent File Structure**: Every stack follows the same pattern (backend, providers, locals, variables, main, outputs)
5. **Security by Default**: Private subnets, encrypted storage, TLS enforcement, least-privilege IAM
6. **Tagging Strategy**: Provider-level `default_tags` ensure all resources are properly tagged
7. **Clear Dependencies**: Deployment order is explicit and enforced via remote state references
8. **Modular Design**: Reusable modules for common patterns (ECR, state bucket, etc.)
9. **Environment Parity**: Same structure for dev/staging/prod with environment-specific variables
10. **Scalable Foundation**: Add new stacks without impacting existing infrastructure

---

## Next Steps

1. **Clone This Structure**: Copy the `infrastructure/terraform/` directory structure
2. **Bootstrap State**: Run the state-bootstrap stack first
3. **Deploy Core Networking**: Apply the core-networking stack
4. **Add Shared Resources**: Apply security, storage, database, etc. stacks
5. **Deploy Application**: Apply compute stacks and services
6. **Set Up CI/CD**: Configure CodePipeline for automated deployments
7. **Add Monitoring**: Deploy observability stack with CloudWatch dashboards

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Terraform Version**: >= 1.13.0  
**AWS Provider Version**: ~> 5.50

---


