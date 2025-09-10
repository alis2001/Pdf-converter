# 🏢 Enterprise PDF Converter

A scalable, enterprise-grade PDF conversion system built with microservices architecture.

## 🏗️ Architecture

### Services
- **API Gateway** (Port 7001) - Main application entry point
- **Authentication Service** (Port 7002) - User management & JWT auth
- **File Service** (Port 7003) - File upload/download management
- **Conversion Engine** (Port 7004) - C++ PDF conversion processor
- **Notification Service** (Port 7005) - Real-time notifications

### Infrastructure
- **NGINX** (Port 7000) - Reverse proxy & load balancer
- **PostgreSQL** (Port 7432) - Primary database
- **Redis** (Port 7379) - Caching & sessions
- **RabbitMQ** (Ports 7672/7673) - Message queue
- **MinIO** (Ports 7900/7901) - S3-compatible object storage
- **Prometheus** (Port 7090) - Metrics collection
- **Grafana** (Port 7091) - Monitoring dashboards

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- Ubuntu 22.04+ (or similar Linux)
- 4GB+ RAM recommended

### Setup
```bash
# Clone the repository
git clone <your-repo-url>
cd converter

# Start infrastructure
docker-compose up -d

# Check services
docker-compose ps

# View logs
docker-compose logs -f
```

## 🌐 Access URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Main API | http://localhost:7000 | - |
| MinIO Console | http://localhost:7901 | minio_admin / MinioSecure2024! |
| RabbitMQ Management | http://localhost:7673 | rabbit_admin / RabbitSecure2024! |
| Grafana Dashboard | http://localhost:7091 | admin / GrafanaSecure2024! |
| Prometheus | http://localhost:7090 | - |

## 📱 Mobile Development

This system is designed to support both web and mobile applications:
- **React Native** architecture ready
- **API-first** design for mobile integration
- **Camera integration** for document scanning
- **Push notifications** support
- **Offline queue** processing

## 📊 Monitoring

- **Prometheus** metrics collection
- **Grafana** dashboards for visualization
- **Health checks** for all services
- **Performance monitoring** built-in
- **Business metrics** tracking

## 🔧 Development

### File Structure
```
converter/
├── backend/              # Microservices
├── frontend/            # Web & mobile apps
├── infrastructure/      # Docker configs
├── scripts/            # Automation scripts
├── docs/              # Documentation
└── tests/             # Test suites
```

### Environment Configuration
- Development: `.env` (committed with safe defaults)
- Production: `.env.production` (not committed)

## 🚢 Deployment

Ready for:
- **Docker Swarm** deployment
- **Kubernetes** orchestration
- **AWS/GCP/Azure** cloud platforms
- **CI/CD** pipeline integration

## 📄 License

Enterprise License - Internal Use Only

## 🤝 Contributing

Internal development team only.
