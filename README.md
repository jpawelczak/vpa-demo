# Introducing new VPA into GKE
With the [VerticalPodAutoscaler InPlaceOrRecreate (VPA IPPR) mode](https://cloud.google.com/kubernetes-engine/docs/concepts/verticalpodautoscaler) in Public Preview, now you can benefit from no-to-low disruptive vertical auto scaling by:

* automating stateless workload rightsizing without downtime - we will focus on this use case in this demo
* scaling-up vertically of stateful workloads without downtime
* seamless scale-down when the traffic is low
* automating k8s Jobs rightsizing

You will learn how to set up mode for your workloads on GKE, best practices and some considerations when using the VPA for automated stateless workload rightsizing.

The demo is based on [HPA Demo](https://github.com/gke-demos/hpa-demo) from GKE Demos repo.

# Automated Workload Rightsizing with GKE VPA IPPR
We will create the following:

* `vpa-demo-app` Deployment
* `vpa-demo-service` Service
* `vpa-demo` VerticalPodAutoscaler with the new `InPlaceOrRecreate` mode

We will also apply some boundries to have better control over resource costs.

# Setting up VPA on GKE Standard Cluster

Firstly, let's create GKE Standard Cluster with enabled VPA:
```
gcloud container clusters create stnd-rapid-vpa-demo \
    --location=us-east1 \
    --project=jpawelczak-gke-dev \
    --cluster-version=1.34.0-gke.... \
    --enable-vertical-pod-autoscaling
    --release-channel=RAPID
```

Now lets deploy all the manifests:
```
kubectl apply -f manifests
```

As you may notice, with [GKE managed VPA](https://cloud.google.com/kubernetes-engine/docs/concepts/verticalpodautoscaler) you get the VerticalPodAutoscaler capabilities with no-to-minimum cluster-level configurations.

### New VPA InPlaceOrRecreate mode
Now let's go through the new [VPA's InPlaceOrRecreate mode](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler/enhancements/4016-in-place-updates-support) that allows VPA to adjust resources in-place, without recreating pods improving services reliability.

We deployed /manifests/vpa.yaml:
```
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: vpa-demo
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind:       Deployment
    name:       vpa-demo-app
  updatePolicy:
    updateMode: "InPlaceOrRecreate"  # Use explicit mode instead of deprecated "Auto"
```

After about 3 minutes from applying the manifests, check VPA configuration:
```
kubectl get vpa
```

This is what you should see:
```
NAME       MODE                CPU   MEM       PROVIDED   AGE
vpa-demo   InPlaceOrRecreate   1m    2097152   True       8m45s
```
Once you see "PROVIDED" as `True` as in the above example, it means VPA is up and running.

Now, let's check VPA's recommendations about container-level CPU and Mem resources:
```
kubectl describe vpa vpa-demo
```

Have you noticed `Message: Some containers have a small number of samples` and `Type: LowConfidence`? It means VPA does not have enough data sample to make an relevant recommendation - let's use `ContainerResourcePolicy` to easily demonstrate the in-place resizing capabilities of the new VPA InPlaceOrRecreate mode.

### VPA's in-place resizing - a quick demo

To observe how a container is resized in-place, you can apply `ContainerResourcePolicy` ([details](https://cloud.google.com/kubernetes-engine/docs/concepts/verticalpodautoscaler#containerresourcepolicy_v1_autoscalingk8sio)).

Apply the `ContainerResourcePolicy` for vpa-demo-app by running `kubectl apply -f vpa-resource-policy.yaml`, you will notice that VPA scales-up the pods to CPU 500m and 1000Mi Mem without recreating the pods. 

vpa-resource-policy.yaml looks like this:
```
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: vpa-demo
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind:       Deployment
    name:       vpa-demo-app
  updatePolicy:
    updateMode: "InPlaceOrRecreate"  # Use explicit mode instead of deprecated "Auto"
  resourcePolicy:
    containerPolicies:
      - containerName: 'vpa-demo-app'
        minAllowed:
          cpu: 500m
          memory: 1000Mi
        maxAllowed:
          cpu: 500m
          memory: 1000Mi
        controlledResources: ["cpu", "memory"]
```

Now lets check the vpa configuration (`kubectl get vpa`):
```
NAME        MODE                CPU    MEM      PROVIDED   AGE
vpa-demo    InPlaceOrRecreate   500m   1000Mi   True       43h
```

Now lets check pod's allocated resources:
```
  containerStatuses:
  - allocatedResources:
      cpu: 500m
      ephemeral-storage: 1Gi
      memory: 1000Mi
    containerID: containerd://8f7ab8659163c15eff15f2fe37a7d8e6f2e0d0422a0b717aec937ed21daf4ec1
    image: us-docker.pkg.dev/gke-demos-345619/gke-demos/hpa-demo:latest
    imageID: us-docker.pkg.dev/gke-demos-345619/gke-demos/hpa-demo@sha256:2f5c45c3198b6340bbb7c02a5bae978f7e5e117e5c214c93dd2018c8485f2eff
    lastState: {}
    name: vpa-demo-app
    ready: true
    resources:
      limits:
        cpu: 500m
        ephemeral-storage: 1Gi
        memory: 1000Mi
      requests:
        cpu: 500m
        ephemeral-storage: 1Gi
        memory: 1000Mi
    restartCount: 0
```

Run `kubectl get pods` to check the pods' `RESTARTS` and `AGE`.

Next, modify minAllowed and maxAllowed, redeploy it by running `kubectl apply -f vpa-resource-policy.yaml` again and check how VPA with in-place resizing works for varius scenarios.

### VPA's in-place resizing - longer path

Let's generate some data to help VPA prepare more relevant recommendations. 

For generating load, the `load.sh` script is provided. It uses the simple load test application [hey](https://github.com/rakyll/hey) to generate load for 120 minutes with .... (*TODO*: examples to be defined).  You can adjust the parameters in the script as you see fit.

After few days running the [hey](https://github.com/rakyll/hey) app, let's check VPA's recommendations again:
```
kubectl describe vpa vpa-demo
```

TODO: we will add further steps to the demo in next iterations of the VPA Demo.

# Setting up VPA on GKE Autopilot Cluster

Firstly, let's create GKE Autopilot Cluster (enabled VPA by default):
```
gcloud container clusters create-auto auto-rapid-vpa-demo \
    --location=us-east1 \
    --project=jpawelczak-gke-dev \
    --cluster-version=1.34.0-gke.... \
    --release-channel=RAPID
```

Now lets deploy all the manifests:
```
kubectl apply -f manifests
```

Apply the `ContainerResourcePolicy` for vpa-demo-app by running `kubectl apply -f vpa-resource-policy.yaml`, you will notice that VPA scales-up the workload to CPU 500m and 1000Mi Mem without recreating the pods. After few seconds, run `kubectl get pods` to check the pods' `RESTARTS` and `AGE`.

*IMPORTANT NOTE*: when analyzing VPA's autoscaling events, mind that VPA will *recreate* pods in IPPR mode to apply [Autopilot Cluster minimum resources and CPU:Mem ratio constrains](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-resource-requests) - that is known limitation of the VPA IPPR Public Preview release.

# Want even better cost control?

As presented earlier, it is a good idea to add some boundries to VPA's recommendations by applying `ContainerResource Policy` with minAllowed and maxAllowed values. It will keep container's resources under control.

TODO: We will explore further availale options in next iterations of the VPA Demo.

# Summary

Due to VPA nature and how it works, it is recommended to follow those steps:
1. Apply VPA for a workload in "Off" mode - it gathers resource usage data.
2. Once you have usage data for few days, change the mode to `InPlaceOrRecreate` and apply `ContainerResourcePolicy` to keep the resources under control.
3. Let VPA actuate the resources of the stateless workloads in-place, so that you can focus on other aspects while improving costs and reliability of the workload.

IMPORTANT NOTE: when analyzing VPA's autoscaling events, mind that VPA will *recreate* pods in IPPR mode to apply [Autopilot Cluster minimum resources and CPU:Mem ratio constrains](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-resource-requests) - that is known limitation of the VPA IPPR Public Preview release.

Note: while Autopilot has VPA enabled by default, to test VPA on Standard Cluster you have to enable the VPA (`--enable-vertical-pod-autoscaling`).
