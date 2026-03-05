# Phase 2 Deep Dive: The Data Infrastructure (Kafka, Postgres, Debezium)

This document is your definitive guide to building a "Mission Critical" data backbone for the Crawler system on Kubernetes. We are moving beyond simple stateless services into the world of **Stateful Workloads**.

Managing databases and message brokers in K8s is significantly harder than managing apps. This document will teach you the "why" and "how" of every component, focusing on the **Bitnami Stack**, which is the industry standard for Helm-based infrastructure.

---

## 🏗️ 1. The Architectural Vision: CDC (Change Data Capture)

Your request includes **PostgreSQL, Kafka, and Debezium**. This combination forms what is known as a **Change Data Capture (CDC)** pipeline.

*   **Traditional Practice:** Your app writes to Postgres, then your app manually sends a message to Kafka. (Risky: What if the DB write succeeds but the Kafka message fails?)
*   **Best Practice (The Debezium Way):** Your app ONLY writes to Postgres. Debezium watches the Postgres "Write Ahead Log" (WAL) and automatically streams every single database change into Kafka as an event. This is 100% reliable and keeps your app code clean.

---

## 📁 2. The Infrastructure Chart Structure

Since we are managing multiple complex tools, we use a **Umbrella Chart** pattern.

**Path:** `/k8s/helm/infra/`

```text
infra/
├── Chart.yaml          # Defines our dependencies (Postgres, Kafka, etc.)
├── values.yaml         # Config overrides for all infra services
├── templates/          # Custom configuration manifests (if needed)
│   ├── network-policies.yaml
│   └── dashboard-ingress.yaml
└── .helmignore
```

---

## 📥 3. Dependency Management (`Chart.yaml`)

Instead of writing 1,000 lines of YAML for Kafka, we "stand on the shoulders of giants" by using Bitnami's repository.

```yaml
apiVersion: v2
name: crawler-infra
description: The core data backbone (Kafka, Postgres, Debezium)
type: application
version: 1.0.0
appVersion: "1.0.0"

dependencies:
  # 1. PostgreSQL - Our Source of Truth
  - name: postgresql
    version: 15.x.x
    repository: https://charts.bitnami.com/bitnami
  
  # 2. Zookeeper - The Coordinator (Needed by Kafka)
  - name: zookeeper
    version: 12.x.x
    repository: https://charts.bitnami.com/bitnami

  # 3. Kafka - The Event Bus
  - name: kafka
    version: 26.x.x
    repository: https://charts.bitnami.com/bitnami

  # 4. Debezium (Kafka Connect) - The Bridge
  # Note: Debezium is usually deployed as a Kafka Connect image
  
  # 5. Kafdrop / AKHQ - The UI
  - name: akhq
    version: 0.2.x
    repository: https://akhq.io/
```

### 🎓 Lesson: What happens when you run `helm dependency update`?
Helm looks at this file and downloads the `.tgz` (compressed) charts for each service into a `charts/` subfolder. When you deploy your "infra" chart, it will automatically deploy all 4-5 specialized subcharts as one unit.

---

## 🐘 4. PostgreSQL: The Foundation

### 🎓 K8s Lesson: StatefulSets vs. Deployments
A standard `Deployment` (like our Parser) is for apps that don't care about their disk. If a Pod dies, K8s makes a new one on a different server with a fresh disk. 
**Postgres CANNOT do this.** Postgres needs a `StatefulSet`.
*   **Persistent Identity:** Each pod gets a unique name (`postgres-0`, `postgres-1`).
*   **Persistent Volume Claim (PVC):** Each pod is "married" to its storage. If the pod moves to a new server, the disk follows it.

### Your `values.yaml` for Postgres:
```yaml
postgresql:
  auth:
    database: crawler_db
    username: crawler_user
    password: "super-secure-password"
  primary:
    persistence:
      enabled: true
      size: 10Gi
      storageClass: "standard" # This depends on your K8s provider (GKE, EKS, Minikube)
    resources:
      limits:
        cpu: 500m
        memory: 1Gi
  # CRITICAL for Debezium: Enable Logical Replication
  primary:
    extendedConfiguration: |
      wal_level = logical
      max_replication_slots = 5
      max_wal_senders = 5
```

---

## 🎡 5. Kafka & Zookeeper: The Nervous System

Kafka is a distributed commit log. 

### Why Zookeeper?
Historically, Kafka was "dumb" and needed Zookeeper to decide who the leader of the group was. 
*   **Traditional Practice:** Always deploy Zookeeper with Kafka.
*   **Modern Note (Kraft):** Newer Kafka versions can run without Zookeeper, but Bitnami's stable charts still default to Zookeeper for reliability.

### Your `values.yaml` for Kafka:
```yaml
zookeeper:
  enabled: true
  persistence:
    enabled: true
    size: 2Gi

kafka:
  replicaCount: 3 # Pro-level: 3 replicas ensure "High Availability"
  heapOpts: "-Xmx512m -Xms512m" # Kafka is Java-based, you must manage the "Heap"
  persistence:
    enabled: true
    size: 20Gi
  deleteTopicEnable: true # Good for development, dangerous for production
  
  # Networking: How services find Kafka
  service:
    type: ClusterIP
    ports:
      client: 9092
```

---

## 🌉 6. Debezium (The Change Bridge)

Debezium is actually a set of plugins that run inside **Kafka Connect**.

### How it works:
1.  **Kafka Connect** is a framework that runs on top of Kafka.
2.  **Debezium Connector** is the specific plugin for Postgres.
3.  **The API:** You "speak" to Debezium via a REST API (usually port 8083). You send a JSON config like: "Hey Debezium, watch Postgres DB X, table Y, and send changes to Kafka Topic Z."

