---
title: "Pre-pulling k8s images"
date: "2024-11-13T20:07:14+01:00"
tags:
  - k8s
---

I was surprised to learn that Kubernetes doesn't include a built-in mechanism to pre-pull images before initiating a deployment rollout.
In my mind, it makes perfect sense to pull the image before any other action.

Of course, this choice aligns with the Kubernetes philosophy of managing stateless,
ephemeral workloads where multiple replicas and nodes are expected to mitigate
the impact of pod startup times.

However, in real-world scenarios, conditions are often less than ideal. I'm
sure that this won't be the last time that I encounter a single-replica application
with frequent updates that requires the fastest possible pod startup time.

## Solutions

I've seen people run `DaemonSets` to pre-pull the images, use cache registries
or even deploy operators that manage multiple-image caches.

Here are some examples:

- [kube-fledged](https://github.com/senthilrch/kube-fledged)
- [kubernetes-image-puller](https://github.com/che-incubator/kubernetes-image-puller)

## Naive implementation using a DaemonSet

I want to demonstrate now how to implement an image pre-puller using a `DaemonSet`,
mainly because it’s a fun solution to try out!

I'll also track the startup time of the pods to see how effective this approach can be.

### Test deployment

Our initial deployment consists of 3 replicas. At startup, each replica
generates a file at `/tmp/start.txt` containing the current timestamp to track
the startup time. We'll change the image later on.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: my-deployment
  name: my-deployment
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-deployment
  template:
    metadata:
      labels:
        app: my-deployment
    spec:
      containers:
        - name: app
          image: busybox:latest
          command:
            - /usr/bin/env
          args:
            - sh
            - -c
            - date +%s > /tmp/start.txt; while true; do sleep 10; done
```

Let's apply the deployment and check the startup time.

```sh
$ kubectl apply -f deployment.yaml
```

To check the startup time I'll use the following bash script (`check-startup-time.sh`):

```bash
#!/usr/bin/env bash
set -eu -o pipefail

namespace="default"
pod_selector="app=my-deployment"

kubectl get pods \
    --namespace "$namespace" \
    --selector "$pod_selector" \
    -o jsonpath='{range .items[*]}{.metadata.name} {.spec.containers[0].image} {.spec.nodeName} {.metadata.creationTimestamp}{"\n"}{end}' |
    while read -r pod img node ts; do
        startTimestamp="$(kubectl exec "$pod" -- head -1 /tmp/start.txt)"
        creationTimestamp="$(date --date="$ts" +'%s')"
        echo "Pod '$pod' ($img) on node '$node' started in $((startTimestamp - creationTimestamp)) seconds"
    done
```

If we run the script we get the following:

```sh
$ ./check-startup-time.sh
Pod 'my-deployment-db7577cf4-srjpf' (busybox:latest) on node 'worker01' started in 4 seconds
Pod 'my-deployment-db7577cf4-vgnbd' (busybox:latest) on node 'worker02' started in 3 seconds
Pod 'my-deployment-db7577cf4-wjz22' (busybox:latest) on node 'worker02' started in 4 seconds
```

Of course, the busybox image is pretty lightweight:

```sh
$ crictl --image-endpoint unix:///run/containerd/containerd.sock images | grep busy
docker.io/library/busybox           latest              27a71e19c9562       2.17MB
```

### DaemonSet pre-puller

Let's also create the `DaemonSet` that will be in charge of pre-pulling the images.
For the moment, using the same busybox image.

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: pre-pull
  namespace: default
spec:
  selector:
    matchLabels:
      name: pre-pull
  template:
    metadata:
      labels:
        name: pre-pull
    spec:
      initContainers:
        - name: pre-pull
          image: busybox:latest
          command: ["/usr/bin/env"]
          args: ["true"]

      containers:
        # Pause container to keep it running with the lowest resource consumption possible
        - name: pause
          image: gcr.io/google-containers/pause:latest
      tolerations:
        # these tolerations are to have the daemonset runnable on control plane nodes
        # remove them if your control plane nodes should not run pods
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
        - key: node-role.kubernetes.io/master
          operator: Exists
          effect: NoSchedule
      terminationGracePeriodSeconds: 5
```

```sh
$ kubectl apply -f pre-pull-ds.yaml
```

### Deploying a heavier image

Now, let’s test with a heavier image. Imagine we’re deploying a new version
of a critical single-replica app that needs to be up and running as fast as possible.

To simulate this, I'll update our deployment's image:

```sh
$ kubectl set image deployment my-deployment app=archlinux:multilib-devel
```

After the rollout completes, check the startup times:

```sh
❯ ./check-startup-time.sh
Pod 'my-deployment-7f44948958-95qh9' (archlinux:multilib-devel) on node 'worker01' started in 3 seconds
Pod 'my-deployment-7f44948958-db988' (archlinux:multilib-devel) on node 'worker02' started in 41 seconds
Pod 'my-deployment-7f44948958-mmv8q' (archlinux:multilib-devel) on node 'worker01' started in 32 seconds
```

As you can see the startup time increased by around 10x on nodes where
the image wasn't already pulled. And this is "only" with 322MB, I've seen
worse ;)

```sh
$ crictl --image-endpoint unix:///run/containerd/containerd.sock images  | grep archlinux
docker.io/library/archlinux         multilib-devel      e6ea8b8396eac       322MB
```

### Trying the pre-puller DaemonSet

First, let's cleanup the environment.

Reset the deployment's image:

```sh
$ kubectl set image deployment my-deployment app=busybox:latest
```

Then, delete the image from all the worker nodes to ensure it's not cached:

```sh
$ crictl --image-endpoint unix:///run/containerd/containerd.sock rmi docker.io/library/archlinux:multilib-devel
Deleted: docker.io/library/archlinux:multilib-devel
```

Next, we'll run a set of commands that could easily be part of a CI pipeline.

```sh
# Update the pre-pull DS with the new image
$ kubectl set image daemonset pre-pull pre-pull=archlinux:multilib-devel
daemonset.apps/pre-pull image updated
```

```sh
# Wait for the rollout to complete
$ kubectl rollout status daemonset pre-pull --timeout 120s
Waiting for daemon set "pre-pull" rollout to finish: 1 out of 3 new pods have been updated...
Waiting for daemon set "pre-pull" rollout to finish: 1 out of 3 new pods have been updated...
Waiting for daemon set "pre-pull" rollout to finish: 2 out of 3 new pods have been updated...
Waiting for daemon set "pre-pull" rollout to finish: 2 out of 3 new pods have been updated...
Waiting for daemon set "pre-pull" rollout to finish: 2 of 3 updated pods are available...
daemon set "pre-pull" successfully rolled out
```

```sh
# Update our deployment with the new image
$ kubectl set image deployment my-deployment app=archlinux:multilib-devel
deployment.apps/my-deployment image updated
```

Finally, check the startup time of the pods.

```sh
$ ./check-startup-time.sh
Pod 'my-deployment-7f44948958-w4fbn' (archlinux:multilib-devel) on node 'worker01' started in 5 seconds
Pod 'my-deployment-7f44948958-wjjcs' (archlinux:multilib-devel) on node 'worker01' started in 3 seconds
Pod 'my-deployment-7f44948958-wvpck' (archlinux:multilib-devel) on node 'worker02' started in 3 seconds
```

Much better! =)
