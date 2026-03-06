In Kubernetes, infrastructure is usually split into two parts: The **StatefulSet/Deployment** (which creates the actual running Pods/Containers) and the **Service** (which acts as a stable network load balancer so other things can find those Pods).

Here is the line-by-line breakdown of both files:

### 1. `zookeeper/service.yaml`
*(This file creates a stable internal DNS name (`crawler-zookeeper`) inside the cluster).*

```yaml
1: {{- if .Values.zookeeper.enabled }}
```
This is a Helm template conditional. It checks your `values.yaml` file to see if `zookeeper.enabled` is `true`. If it's `false`, Helm completely ignores this entire file and won't deploy it.

```yaml
2: apiVersion: v1
3: kind: Service
```
This tells Kubernetes exactly what type of object we are creating. `v1` is the API version, and a `Service` is a networking object that routes traffic.

```yaml
4: metadata:
5:   name: crawler-zookeeper
```
This names the Service. Because we named it exactly `crawler-zookeeper`, any other pod in your infrastructure namespace (like your Kafka brokers) can simply use the alias `crawler-zookeeper` to talk to it, and Kubernetes will resolve the networking automatically.

```yaml
6:   labels:
7:     app: crawler-zookeeper
```
These are tags attached to the Service for organizational purposes, making it easy to query or group resources later.

```yaml
8: spec:
```
The `spec` block defines the actual active configuration of the Service.

```yaml
9:   ports:
10:   - port: {{ .Values.zookeeper.port }}
11:     targetPort: {{ .Values.zookeeper.port }}
12:     name: client
```
This defines the networking ports. 
*   `port`: The port that the Service itself will listen on (dynamically pulling `2181` from `values.yaml`).
*   `targetPort`: Where the Service will forward the traffic to (port `2181` on the actual Zookeeper pod).

```yaml
13:   selector:
14:     app: crawler-zookeeper
```
**This is the most critical part of the Service.** The `selector` tells the Service *how to find* the pods it should send traffic to. It actively scans the namespace for any pod that has the label `app: crawler-zookeeper` and routes traffic to them.

```yaml
15:   type: ClusterIP
```
This makes the Service only reachable from *inside* the Kubernetes cluster. It does not get an external IP address, which is good for security since the outside world shouldn't be talking directly to Zookeeper.

```yaml
16: {{- end }}
```
Closes the Helm `if` condition started on line 1.

---

### 2. `zookeeper/statefulset.yaml`
*(This file creates the actual Zookeeper Docker container/pod).*

```yaml
1: {{- if .Values.zookeeper.enabled }}
```
Again, only deploys if Zookeeper is enabled in `values.yaml`.

```yaml
2: apiVersion: apps/v1
3: kind: StatefulSet
```
We use a `StatefulSet` instead of a standard `Deployment` because Zookeeper is a database-like application that stores data. StatefulSets ensure the pod gets a strict, predictable name (like `crawler-zookeeper-0`) and maintains a stable identity if it crashes.

```yaml
4: metadata:
5:   name: crawler-zookeeper
6:   labels:
7:     app: crawler-zookeeper
```
Names the StatefulSet and applies organizational tags.

```yaml
8: spec:
9:   serviceName: "crawler-zookeeper"
```
This links this StatefulSet to the Service we created in the other file. It tells Kubernetes to use that Service to manage the network identity of the pods created here.

```yaml
10:   replicas: 1
```
We are telling Kubernetes to boot up exactly 1 instance (pod) of Zookeeper. 

```yaml
11:   selector:
12:     matchLabels:
13:       app: crawler-zookeeper
```
This tells the StatefulSet which pods it is responsible for managing. It will "own" and monitor any pod with this label.

```yaml
14:   template:
```
Everything from this line down acts as a blueprint/stamp. Whenever the StatefulSet needs to create a pod, it stamps out a pod matching exactly what is defined below.

```yaml
15:     metadata:
16:       labels:
17:         app: crawler-zookeeper
```
Attaches the required label to the minted pod so the `selector` (line 11) and the Service can successfully find it.

```yaml
18:     spec:
19:       containers:
20:       - name: zookeeper
```
Begins the definition of the actual Docker container and names it `zookeeper`.

```yaml
21:         image: "{{ .Values.zookeeper.image.repository }}:{{ .Values.zookeeper.image.tag }}"
```
Specifies the Docker image to download. It parses the string to pull `confluentinc/cp-zookeeper:7.8.0` dynamically from `values.yaml`.

```yaml
22:         env:
```
Begins the list of Environment Variables to inject into the container when it powers on.

```yaml
23:         - name: ZOOKEEPER_CLIENT_PORT
24:           value: {{ .Values.zookeeper.port | quote }}
```
Tells the Confluent Zookeeper software inside the container which port it should start listening on (`2181`). The `quote` function ensures Helm passes it as a string rather than a raw integer, which prevents parsing errors.

```yaml
25:         - name: ZOOKEEPER_TICK_TIME
26:           value: "2000"
```
A specific Zookeeper configuration setting. A "tick" is the basic time unit (in milliseconds) used by Zookeeper to regulate heartbeats and timeouts between clusters. 2000ms (2 seconds) is the standard default.

```yaml
27:         ports:
28:         - containerPort: {{ .Values.zookeeper.port }}
29:           name: client
```
This officially opens port `2181` on the container so traffic can physically enter it.

```yaml
30:         resources:
31:           {{- toYaml .Values.zookeeper.resources | nindent 10 }}
```
This is a Helm trick. It takes the CPU and Memory limits we defined in `values.yaml` (e.g., `cpu: 25m`, `memory: 128Mi`), converts them to pure YAML syntax using `toYaml`, and injects them here. The `nindent 10` adds exactly 10 spaces of indentation before each line so they align perfectly with the surrounding yaml structure. This ensures the pod is strictly throttled and doesn't consume all your Mac's RAM.

```yaml
32: {{- end }}
```
Closes the Helm `if` condition from line 1.
