# Architecting Web Crawler Simulation

A web crawler simulated as a set of cooperating Spring Boot microservices communicating over Kafka. Each stage of a real crawler pipeline is its own service: URL discovery, fetching, parsing, and processing, with a sensor service for monitoring.

## Services

| Module | Role |
|---|---|
| `url.discovery/` | Discovers and queues URLs to crawl |
| `fetcher/` | Fetches page content for discovered URLs |
| `parser/` | Parses fetched content and extracts links/data |
| `processor/` | Processes parsed results |
| `sensor/` | Monitoring/telemetry for the pipeline |
| `docs and infra/` | Design docs and infrastructure configuration |

## Tech Stack

- Java 21, Spring Boot 3.4 (Maven, each service has its own `pom.xml` and Dockerfile)
- Spring Kafka for inter-service messaging
- Docker for containerization

## Getting Started

### Prerequisites

- Java 21
- Maven (wrapper `mvnw` included in each module)
- A running Kafka broker
- Docker (optional)

### Run

Each module is an independent Spring Boot app with a Dockerfile:

```bash
cd fetcher
./mvnw spring-boot:run
```

Repeat for each service (start Kafka first). See `docs and infra/` for the overall design and infrastructure setup.

<!-- sync-marker-1 -->
