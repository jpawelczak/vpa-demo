# Introducing new VPA into GKE
With the [VerticalPodAutoscaler InPlaceOrRecreate (VPA IPPR) mode (Public Preview)](https://cloud.google.com/kubernetes-engine/docs/concepts/verticalpodautoscaler), now you can benefit from no-to-low disruptive vertical auto scaling starting from GKE 1.34.0-gke.2201000.

# Automated Workload Rightsizing with GKE VPA IPPR
In this demo, we will use VPA as automated workload rightsizing. We will create the following:

* `vpa-demo-app` Deployment
* `vpa-demo-service` Service
* `vpa-demo` VerticalPodAutoscaler with the new `InPlaceOrRecreate` mode

# Setting up VPA on GKE Standard Cluster

Firstly, let's create GKE Standard Cluster with enabled VPA:
```
gcloud container clusters create stnd-rapid-vpa-demo \
    --location=us-east1 \
    --project=<you-project-ID> \
    --enable-vertical-pod-autoscaling
    --release-channel=rapid
```

As you may notice, with [GKE managed VPA](https://cloud.google.com/kubernetes-engine/docs/concepts/verticalpodautoscaler) you get the VerticalPodAutoscaler capabilities with no-to-minimum cluster-level configurations.

### New VPA InPlaceOrRecreate mode
Now let's go through the new VPA's `InPlaceOrRecreate` mode that allows VPA to adjust resources in-place, without recreating pods improving workload reliability.

Firstly, lets deploy all the manifests:
```
kubectl apply -f manifests
```

VPA with `InPlaceOrRecreate` mode looks like this (/manifests/vpa.yaml):
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

After some time from deploying the vpa-demo-app workload, check VPA configuration:
```
kubectl get vpa
```

This is what you should see:
```
NAME       MODE                CPU   MEM       PROVIDED   AGE
vpa-demo   InPlaceOrRecreate   1m    2097152   True       8m45s
```
Once you see "PROVIDED" as `True` as in the above example, it means VPA is up and running for the workload.

### VPA's in-place resizing with ContainerResourcePolicy

Now, let's check VPA's recommendations about container-level CPU and Mem resources:
```
kubectl describe vpa vpa-demo
```

Have you noticed `Message: Some containers have a small number of samples` and `Type: LowConfidence`? It means VPA does not have enough data sample to make a relevant recommendation, as we deployed VPA for a new workload (no historic data available). To set resources on a level required to maintain reliability of the workload, let's use VPA's `ContainerResourcePolicy` ([details](https://cloud.google.com/kubernetes-engine/docs/concepts/verticalpodautoscaler#containerresourcepolicy_v1_autoscalingk8sio)).

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
          cpu: 250m
          memory: 512Mi
        maxAllowed:
          cpu: 500m
          memory: 512Mi
```

Once applied `ContainerResourcePolicy` for vpa-demo-app by running `kubectl apply -f vpa-resource-policy.yaml`, you will notice that VPA resizes the pods in-place to CPU 250m - our minimum CPU to maintain workload's reliability.

Now, let's check VPA's recommendations about container-level CPU and Mem resources (`kubectl describe vpa vpa-demo`):
```
.....
```

After 1-2 weeks of gathering resource utilization data, we can revisit the VPA's recommendations and update the `ContainerResourcePolicy` accordingly.

# In-place resizing events

Once VPA InPlaceOrRecreate applies changes, you can check in-place scaling events in "Pod details" page, Events tab:
![Screenshot of in-place scaling events](vpa-ippr-event.png)

# Summary

With VPA's `InPlaceOrRecreate` mode you can benefit from no-to-low disruptive vertical auto scaling for automated workload rightsizing:
1. Apply VPA `InPlaceOrRecreate` mode for a workload with minAllowed and maxAllowed values defined in `ContainerResourcePolicy` ([mind GKE Autopilot's min and ratio resource contrains](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-resource-requests)) - VPA gathers resource usage data while keeping minimum resources required for reliable workload operation.
2. Once you gather more resource utilization data, update the `ContainerResourcePolicy` accordingly - let VPA actuate the resources in-place within minAllowed and maxAllowed boundries, so that you can focus on other aspects while improving workload's resource utilization is managed automatically by the VPA IPPR.