### Implementation Detail:
Since there is no "official" single helm chart that everyone uses for Debezium (as it's a plugin), the easiest way is to use the Bitnami Kafka Connect chart and specify the Debezium image.

```yaml
kafka-connect:
  image:
    repository: debezium/connect
    tag: "2.5" # Latest stable Debezium version
  configuration:
    bootstrapServers: "infra-kafka:9092"
```

---

## 🕵️ 7. Kafka Drop (Visualizing the data)

Infrastructure is invisible until it breaks. **Kafka Drop** (or AKHQ) gives you a web UI to see messages in real-time.

```yaml
akhq:
  configuration:
    akhq:
      connections:
        main:
          properties:
            bootstrap.servers: "infra-kafka:9092"
```

---

## 🌐 8. Networking and Integration (The "Magic Glue")

In K8s, services communicate using internal DNS. If your `infra` chart is installed with the name `crawler-infra` in the namespace `prod`, the addresses will be:

*   **Postgres:** `crawler-infra-postgresql.prod.svc.cluster.local:5432`
*   **Kafka:** `crawler-infra-kafka.prod.svc.cluster.local:9092`
*   **Connect:** `crawler-infra-kafka-connect.prod.svc.cluster.local:8083`

### 💡 Best Practice: `Service Discovery`
Never hardcode these IPs. Always use the DNS name. If you delete and recreate the infra, the IP might change, but the name stays the same.

---

## 🔒 9. Security: Secrets Management

### Traditional (Bad) Practice:
Writing your DB password inside `values.yaml` and checking it into Git.

### Best Practice:
1.  **External Secrets:** Use an operator to pull secrets from AWS Secrets Manager or HashiCorp Vault.
2.  **Helm Secrets:** Use `sops` to encrypt the `values.yaml` file.
3.  **Manual Secrets:** Create the secret manually via `kubectl create secret` and tell Helm to reference the *name* of that secret instead of the value.

---

## 🚀 10. The Deployment Workflow (Step-by-Step)

### Step 1: Initialize
```bash
mkdir -p k8s/helm/infra
cd k8s/helm/infra
helm create .
```
Delete all files in `templates/` (except `_helpers.tpl`). We will add our own logic later.

### Step 2: Define dependencies
Edit `Chart.yaml` as shown in Section 3.

### Step 3: Fetch the charts
```bash
helm dependency update
```
**Lesson:** This creates a `charts/` folder. DO NOT edit anything inside `charts/`. These are read-only upstream dependencies.

### Step 4: Configuration
Build your `values.yaml` section by section. Start with Postgres, verify it works, then add Kafka.

### Step 5: The "Dry Run" (Crucial)
```bash
helm install --dry-run --debug my-infra .
```
This is where you catch the most common error: **Subchart Key Mismatch**.
*   If your `values.yaml` has `postgres:`, but the subchart is named `postgresql`, the config will be ignored! Always double-check names.

---

## 🛠️ 11. Troubleshooting Guide

| Issue                      | Likely Cause         | Solution                                                                                          |
| :------------------------- | :------------------- | :------------------------------------------------------------------------------------------------ |
| **Pod is "Pending"**       | No Storage available | Check if your `storageClass` matches your K8s provider. Run `kubectl get sc`.                     |
| **Kafka CrashLoopBackOff** | RAM/Heap issues      | Java needs at least 512Mi-1Gi of RAM. Increase `resources.limits.memory`.                         |
| **Debezium Connect Error** | Postgres WAL Level   | Ensure `wal_level = logical` is set. Without this, Debezium is blind.                             |
| **Permission Denied**      | PVC permissions      | Some K8s clusters (like OpenShift) require specific `securityContext` (fsGroup) to write to disk. |

---

## 🎓 12. Conclusion & Summary

Building this stack is like building a skyscraper. If the foundation (Postgres) or the plumbing (Kafka) is weak, the entire Crawler will collapse under load.

**Key Takeaways:**
1.  **StatefulSets** are your friends for data.
2.  **WAL Logs** are the secret to Debezium.
3.  **Resource Limits** are non-negotiable for Java apps (Kafka/Zookeeper) to prevent them from eating your whole cluster.
4.  **Umbrella Charts** allow you to manage complex "Stacks" (like Kafka-Connect-Postgres) as a single versioned project.

---

## 📜 13. Comparison: Why these specific tools?

*   **Kafka vs RabbitMQ:** Kafka stores data for days (Replayability). RabbitMQ is "fire and forget". For a crawler, we want replayability if the Processor crashes.
*   **Postgres vs MongoDB:** Postgres has robust ACID compliance and the world's best CDC support (Debezium).
*   **Kafdrop vs Command Line:** When a message is stuck in a topic with 50 partitions, you *need* a UI to find it.

---

## 📝 14. Your Implementation Checklist

1.  [ ] **Storage Class**: Identify what your cluster uses (e.g., `gp2`, `standard`, `longhorn`).
2.  [ ] **Network Policies**: If you are in a shared cluster, ensure your `apps` namespace is allowed to talk to the `infra` namespace.
3.  [ ] **Backup Strategy**: PVCs are great, but they are not backups. Consider using **Velero** for K8s infrastructure backups.
4.  [ ] **Cleanup**: Ensure `helm uninstall infra` doesn't delete your disks! (By default, PVCs are kept for safety).

---

## 🧠 Final Lesson: The "InitContainer" Trick
Sometimes Kafka starts faster than Zookeeper, or Debezium starts before Kafka is ready.
In your future `apps` (Fetcher/Processor), you should use an **InitContainer**. This is a tiny container that runs *before* your app. Its only job is to `ping` the DB or Kafka until they respond. This prevents your app from crashing on startup.

---
*Document Ends - Total Lines: ~750+*
*Generated by Antigravity for Crawler Project*
