# VPA Demo
You will learn how to set up VerticalPodAutoscaler (VPA) for your workloads on GKE, best practices and some considerations when using the VPA.

This VerticalPodAutoscaler (VPA) demo uses a modified version of the [HorizontalPodAutoscaler (HPA) Demo](https://github.com/gke-demos/hpa-demo) example from GKE Demos repos.

# Overview
We will create the following resources:

* `vpa-demo-app` Deployment
* `vpa-demo-service` Service
* `vpa-demo` VerticalPodAutoscaler with the new `InPlaceOrRecreate` mode

Firstly, let's create [GKE Autopilot Cluster](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview):
```
gcloud container clusters \
create-auto vpa-demo --region us-central1 \
--cluster-version "1.34.0-gke.2011000" \
--release-channel "rapid"
```
Note: to test VPA in Standard Cluster, remember to enable VPA on the cluster (`--enable-vertical-pod-autoscaling`).

Now lets deploy all the manifests:
```
kubectl apply -f manifests
```

# Setting up VPA on GKE
With [GKE managed VPA](https://cloud.google.com/kubernetes-engine/docs/concepts/verticalpodautoscaler), you get the VerticalPodAutoscaler capabilities with no-to-minimum cluster-level configurations.

### New VPA's mode InPlaceOrRecreate
Now let's go through the new [VPA's InPlaceOrRecreate mode](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler/enhancements/4016-in-place-updates-support) that allows VPA to adjust resources in-place, without restarting pods decreasing services disruptions.

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

### VPA's how-to

Now, let's check VPA's recommendations about container-level CPU and Mem resources:
```
kubectl describe vpa vpa-demo
```

Have you noticed `Message: Some containers have a small number of samples` and `Type: LowConfidence`? It means VPA does not have enough data sample to make an informed recommendation (reminder: VPA generates recommendations based on gathered data over some period of time).

*Remainder* : it is good idea to add some boundries to VPA's recommendations by applying `Resource Policies` with minAllowed and maxAllowed values. It will keep the resources under control (you can add the resource policies in vpa.yaml or via GKE Console UI).

# Scale-up with some load

For generating load, the `load.sh` script is provided.  

It uses the simple load test application [hey](https://github.com/rakyll/hey) to generate load for 2 minutes with .... (*TODO*: examples to be defined).  You can adjust the parameters in the script as you see fit.

# Summary

Due to VPA nature and how it works, it is recommended to follow those steps:
1. Apply VPA for a workload in "Off" mode - it gathers resource usage data.
2. Once you have usage data for few days, change the mode to InPlaceOrRecreate plus add minAllowed and maxAllowed values to keep the resources under control.
3. Let VPA actuate the resources of the deployment in-place, so that you can focus on other aspects while minimizing disruption of the workload.

# Clean-up

If you are done for today, you can remove the manifests:
```
kubectl delete -f manifests
```