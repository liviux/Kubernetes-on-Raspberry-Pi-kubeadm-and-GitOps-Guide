#!/bin/bash
echo "=== OBSERVABILITY STACK VERIFICATION ==="

# 1. Prometheus Targets
echo "Checking Prometheus Targets..."
# Port-forward to query internal API
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 > /dev/null 2>&1 &
PID=$!
sleep 3
UP_TARGETS=$(curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length')
kill $PID

if [ "$UP_TARGETS" -gt 0 ]; then
    echo "✅ Prometheus is scraping $UP_TARGETS targets"
else
    echo "❌ Prometheus has 0 targets"
    exit 1
fi

# 2. Loki Log Ingestion
echo "Checking Loki Status..."
kubectl get pods -n monitoring -l app=loki | grep Running > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Loki Database is Running"
else
    echo "❌ Loki is down"
    exit 1
fi

# 3. K8sGPT
echo "Checking AI Diagnostics..."
kubectl get pods -n observability -l app.kubernetes.io/name=k8sgpt-operator | grep Running > /dev/null && echo "✅ K8sGPT Operator is Active"

echo "=== OBSERVABILITY CHECK COMPLETE ==="
