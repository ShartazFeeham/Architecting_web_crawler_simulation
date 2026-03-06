Unlike Zookeeper and Kafka which are heavily stateful and store data permanently, Debezium (running as a Kafka Connect worker) is surprisingly **stateless**. It reads from the Postgres database, but it stores its memory of where it last read (its "offsets") safely inside an internal Kafka topic, not on its local hard drive.

Because it is stateless, its infrastructure is built using a simple **Deployment** and it requires a **ConfigMap** to dynamically tell it which database to watch.

Here is a line-by-line breakdown of the Debezium configuration:

### 1. `debezium/deployment.yaml`
*(This creates the actual Debezium worker containers).*

```yaml
1: {{- if .Values.debezium.enabled }}
2: apiVersion: apps/v1
3: kind: Deployment
```
A `Deployment` assumes the application is entirely stateless. If the Debezium pod crashes, Kubernetes violently throws away the broken container and stamps out a brand new, identical replacement pod instantly. It will simply reconnect to Kafka to figure out where it left off.

```yaml
4: metadata:
5:   name: crawler-debezium
...
9:   replicas: 1
10:   selector:
11:     matchLabels:
12:       app: crawler-debezium
```
Standard configuration ensuring exactly 1 pod labelled `crawler-debezium` is running at all times.

```yaml
19:       - name: debezium
20:         image: "{{ .Values.debezium.image.repository }}:{{ .Values.debezium.image.tag }}"
```
Sets the blueprint for the docker container, pulling `debezium/connect:2.5` from values.

```yaml
24:         # Kafka Connect relies on Kafka to store its offsets/configs instead of a local hard drive
25:         - name: BOOTSTRAP_SERVERS
26:           value: "crawler-kafka:9092"
```
Tells Debezium where the Kafka cluster is located so it can stream the database changes straight into it.

```yaml
27:         - name: GROUP_ID
28:           value: "1"
29:         - name: CONFIG_STORAGE_TOPIC
30:           value: "my_connect_configs"
31:         - name: OFFSET_STORAGE_TOPIC
32:           value: "my_connect_offsets"
33:         - name: STATUS_STORAGE_TOPIC
34:           value: "my_connect_statuses"
```
These are the internal Kafka topics where Debezium safely stores its state. This is exactly why Debezium doesn't need a persistent hard drive.

```yaml
40:         readinessProbe:
41:           httpGet:
42:             path: /connectors
43:             port: {{ .Values.debezium.port }}
44:           initialDelaySeconds: 15
45:           timeoutSeconds: 5
```
This tells Kubernetes to constantly check `http://crawler-debezium:8083/connectors`. Kubernetes will refuse to send any traffic to this pod until that URL returns a healthy status code, proving Debezium has finished booting up its Java environment.

```yaml
46:         # This lifecycle hook fires immediately after the container is marked Ready.
47:         lifecycle:
48:           postStart:
49:             exec:
50:               command:
51:                 - "sh"
52:                 - "-c"
53:                 - "sleep 10 && curl -X POST -H 'Accept:application/json' -H 'Content-Type:application/json' http://localhost:8083/connectors/ -d @/debezium/config/pg-connector.json"
```
**The vital auto-configuration link:** Debezium boots up empty. It doesn't know it's supposed to watch Postgres. This `postStart` lifecycle hook executes a hidden shell script inside the container right after it boots. It waits 10 seconds for the REST API to warm up, and then uses `curl` to automatically submit the JSON configuration file directly to its own API (`localhost:8083`), forcing it to start reading the database.

---

### 2. `debezium/configmap.yaml`
*(This holds the actual JSON payload that tells Debezium how to connect to Postgres).*

```yaml
2: apiVersion: v1
3: kind: ConfigMap
4: metadata:
5:   name: crawler-debezium-config
```
A ConfigMap is a Kubernetes object used to store non-confidential data in key-value pairs (like a floating settings file).

```yaml
10:       "name": "crawler-pg-connector",
11:       "config": {
12:         "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
```
This JSON payload tells Debezium to load the specific Postgres Plugin.

```yaml
14:         "database.hostname": "crawler-pg-db",
...
16:         "database.user": "{{ .Values.postgres.username }}",
```
Notice how it uses the internal Kubernetes DNS name (`crawler-pg-db`) to find the database, and dynamically pulls the password from `values.yaml`. 

```yaml
20:         "plugin.name": "pgoutput",
21:         "slot.name": "debezium",
22:         "publication.name": "debezium_publication",
```
Tells Debezium to hook into the exact Logical Replication slots we configured inside the Postgres container earlier.

```yaml
23:         "table.include.list": "public.urls",
24:         "topic.prefix": "crawler"
```
Instructs Debezium to *only* watch for changes in the `urls` table, and explicitly stream those events to a Kafka topic named `crawler.public.urls`.

---

### 3. `debezium/service.yaml`
*(Creates an internal network bridge to the Deployment).*

```yaml
2: apiVersion: v1
3: kind: Service
4: metadata:
5:   name: crawler-debezium
...
10:   - port: {{ .Values.debezium.port }}
11:     targetPort: {{ .Values.debezium.port }}
```
Creates a stable, internal-only IP address named `crawler-debezium` that routes to port `8083` on any pod labeled `app: crawler-debezium`. This allows other tools in the cluster to interact with the Debezium REST API if necessary.
