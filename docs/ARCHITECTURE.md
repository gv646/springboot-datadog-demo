# Architecture Documentation

## Overview

This document provides detailed information about the architecture of the Spring Boot + DataDog POC.

## System Components

### 1. Application Container (Main)
- **Technology**: Spring Boot 3.3.5 + Java 21
- **Port**: 8080
- **Responsibilities**:
  - Serve REST API endpoints
  - Generate application logs
  - Send traces to DataDog agent
  - Emit custom metrics

### 2. DataDog Sidecar Container
- **Image**: `datadog/serverless-init:latest`
- **Port**: 8126 (APM trace agent)
- **Responsibilities**:
  - Collect application logs from `/home/LogFiles`
  - Receive APM traces from the application
  - Forward all telemetry to DataDog cloud
  - Collect system metrics

### 3. Shared Storage
- **Location**: `/home/LogFiles`
- **Purpose**: Shared volume for log files between containers

## Communication Flow
```
User Request
     │
     ▼
Azure App Service Load Balancer
     │
     ▼
┌────────────────────────────────────┐
│  Main Container (Port 8080)        │
│  ┌──────────────────────────────┐  │
│  │  Spring Boot Application     │  │
│  │  - Processes request          │  │
│  │  - Logs to file              │──┼──► /home/LogFiles/
│  │  - Sends trace to DD agent   │──┼──► localhost:8126
│  └──────────────────────────────┘  │
└────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────┐
│  DataDog Sidecar (Port 8126)       │
│  ┌──────────────────────────────┐  │
│  │  DataDog Agent               │  │
│  │  - Reads logs ◄──────────────┼──┘ /home/LogFiles/
│  │  - Receives traces           │
│  │  - Aggregates metrics        │
│  └──────────────────────────────┘  │
└────────────────────────────────────┘
                 │
                 ▼
          DataDog Cloud
      (ap2.datadoghq.com)
```

## Deployment Architecture
```
Developer Machine
     │ (1) Build & Push
     ▼
Azure Container Registry
     │
     ▼ (2) Pull Image
Azure App Service
     │
     ├─► Main Container
     │
     └─► DataDog Sidecar
          │
          ▼ (3) Send Telemetry
     DataDog Platform
```

## Key Design Decisions

### Why Sidecar Pattern?
- **Separation of Concerns**: Monitoring logic separate from business logic
- **Easy Updates**: Update DataDog agent without touching application
- **No Code Changes**: Minimal application code changes needed
- **Reusable**: Same sidecar can be used across multiple services

### Why Container-Based Deployment?
- **Consistency**: Same container runs everywhere (dev, staging, prod)
- **Portability**: Easy to move between cloud providers
- **Isolation**: Better resource isolation
- **Scalability**: Easier horizontal scaling

### Why Azure App Service?
- **Managed Platform**: Less infrastructure management
- **Sidecar Support**: Native support for multiple containers
- **Integration**: Good integration with Azure services
- **Cost-Effective**: Pay only for what you use

## Security Considerations

1. **API Key Storage**: DataDog API key stored as environment variable
2. **Container Registry**: Private ACR with authentication
3. **Network**: Containers communicate via localhost
4. **HTTPS**: All external traffic encrypted

## Scalability

- **Horizontal**: Add more instances via App Service scaling
- **Vertical**: Increase App Service Plan tier
- **Auto-scaling**: Can configure based on CPU/memory metrics

## Monitoring Points

1. **Application Metrics**: Custom business metrics
2. **System Metrics**: CPU, memory, disk usage
3. **APM Traces**: Request/response times, errors
4. **Logs**: Application and system logs
5. **Alerts**: Configure in DataDog for anomalies

## Future Enhancements

- CI/CD pipeline integration
- Multiple environment support (dev/staging/prod)
- Database integration
- Message queue integration
- Advanced DataDog features (synthetic monitoring, etc.)
