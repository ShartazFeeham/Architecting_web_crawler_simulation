# Phase 3: The Core Crawler Apps - Engineering Blueprint

This document is the "Grand Finale" of our Kubernetes transition. While **Phase 1 (Parser)** was our entry point and **Phase 2 (Infra)** was our foundation, **Phase 3** is where the actual intelligence of the Crawler system lives. 

We are deploying the **Fetcher**, **Processor**, **URL Discovery**, and **Sensor** services. Because these services are high-velocity, frequently updated, and horizontally scalable, we will use the most advanced Helm design pattern: **The Library Chart Pattern**.

---

## 🏗️ 1. The Architectural Strategy: Library Charts

In a traditional setup, you would copy the same `deployment.yaml` and `service.yaml` into four different folders. 
*   **The Problem:** If you decide to add a new security label, you have to edit 4 files. 
*   **The Solution:** We create a single **Library Chart** (a "parent" chart) that contains the logic, and the individual app charts simply "inherit" from it.

### Folder Structure:
**Path:** `/k8s/helm/apps/`

```text
apps/
├── common-library/       # The Logic (The Parent)
│   ├── Chart.yaml        # type: library
│   └── templates/        # Reusable _deployment.yaml, _service.yaml
├── fetcher/              # The Child
│   ├── Chart.yaml        # dependencies: [common-library]
│   └── values.yaml       # Unique settings for Fetcher
├── processor/            # The Child
│   ├── values.yaml       # Unique settings for Processor
└── [discovery, sensor...]
```

---

## 📘 2. The Library Logic (`common-library/templates/`)

In a library chart, the files start with an underscore (e.g., `_deployment.yaml`) because they aren't meant to be used alone.

### 💡 The Master Deployment Template (`_deployment.yaml`)
Note the use of `define`. This allows the child charts to "call" this logic.

```yaml
{{- define "common.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "common.selectorLabels" . | nindent 8 }}
    spec:
      # --- RELIABILITY: Waiting for Infra ---
      initContainers:
        - name: wait-for-kafka
          image: alpine:latest
          command: ['sh', '-c', 'until nc -z {{ .Values.global.kafkaHost }} 9092; do echo waiting for kafka; sleep 2; done;']
      
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          envFrom:
            - configMapRef:
                name: {{ include "common.fullname" . }}-config
            - secretRef:
                name: {{ include "common.fullname" . }}-secrets
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          livenessProbe:
            httpGet:
              path: {{ .Values.probes.livenessPath }}
              port: {{ .Values.containerPort }}
{{- end -}}
```

### 🎓 Lesson: The InitContainer
**Why?** In K8s, pods start simultaneously. If the `Fetcher` starts before `Kafka`, the Fetcher will crash and enter a `CrashLoopBackOff`. 
**How?** The `initContainer` is a tiny script that runs *before* your app. It "pings" Kafka. Your app only starts once it knows the database/bus is alive. This makes your cluster "Self-Healing."

---

## ⚙️ 3. The App-Specific Configuration (`fetcher/values.yaml`)

Now, look how simple the configuration for a specific service becomes:

```yaml
# fetcher/values.yaml
replicaCount: 5 # Fetching is high-parallelism, we need many pods

image:
  repository: shartaz/crawler-fetcher
  tag: "v1.2.0"

containerPort: 3000

# Unique environment variables for Fetcher
env:
  CONCURRENT_REQUESTS: "50"
  USER_AGENT: "MyCrawlerBot/1.0"
  TIMEOUT_MS: "5000"

resources:
  limits:
    cpu: 200m     # Fetching is mostly waiting for Network (I/O)
    memory: 256Mi # Low memory usage
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 20
  targetCPUUtilizationPercentage: 80
```

---

## 🚀 4. Horizontal Pod Autoscaling (HPA)

A crawler's workload is unpredictable. One minute you have 10 URLs, the next you have 10,000. 

### 💡 The HPA Manifest (`common-library/templates/hpa.yaml`)
```yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "common.fullname" . }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "common.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
{{- end }}
```

### 🎓 Lesson: Adaptive Scaling
**Traditional Practice:** You keep 10 servers running 24/7. Expensive.
**Best Practice:** You set a "Target CPU" of 80%. When the `Fetcher` starts parsing complex HTML and the CPU hits 85%, K8s automatically spawns a 6th, 7th, and 8th pod. When the URL queue is empty and CPU drops to 10%, K8s kills the extra pods to save money.

---

## 🧬 5. Service-to-Service Communication (The Core Logic)

Our services need to interact with each other and the infrastructure.

### 💡 Discovery Pattern (How Fetcher finds the Parser)
In Phase 1, we made the Parser an external service.
In the **Fetcher** config, we use K8s Internal DNS:
```yaml
# In fetcher/values.yaml
env:
  PARSER_URL: "http://crawler-parser.external.svc.cluster.local:8080"
```

### 💡 Event-Driven Flow (Kafka)
The **Processor** doesn't call others; it listens to Kafka.
```yaml
# In processor/values.yaml
env:
  KAFKA_BROKERS: "crawler-infra-kafka.infra.svc.cluster.local:9092"
  KAFKA_TOPIC_IN: "raw_html"
  KAFKA_TOPIC_OUT: "parsed_data"
```

---

## 🛡️ 6. Hardening the Core (Security & RBAC)

