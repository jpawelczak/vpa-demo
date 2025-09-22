#!/bin/sh

#20 workers for 2 min
#kubectl run -i --tty --rm hey --image us-docker.pkg.dev/gke-demos-345619/hey/hey --restart=Never --  -c 20 -z 2m  http://vpa-demo-service

#100 requests for 2 min
echo "starting test of 50 requests for 2 min"

kubectl run -i --tty --rm hey --image us-docker.pkg.dev/gke-demos-345619/hey/hey --restart=Never --  -n 400 -z 2m  http://vpa-demo-service
