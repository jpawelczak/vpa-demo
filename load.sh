#!/bin/sh

#10 workers for 120 min
echo "starting test of 10 workers for 120 min"

kubectl run -i --tty --rm hey --image us-docker.pkg.dev/gke-demos-345619/hey/hey --restart=Never --  -c 10 -z 120m  http://vpa-demo-service

#TODO: 100 requests during weekday, minimum requests during weekends
