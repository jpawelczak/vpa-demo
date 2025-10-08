# Introducing new VPA into GKE
With the [VerticalPodAutoscaler InPlaceOrRecreate (VPA IPPR) mode](https://cloud.google.com/kubernetes-engine/docs/concepts/verticalpodautoscaler) in Public Preview, now you can benefit from no-to-low disruptive vertical auto scaling by starting from GKE 1.34.0-gke.2201000:

* automating stateless workload rightsizing without downtime
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
    --project=<you-project-ID> \
    --enable-vertical-pod-autoscaling
    --release-channel=rapid
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

Have you noticed `Message: Some containers have a small number of samples` and `Type: LowConfidence`? It means VPA does not have enough data sample to make an relevant recommendation - let's use VPA's `ContainerResourcePolicy` to easily demonstrate the in-place resizing capabilities of the new VPA `InPlaceOrRecreate` mode.

### VPA's in-place resizing - a quick demo

To observe how a container is resized in-place, you can apply `ContainerResourcePolicy` ([details](https://cloud.google.com/kubernetes-engine/docs/concepts/verticalpodautoscaler#containerresourcepolicy_v1_autoscalingk8sio)) for vpa-demo-app by running `kubectl apply -f vpa-resource-policy.yaml`, you will notice that VPA scales-up the pods to CPU 550m without recreating the pods. 

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
        controlledResources: ["cpu", "memory"]
        mode: Auto
        minAllowed:
          cpu: 350m
          memory: 512Mi
        maxAllowed:
          cpu: 350m
          memory: 512Mi
```

Now lets check the vpa configuration (`kubectl get vpa`):
```
NAME        MODE                CPU    MEM      PROVIDED   AGE
vpa-demo    InPlaceOrRecreate   350m   512Mi    True       43h
```

Now lets check pod's allocated resources:
```
  containerStatuses:
  - allocatedResources:
      cpu: 350m
      ephemeral-storage: 1Gi
      memory: 512Mi
    containerID: containerd://8f7ab8659163c15eff15f2fe37a7d8e6f2e0d0422a0b717aec937ed21daf4ec1
    image: us-docker.pkg.dev/gke-demos-345619/gke-demos/hpa-demo:latest
    imageID: us-docker.pkg.dev/gke-demos-345619/gke-demos/hpa-demo@sha256:2f5c45c3198b6340bbb7c02a5bae978f7e5e117e5c214c93dd2018c8485f2eff
    lastState: {}
    name: vpa-demo-app
    ready: true
    resources:
      limits:
        cpu: 350m
        ephemeral-storage: 1Gi
        memory: 512Mi
      requests:
        cpu: 350m
        ephemeral-storage: 1Gi
        memory: 512Mi
    restartCount: 0
```

Run `kubectl get pods` to check the pods' `RESTARTS` and `AGE`.

Next, modify minAllowed and maxAllowed part of the yaml, redeploy it by running `kubectl apply -f vpa-resource-policy.yaml` again and check how VPA with in-place resizing works for varius scenarios.

Once VPA InPlaceOrRecreate applied changes, you can spot in-place scaling events in "Pod details" page, Event tab:
![Screenshot of in-place scaling events](vpa-ippr-event.png)

### VPA's in-place resizing - longer path (work-in-progress)

**TODO**: we will add further steps to the demo in next iterations of the VPA Demo.

Let's generate some data to help VPA prepare more relevant recommendations. 

For generating load, the `load.sh` script is provided. It uses the simple load test application [hey](https://github.com/rakyll/hey) to generate load for 120 minutes with .... (*TODO*: examples to be defined).  You can adjust the parameters in the script as you see fit.

After few few hours running the [hey](https://github.com/rakyll/hey) app, let's check VPA's recommendations again:
```
kubectl describe vpa vpa-demo
```

# Setting up VPA on GKE Autopilot Cluster

Firstly, let's create GKE Autopilot Cluster (enabled VPA by default):
```
gcloud container clusters create-auto auto-rapid-vpa-demo \
    --location=us-east1 \
    --project=<you-project-ID> \
    --release-channel=rapid
```

Now lets deploy all the manifests:
```
kubectl apply -f manifests
```

Now let's see how Autopilot assigns more resources. To make it strightforward, apply the `ContainerResourcePolicy` for vpa-demo-app by running `kubectl apply -f vpa-resource-policy.yaml`. It increases CPU from 250m to 350m - VPA will update allocated resources to meet the minimum CPU defined in the `ContainerResourcePolicy`. 

Now decrease CPU from 350m to 300m by modifing minAllowed and maxAllowed in `vpa-resource-policy.yaml` (or edit it via GCP Console User Interface). This time, the system will decrease CPU from 350m to 300m.

**IMPORTANT NOTE**: when testing VPA InPlaceOrRecreate mode, mind that VPA will fallback to *recreating* pods to apply bigger changes, including applying [Autopilot's minimum resources and CPU:Mem ratio constrains](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-resource-requests) (as in the current behavior of Auto or Recreate mode) - that is known limitation of the VPA IPPR Public Preview release.

# Q&A

Q: After applying `ContainerResourcePolicy` to a vpa-demo-app, how long it takes for VPA to apply the minAllowed values? <br>
A: The minAllowed will be incorporated right away to cap the value of the recommendation. The recommendation will be applied if the existing usage falls outside of the lower or upper bounds of the recommended resources. If minAllowed is set to a value above the existing utilization, VPA will try to apply the recommendation right away. There are multiple factors that may cause it to not be successful (e.g., PDBs, etc)

Q: For new workloads (without usage data), what is the minimum time a CPU increase must be seen before VPA apply new recommendation? <br>
A: At least a couple of minutes. The recommendation will be applied if the existing usage falls outside of the lower or upper bounds of the recommended resources. A recommendation will start with very very wide ranges (called low confidence recommendation) to avoid a quick eviction. And the range will narrow as time goes by (VPA gets a high confidence recommendation after ~a week worth of data, in which the interval is narrow enough).

Q: When workload is running for a some time, how long it takes for VPA to apply recommandations after difference in cpu usage? <br>
A: Very similar to the question above. If the CPU usage goes outside of the interval, VPA will evict it right away (considering no PDBs, etc).

# Want even better cost control? (work-in-progress)

**TODO**: We will explore further availale options in next iterations of the VPA Demo.

As presented earlier, it is a good idea to add some boundries to VPA's recommendations by applying `ContainerResourcePolicy` with minAllowed and maxAllowed values. It will keep container's resources under control.

# Summary

With VPA's  `InPlaceOrRecreate` mode is recommended to follow those steps:
1. Apply VPA `InPlaceOrRecreate` mode for a workload with minAllowed and maxAllowed values defined in `ContainerResourcePolicy` (mind GKE Autopilot's min resources contrains) - the VPA gathers resource usage data while keeping minimum resources required for reliable workload operation.
2. Once you gather more data, update the `ContainerResourcePolicy` accordingly - let VPA actuate the resources in-place, so that you can focus on other aspects while improving costs and reliability of the workload is managed automatically by the VPA IPPR.
