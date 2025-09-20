# Nimbus Analytics Architecture Overview

## System Architecture

Nimbus Analytics implements a microservices architecture with defense-in-depth security controls:
[Internet] → [Application Load Balancer] → [ECS Fargate Containers]
↓                           ↓
[WAF (Optional)]              [Private Subnets]
↓
[Database Subnets]
↓
[RDS]
[VPC Flow Logs] → [CloudWatch] → [SNS] → [Security Team]
↓
[Lambda Threat Detection]

## Network Topology

### Public Subnets (DMZ)
- Application Load Balancer
- NAT Gateways
- Bastion hosts (if needed)

### Private Subnets (Application Tier)
- ECS Fargate containers
- Application services
- No direct internet access (via NAT Gateway only)

### Database Subnets (Data Tier)
- RDS instances
- ElastiCache (if used)
- No internet access at all
- Only accessible from application subnets

## Security Layers

1. **Edge Security**: AWS WAF (optional), ALB security groups
2. **Network Security**: VPC isolation, security groups, NACLs, private subnets
3. **Application Security**: Container hardening, non-root users, read-only filesystems
4. **Data Security**: Encryption at rest/transit, field-level encryption
5. **Monitoring**: VPC Flow Logs, CloudWatch, Lambda threat detection

## Components

### Analytics API
- **Technology**: Node.js, Express
- **Security**: Helmet.js, rate limiting, input validation
- **Deployment**: ECS Fargate with security hardening
- **Network**: Private subnet, ALB access only

### Data Processor
- **Technology**: Python, Pandas, NumPy  
- **Security**: Restricted container, minimal capabilities
- **Deployment**: Batch processing with resource limits
- **Network**: Private subnet, no external access

### Web Dashboard
- **Technology**: React, NGINX
- **Security**: CSP headers, secure cookies, HTTPS only
- **Deployment**: Static files served via NGINX container
- **Network**: Private subnet, ALB access only

## Security Controls Implementation

### Container Security
- Non-root execution (UID 1001)
- Read-only root filesystems
- Dropped Linux capabilities
- Resource limits (CPU/Memory)
- Health checks and monitoring

### Network Security  
- Zero-trust networking model
- Least-privilege security groups
- VPC Flow Logs for audit trail
- Private DNS resolution
- No direct internet access for containers

### Data Protection
- KMS encryption for all data at rest
- TLS 1.3 for data in transit
- Database connection encryption
- Secrets management via AWS Secrets Manager

### Monitoring and Alerting
- CloudWatch metrics and alarms
- VPC Flow Log analysis
- Lambda-based threat detection
- SNS notifications for security events
- Compliance audit logging
