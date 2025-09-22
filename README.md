# VPA Demo

This VerticalPodAutoscaler (VPA) demo uses a modified version of the [HorizontalPodAutoscaler (HPA) Demo](https://github.com/gke-demos/hpa-demo) example from GKE Demos repos. 

It creates the following resources:

* `vpa-demo-app` Deployment
* `vpa-demo-service` Service
* `vpa-demo` VerticalPodAutoscaler with the new `InPlaceOrRecreate` mode

Firstly, let's create GKE Autopilot Cluster:
```
gcloud container clusters \
create-auto vpa-demo --region us-central1 \
--cluster-version "1.34.0-gke.1709000" \
--release-channel "rapid"
```
Note: to test VPA in Standard Cluster, remember to enable VPA on the cluster (`--enable-vertical-pod-autoscaling`).

Now lets deploy the manifests:
```
kubectl apply -f manifests
```

# New VPA's mode InPlaceOrRecreate
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

Now, let's check VPA's recommendations about container-level CPU and Mem resources:
```
kubectl describe vpa vpa-demo
```

Have you noticed `Message: Some containers have a small number of samples` and `Type: LowConfidence`? It means VPA does not have enough data sample to make an informed recommendation (reminder: VPA generates recommendations based on gathered data over some period of time).

Don't want to have too large pods wasting resources? Add some boundries to VPA's recommendations by applying Resource Policies with minAllowed and maxAllowed values. It will keep the resources under control (you can do it in vpa.yaml or via GKE Console UI).

To summerize the VPA part, recommended approach:
1. Apply VPA for a workload in "Off" mode - it gathers resource usage data.
2. Once you have usage data for few days, change the mode to InPlaceOrRecreate plus add minAllowed and maxAllowed values to keep the resources under control.
3. Let VPA actuate the resources of the deployment in-place, so that you can focus on other aspects.

# Generate some load

For generating load, the `load.sh` script is provided.  It uses the simple load test application [hey](https://github.com/rakyll/hey) to generate load for 2 minutes with .... (*TODO*: examples to be defined).  You can adjust the parameters in the script as you see fit.

