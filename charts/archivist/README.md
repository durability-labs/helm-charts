# Archivist Helm Chart

 1. [Description](#description)
 2. [Installation](#installation)
 3. [Deployment strategies](#deployment-strategies)
     - [Private deployment](#private-deployment)
     - [Public deployment](#public-deployment)
     - [Replica count](#replica-count)
     - [Knows issues](#knows-issues)
     - [Prettify](#prettify)
 4. [Development](#development)
 5. [To do](#to-do)


## Description

 Archivist is a decentralized data storage platform that provides exceptionally strong censorship resistance and durability guarantees.

 Chart will install Archivist in Kubernetes and make nodes publicly accessible in the Internet or just for in-cluster testing. For more information please read [Deployment strategies](#deployment-strategies).


## Installation

 > **Note:** Please read [Deployment strategies](#deployment-strategies) before the installation.

 1. Create a namespace
    ```shell
    kubectl create namespace archivist-ns
    ```

 2. Create secrets if we would like to pass sensitive data

    Create `archivist-eth-provider` secret, a common one for all Archivist instances
    ```shell
    secret='apiVersion: v1
    kind: Secret
    metadata:
      name: archivist-eth-provider
      namespace: archivist-ns
      labels:
        name: archivist
    type: Opaque
    stringData:
      ARCHIVIST_ETH_PROVIDER: https://mainnet.infura.io/v3/YOUR-API-KEY
    '

    echo $secret | kubectl create -f -
    ```

    Generate ethereum key pair for each replica
    ```shell
    docker run --rm gochain/web3 account create
    ```

    Create `archivist-eth-private-key` secret, a common one with separate key for each Archivist instance
    ```shell
    secret='apiVersion: v1
    kind: Secret
    metadata:
      name: archivist-eth-private-key
      namespace: archivist-ns
      labels:
        name: archivist
    type: Opaque
    stringData:
      ARCHIVIST_ETH_PRIVATE_KEY-1-1: 0x...
      ARCHIVIST_ETH_PRIVATE_KEY-2-1: 0x...
    '

    echo $secret | kubectl create -f -
    ```
    > **Note:** Please note, key name should contain Pod index, like `-1-1`, `-2-1` in case of multiple replicas or single replica with `statefulSet.prettify=false` and `-1` in case of single replica.

 3. Create a `archivist-api-basic-auth` secret if we would like to expose Archivist API via [Ingress NGINX Controller](https://kubernetes.github.io/ingress-nginx/) protected by [basic authentication](https://kubernetes.github.io/ingress-nginx/examples/auth/basic/)
    ```shell
    docker run --rm httpd htpasswd -bnB <username> <password>
    ```
    ```shell
    secret='apiVersion: v1
    kind: Secret
    metadata:
      name: archivist-api-basic-auth
      namespace: archivist-ns
      labels:
        name: archivist-api-basic-auth
    type: Opaque
    stringData:
      auth: >-
        auth file content
    '

    echo $secret | kubectl create -f -
    ```

 4. Refer to the created secrets in the `values.yaml`
    <details>
    <summary><code>values.yaml</code></summary>

    ```yaml
    # Replica
    replica:
      count: 2

    # StatefulSet
    statefulSet:
      ordinalsStart: 1

    # Service account
    serviceAccount:
      create: true
      rbac:
        create: true

    # Archivist
    archivist:
      # In case we would like to pass more than one bootstrap node
      args:
      - archivist
      - persistence
      - prover
      - --bootstrap-node=spr:xxx
      - --bootstrap-node=spr:yyy
      env:
        ARCHIVIST_LOG_LEVEL: TRACE
        ARCHIVIST_METRICS: true
        ARCHIVIST_METRICS_ADDRESS: 0.0.0.0
        ARCHIVIST_METRICS_PORT: 8008
        ARCHIVIST_DATA_DIR: /data
        ARCHIVIST_API_BINDADDR: 0.0.0.0
        ARCHIVIST_API_PORT: 8080
        ARCHIVIST_STORAGE_QUOTA: 18gb
        ARCHIVIST_BLOCK_TTL: 1d
        ARCHIVIST_BLOCK_MI: 10m
        ARCHIVIST_BLOCK_MN: 1000
        # port values will be set dynamically for each replica, base on data from service.transport
        ARCHIVIST_LISTEN_ADDRS: /ip4/0.0.0.0/tcp/8070
        ARCHIVIST_DISC_IP: 0.0.0.0
        # port value will be set dynamically for each replica, base on data from service.discovery
        ARCHIVIST_DISC_PORT: 8090
        # In case of single SPR, you can set it via var
        # ARCHIVIST_BOOTSTRAP: "spr:xxx"
        ARCHIVIST_MARKETPLACE_ADDRESS: 0x1234567890123456789012345678901234567890
        # file name will be used as a secret name to be mounted to the specified path
        # unique key from `archivist-eth-private-key` secret will be used to mach the unique Pod name
        ARCHIVIST_ETH_PRIVATE_KEY: /opt/archivist-eth-private-key
      extraEnv:
        - name: ARCHIVIST_ETH_PROVIDER
          valueFrom:
            secretKeyRef:
              name: archivist-eth-provider
              key: ARCHIVIST_ETH_PROVIDER

    # Pod ports
    ports:
      api:
        enabled: true
        name: api
        containerPort: 8080
      metrics:
        enabled: true
        name: metrics
        containerPort: 8008
      transport:
        enabled: true
        name: libp2p
        containerPort: 8070
      discovery:
        enabled: true
        name: discovery
        containerPort: 8090

    # Service
    service:
      type:
        - service
        - nodeport
      api:
        enabled: true
        port: 8080
      metrics:
        enabled: true
        name: metrics
        port: 8008
      transport:
        enabled: true
        # 30000-32767
        nodePort: 30500
        nodePortOffset: 10
      discovery:
        # 30000-32767
        enabled: true
        nodePort: 30600
        nodePortOffset: 10

    # Ingress
    ingress:
      enabled: true
      class: nginx
      annotations:
        cert-manager.io/cluster-issuer: "letsencrypt-staging"
        nginx.ingress.kubernetes.io/use-regex: "true"
        nginx.ingress.kubernetes.io/rewrite-target: /$2
        nginx.ingress.kubernetes.io/auth-type: basic
        nginx.ingress.kubernetes.io/auth-secret: archivist-api-basic-auth
        nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required - Private Area'
      tls:
        - secretName: api-domain-tld
          hosts:
            - api.domain.tld
      hosts:
        - host: api.domain.tld
          paths:
            - path: /storage
              rewritePath: (/|$)(.*)
              pathType: Prefix
              podName: node

    # Persistence
    persistence:
      enabled: true
      name: data
      size: 20Gi
      retentionPolicy:
        whenDeleted: Delete
    ```
    </details>

    Review and update all settings and pay attention to `archivist.env`, `service` and `ingress`. You also may consider to skip the values which [defaults](values.yaml) suit your needs.

 5. Install helm chart
    ```shell
    helm install -f values.yaml -n archivist-ns archivist ./archivist
    ```

 6. Check that your Archivist nodes up and running and accessible via Ingress
    ```shell
    # Pods
    kubectl get pods -n archivist-ns

    # API
    # storage/node-1
    # storage/node-2

    curl -s -k -u username:password https://api.domain.tld/storage/node-1/api/archivist/v1/debug/info | jq -r
    ```

 7. If we need more replicas, we should
    - Update secrets with the keys for new replicas
    - Update values.yaml with required number of replicas - `replica.count`
    - Upgrade release


## Deployment strategies

 For P2P communication, Archivist require that transport and discovery ports be accessible for direct connection. In that way we may consider two deployment strategies
 - Private - Archivist is accessible only inside the Kubernetes cluster
 - Public - Archivist is accessible to any nodes in the Internet


### Private deployment

 For private deployment, Archivist Pods should announce their private IP's and TCP ports. Because every Pod has unique IP, all Pods can use same TCP/UDP ports which will be directly accessible by other Pods.

 [Name resolution](https://github.com/libp2p/specs/blob/master/addressing/README.md#ip-and-name-resolution) is not yet supported and we can't use [headless service](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services) for P2P communications.

 This type of deployment is mostly useful for in-cluster testing.

 Deployment is considered **Private** when `service.type = [service]`


### Public deployment

 For Public deployment, Archivist Pods should announce Public IP of the Kubernetes workers node on which they are running and TCP/UDP ports should be unique, because [NodePort](https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport) is shared across all nodes in the cluster. This leads to some limitation in case we would like to use a single [StatefulSet](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) with replicas > 1, because there is no native way in Kubernetes to assign dynamically Pods TCP/UDP ports per replica.

 Deployment is considered **Public** when `service.type = [service, nodeport]`


### Replica count

#### Single replica

 - Single StatefulSet is created and by default with index in the name
 - `ClusterIP` service is used for API and Metrics ports
 - In case of the **Public deployment** type, additionally, `NodePort` service will be created
 - App configuration is done only using `values.yaml` and secrets


#### Multiple replicas

 - **Private deployment**
   - Multiple StatefulSets are created to set unique TCP/UDP Pods ports
   - A separate `ClusterIP` service is created for every Pod API and Metrics ports
   - P2P communication is done directly via Pods IPs
   - App configuration is done using `values.yaml` and secrets

 - **Public deployment**
   - Multiple StatefulSets are created to set unique TCP/UDP Pods ports
   - A separate `ClusterIP` service is created for every Pod API and Metrics ports
   - `NodePort` service is created for every Pod with unique TCP/UDP ports
   - App configuration is done using `values.yaml` and secrets


### Knows issues
 1. We can deploy just one replica per installation in case of `NodePort`, because
    - In Kubernetes, we can't set different settings for replicas in StatefulSet
    - Even if we can workaround that by passing environment variables via `init-env` init container, Pods ports, in the manifest, also should be unique because Archivist has `--listen-addrs` and `--disc-port` for P2P communication and they should be same as `NodePort` and unique for every Pod

    We can workaround that by passing unique TCP/UDP ports using `init-env` init container and port forwarder sidecar and we will consider to implement that later.

    Even if we can use a single StatefulSet for **Private deployment** with `init-env` init container to pass unique sensitive data, it was decided to follow same approach as we use for **Public** one. We may consider to change that later.

    This is why, for now, we have an option `replica.count` to generate multiple StatefulSets with unique settings.

 2. When we deploy multiple nodes using single installation, multiple StatefulSets will be created. During release upgrade all of them will be upgraded/restarted almost simultaneously.

 3. Archivist erasure codding is working on the main app thread and it results of the failed liveness/readiness probes. This is why we have high values by default for these probes.


### Prettify

 Because we are forced to deploy multiple StatefulSets with unique settings, we add a replica index to their names. As a result we will get names which contains additionally Pod index and this is why we've introduced `prettify` key to the StatefulSet, Service and Ingress and `ordinalsStart` for StatefulSet which affect how these names will looks like.

| Object      | Accept `prettify`  | Single                    | Single, `prettify`     | Multiple                                       | Multiple, `prettify`                                       | Single --> Multiple               |
| ----------- | ------------------ | ------------------------- | ---------------------- | ---------------------------------------------- | ---------------------------------------------------------- | --------------------------------- |
| StatefulSet | :white_check_mark: | `archivist-1`             | `archivist`            | `archivist-1`<br>`archivist-2`                         | `archivist-1`<br>`archivist-2`                     | Destructive in case of `prettify` |
| Pod         | :x:                | `archivist-1-1`           | `archivist-1`          | `archivist-1-1` <br> `archivist-2-1`                   | `archivist-1-1` <br> `archivist-2-1`               | Destructive in case of `prettify` |
| PVC         | :x:                | `data-archivist-1-1`      | `data-archivist-1`     | `data-archivist-1-1` <br> `data-archivist-2-1`         | `data-archivist-1-1` <br> `data-archivist-2-1`     | Destructive in case of `prettify` |
| Service     | :white_check_mark: | `archivist-1-1-nodeport`  | `archivist-nodeport`   | `archivist-1-1-nodeport` <br> `archivist-2-1-nodeport` | `archivist-1-nodeport` <br> `archivist-2-nodeport` | Non destructive                   |
| Ingress     | :white_check_mark: | `/archivist-1-1`          | `/archivist`           | `/archivist-1-1` <br> `/archivist-2-1`                 | `/archivist-1` <br> `/archivist-2`                 | Non destructive                   |


The idea is to make endpoint appropriate to the StatefulSet name by removing Pod index in case of multiple StatefulSets.

For StatefulSet, `prettify=false` by default, in order to be able to add more replicas without destroying the fist one, when just one is deployed initially. With that value, a replica index will be added to the the StatefulSet, even if `replica=1`. If you would like to run just a single replica and have a name without that index, you should set `statefulSet.prettify=true`.


## Development

```shell
# Render chart templates
helm template archivist-bootstrap archivist -n archivist-ns --debug

# Pass values
helm template archivist-bootstrap archivist -n archivist-ns --debug --set replica.count=3

# Specific template
helm template archivist-bootstrap archivist -n archivist-ns --debug -s templates/service.yaml

# Examine a chart for possible issues
helm lint archivist

# Check the manifest
helm install archivist --dry-run archivist --namespace archivist-ns
helm install archivist --dry-run=server archivist --namespace archivist-ns
```


## To do
 1. Make code more reusable.
 2. Check options to deploy a separate bootstrap node and get its SPR automatically and pass it to Storage nodes, to setup an in-cluster fully working environment.
 3. Consider to use a single StatefulSet for **Private deployment** with the help of `init-env` init container.
 4. Consider to add a port forwarder as a sidecar to implement single StatefulSet configuration with the help of `init-env` init container for **Public deployment**.
 5. Consider to add an option to use Deployment instead of StatefulSet.
