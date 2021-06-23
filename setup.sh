# Sources:
# https://redhat-developer-demos.github.io/knative-tutorial/knative-tutorial/eventing/index.html
# https://redhat-developer-demos.github.io/knative-tutorial/knative-tutorial/eventing/eventing-trigger-broker.html#events-triggers-brokers

# Create cluster in kind
kind create cluster --name cloud-cluster --config cloud-cluster-config.yaml

# Installing Knative Serving Component
kubectl apply -f https://github.com/knative/serving/releases/download/v0.23.0/serving-crds.yaml
kubectl apply -f https://github.com/knative/serving/releases/download/v0.23.0/serving-core.yaml
kubectl get pods --namespace knative-serving

# Install istio
kubectl apply -f https://github.com/knative/net-istio/releases/download/v0.23.0/istio.yaml
kubectl apply -f https://github.com/knative/net-istio/releases/download/v0.23.0/net-istio.yaml
kubectl --namespace istio-system get service istio-ingressgateway
kubectl get pods --namespace knative-serving

# Installing Knative Eventing Component
kubectl apply -f https://github.com/knative/eventing/releases/download/v0.23.0/eventing-crds.yaml
kubectl apply -f https://github.com/knative/eventing/releases/download/v0.23.0/eventing-core.yaml
kubectl get pods --namespace knative-eventing

# Create namespace
kubectl create namespace knativetutorial

# Create default broker
kubectl apply -f https://github.com/knative/eventing/releases/download/v0.23.0/in-memory-channel.yaml
kubectl apply --filename https://github.com/knative/eventing/releases/download/v0.23.0/eventing-sugar-controller.yaml
kubectl apply -f https://github.com/knative/eventing/releases/download/v0.23.0/mt-channel-broker.yaml
kubectl apply -n knativetutorial -f default-broker.yaml

# Verify created resources
kubectl get broker.eventing.knative.dev -n knativetutorial
kubectl get channel -n knativetutorial

# Deploy Sinks
docker pull quay.io/rhdevelopers/eventinghello:0.0.2
kind load docker-image quay.io/rhdevelopers/eventinghello:0.0.2 --name cloud-cluster
kubectl apply -n knativetutorial -f eventing-aloha-sink.yaml
kubectl apply -n knativetutorial -f eventing-bonjour-sink.yaml

# Deploy Triggers
kubectl apply -n knativetutorial -f trigger-helloaloha.yaml
kubectl apply -n knativetutorial -f trigger-hellobonjour.yaml

# Verify that the triggers are ready
kubectl --namespace knativetutorial get triggers.eventing.knative.dev

# Verification
kubectl get trigger helloaloha -o jsonpath='{.status.subscriberUri}' -n knativetutorial
kubectl get trigger hellobonjour -o jsonpath='{.status.subscriberUri}' -n knativetutorial
kubectl get broker default -o jsonpath='{.status.address.url}' -n knativetutorial

# Deploy curler service (event source)
kubectl -n knativetutorial apply -f curler.yaml

kubectl -n knativetutorial exec -it curler -- /bin/bash

curl -v "http://eventingaloha.knativetutorial.svc.cluster.local" \
-X POST \
-H "Ce-Id: say-hello" \
-H "Ce-Specversion: 1.0" \
-H "Ce-Type: aloha" \
-H "Ce-Source: mycurl" \
-H "Content-Type: application/json" \
-d '{"key":"from a curl"}'

watch kubectl get pods -n knativetutorial

curl -v "http://eventingbonjour.knativetutorial.svc.cluster.local" \
-X POST \
-H "Ce-Id: say-hello" \
-H "Ce-Specversion: 1.0" \
-H "Ce-Type: bonjour" \
-H "Ce-Source: mycurl" \
-H "Content-Type: application/json" \
-d '{"key":"from a curl"}'

# Delete cluster
kind delete cluster --name cloud-cluster