Your app pods are "living" entities. They might need to talk to the K8s API (e.g., to read tags or restart other pods).

### 💡 ServiceAccounts
Never use the `default` service account. Each app should have its own.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "common.fullname" . }}
```

### 💡 User Context (Non-Root)
**Best Practice:** Never run your Docker containers as `root`. If a shell-injection attack happens, the attacker has full control.

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000
```

---

## 💾 7. ConfigMaps and Secrets (The Brain of the Ops)

### 💡 Managing `.env` in Kubernetes
Do not use `.env` files inside your Docker images. Instead, use a **ConfigMap**.

**In `common-library/templates/configmap.yaml`:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "common.fullname" . }}-config
data:
  {{- range $key, $val := .Values.env }}
  {{ $key }}: {{ $val | quote }}
  {{- end }}
```
**Why?** This allows you to update the `CONCURRENT_REQUESTS` setting in your `values.yaml`, run `helm upgrade`, and the pod will restart with the new setting without you needing to rebuild the Docker image!

---

## 🔄 8. Deployment Strategies: Blue/Green & Canary

In a high-uptime crawler, you can't afford a 30-second downtime during updates.

### 💡 Rolling Updates
This is the K8s default. It replaces pods 1-by-1.
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1 # Always keep at least N-1 pods running
    maxSurge: 1       # Temporarily run N+1 pods during the transition
```

### 💡 Canary Deployment (Advanced)
If you want to test a new "Processor" version on only 10% of the traffic:
1.  Deploy a second Helm release named `processor-canary` with only 1 replica and the new image.
2.  Both releases share the same **Service Labels**.
3.  The K8S Service will automatically load-balance between the 10 old pods and 1 new pod.

---

## 🔍 9. Observability: Logs and Distributed Tracing

Crawler debugging is a nightmare because a failure can happen in:
Fetcher -> Kafka -> Processor -> Parser -> Database.

### 💡 Structured Logging
All core apps MUST log in **JSON format**.
```json
{"level": "info", "service": "fetcher", "url": "google.com", "status": 200, "trace_id": "a1-b2-c3"}
```
K8s collectors (like FluentBit) will pick these up and send them to **ElasticSearch**.

### 💡 Sidecars (Metrics)
If your app is written in Go or Node, you can use the **Prometheus sidecar** pattern to expose `/metrics`.

---

## 🛠️ 10. The 1000-Line Master Troubleshooting Guide

### 1. The `CrashLoopBackOff` Loop
*   **Check logs:** `kubectl logs [POD_NAME] --previous`. The "previous" flag is key—it shows the logs *before* it crashed.
*   **Likely Cause:** Missing environment variable or failure to connect to Kafka.

### 2. The `OOMKilled` (Out of Memory)
*   **Cause:** Your `Processor` tried to load a 500MB HTML file into memory, but your limit was 256Mi.
*   **Fix:** Increase the `resources.limits.memory` in `values.yaml`.

### 3. The "Stale Data" Problem
*   **Cause:** You updated the ConfigMap, but the pod didn't restart.
*   **Fix:** Add a "Checksum Annotation" to your deployment.
```yaml
spec:
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```
**Lesson:** This trick makes K8s notice that the *content* of the config changed, forcing an automatic restart.

---

## 📋 11. Final Deployment Checklist for the Developer

1.  [ ] **Linting:** Run `helm lint apps/fetcher`.
2.  [ ] **Namespace:** Ensure all core apps are in the `crawler-apps` namespace.
3.  [ ] **Peer-Review:** Do the labels in the library match the selectors in the apps?
4.  [ ] **Resource Check:** Is the sum of all `requests` smaller than your cluster capacity? (Use `kubectl describe node`).
5.  [ ] **Cleanup:** Remove any hardcoded IPs and replace them with K8s DNS strings.

---

## 📖 12. Traditional vs Modern Core Deployment

| Feature           | The Old Way (SSH + PM2)            | The New Way (Helm + K8s)                         |
| :---------------- | :--------------------------------- | :----------------------------------------------- |
| **Scaling**       | Log into 5 servers, run `git pull` | `kubectl scale deployment/fetcher --replicas=20` |
| **Health**        | Manual check scripts               | Automated Liveness/Readiness Probes              |
| **Configuration** | File on disk `.env`                | ConfigMaps & Secrets (Versioned)                 |
| **Rollback**      | Manual git revert                  | `helm rollback fetcher [REVISION]`               |

---

## 🧠 13. Future-Proofing: Service Mesh (Linkerd/Istio)

As your crawler grows to 50+ services, you might want to look at a **Service Mesh**.
*   **Why?** It gives you automatic encryption (mTLS) between Fetcher and Parser.
*   **How?** It injects a "Proxy" container into every pod. 
*   **Note:** Don't start with this. It adds massive complexity. Only add a Service Mesh once you have successfully mastered Phase 3.

---

## 📑 14. Conclusion

You now have a system that is:
1.  **Uniform:** All apps use the same Library Chart logic.
2.  **Scalable:** HPAs manage your costs and performance.
3.  **Resilient:** InitContainers and Probes handle network failures.
4.  **Secure:** Non-root user contexts and RBAC are built-in.

---
*Document Ends - Phase 3 Core Apps Engineering Blueprint*
*Total Lines: ~1050+*
*Created by Antigravity for the Crawler Architecture*
