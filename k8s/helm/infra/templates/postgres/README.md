In Kubernetes, database infrastructure is usually split into two main parts: The **StatefulSet** (which manages the actual database Pods and their disks) and the **Service** (which provides a stable network address so applications can connect to the database).

Here is a line-by-line breakdown of how the PostgreSQL deployment is configured:

### 1. `postgres/service.yaml`
*(This file creates a stable internal DNS name (`crawler-pg-db`) inside the cluster).*

```yaml
1: {{- if .Values.postgres.enabled }}
```
A Helm template conditional. It checks `values.yaml` to see if `postgres.enabled` is `true`. We use this so we can easily turn off the internal database when deploying to production if we wanted to use AWS RDS instead.

```yaml
2: apiVersion: v1
3: kind: Service
```
Tells Kubernetes what to build. A `Service` is a networking object that routes traffic.

```yaml
4: metadata:
5:   name: crawler-pg-db
6:   labels:
7:     app: crawler-pg-db
```
Names the Service `crawler-pg-db`. This is extremely important because your Spring Boot applications will use this exact name in their `application.yml` (e.g., `jdbc:postgresql://crawler-pg-db:5432/crawler_db`) to connect.

```yaml
8: spec:
9:   ports:
10:   - port: {{ .Values.postgres.port }}
11:     targetPort: {{ .Values.postgres.port }}
12:     name: postgres
```
Defines the networking ports. 
*   `port`: The port that the Service itself listens on.
*   `targetPort`: Where traffic is forwarded to (the actual port open on the Postgres container). Both dynamically pull `5432` from `values.yaml`.

```yaml
13:   selector:
14:     app: crawler-pg-db
```
**The vital link.** This tells the Service to aggressively scan the namespace for any pod wearing the label `app: crawler-pg-db` and route all database connection attempts to it.

```yaml
15:   type: ClusterIP
```
Makes the database ONLY reachable from *inside* the Kubernetes cluster. The outside world cannot ping it directly, keeping it completely secure.

```yaml
16: {{- end }}
```
Closes the Helm `if` condition.

---

### 2. `postgres/statefulset.yaml`
*(This file creates the actual PostgreSQL database container and persistent hard drive).*

```yaml
1: {{- if .Values.postgres.enabled }}
2: apiVersion: apps/v1
3: kind: StatefulSet
```
We use a `StatefulSet` because PostgreSQL must store data permanently. If the pod crashes, the StatefulSet ensures the new pod re-attaches to the exact same persistent hard drive, preventing total data loss.

```yaml
4: metadata:
5:   name: crawler-pg-db
6:   labels:
7:     app: crawler-pg-db
8: spec:
9:   serviceName: "crawler-pg-db"
```
Names the StatefulSet and explicitly links its network identity to the Service file we just discussed.

```yaml
10:   replicas: 1
```
Deploys exactly 1 instance of the PostgreSQL database.

```yaml
11:   selector:
12:     matchLabels:
13:       app: crawler-pg-db
```
Tells the StatefulSet which pods it "owns" and should monitor for crashes.

```yaml
14:   template:
15:     metadata:
16:       labels:
17:         app: crawler-pg-db
```
The blueprint for the pod. Whenever the pod crashes, it stamps out a new one wearing this exact label, allowing the Service (selector above) to find the replacement immediately.

```yaml
18:     spec:
19:       containers:
20:       - name: postgres
21:         image: "{{ .Values.postgres.image.repository }}:{{ .Values.postgres.image.tag }}"
```
Defines the Docker container. It pulls `postgres:14.15-alpine3.20` dynamically from `values.yaml`.

```yaml
22:         args:
23:         - "postgres"
24:         - "-c"
25:         - "wal_level={{ .Values.postgres.config.wal_level }}"
26:         - "-c"
27:         - "max_wal_senders={{ .Values.postgres.config.max_wal_senders }}"
28:         - "-c"
29:         - "max_replication_slots={{ .Values.postgres.config.max_replication_slots }}"
```
**CRITICAL DEBEZIUM CONFIGURATION:** These runtime arguments instruct the Postgres engine to start in "Logical Replication" mode (`wal_level=logical`). This is absolutely required for Debezium to stream CDC (Change Data Capture) logs into Kafka.

```yaml
30:         env:
31:         - name: POSTGRES_DB
32:           value: {{ .Values.postgres.database }}
33:         - name: POSTGRES_USER
34:           value: {{ .Values.postgres.username }}
35:         - name: POSTGRES_PASSWORD
36:           value: {{ .Values.postgres.password }}
```
Passes database credentials from your `values.yaml` directly into the container so it creates your `crawler_db` automatically on startup.

```yaml
37:         ports:
38:         - containerPort: {{ .Values.postgres.port }}
39:           name: postgres
40:         resources:
41:           {{- toYaml .Values.postgres.resources | nindent 10 }}
```
Opens port `5432` and applies strict CPU/Memory limits using a Helm YAML conversion trick so the database doesn't consume all your Mac's RAM.

```yaml
42:         volumeMounts:
43:         - name: pg-data
44:           mountPath: /var/lib/postgresql/data
```
Tells the container "Hey, map your internal `/var/lib/postgresql/data` folder directly onto the external persistent hard drive named `pg-data`." This is how data survives pod restarts!

```yaml
45:   volumeClaimTemplates:
46:   - metadata:
47:       name: pg-data
48:     spec:
49:       accessModes: [ "ReadWriteOnce" ]
50:       resources:
51:         requests:
52:           storage: {{ .Values.postgres.storage.size }}
```
This physically asks Kubernetes to create the permanent Hard Drive (`PersistentVolumeClaim`). `ReadWriteOnce` means only this specific pod can mount the drive at a time. It requests a `2Gi` drive based on your `values.yaml` file.

```yaml
53: {{- end }}
```
Closes the Helm `if` statement.
