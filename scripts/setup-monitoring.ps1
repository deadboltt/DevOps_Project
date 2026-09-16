# =============================================================================
# Automated Prometheus & Grafana Monitoring Stack Setup Script
# =============================================================================

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " [GitOps EKS Platform] Installing Observability Stack  " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# 1. Add Prometheus Community Helm repository
Write-Host "`n[1/4] Adding and updating Prometheus Community Helm repo..." -ForegroundColor Yellow
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 2. Deploy kube-prometheus-stack
Write-Host "`n[2/4] Deploying kube-prometheus-stack in 'monitoring' namespace..." -ForegroundColor Yellow
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --create-namespace `
  --values "$PSScriptRoot\..\monitoring\values.yaml"

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[!] Prometheus stack Helm installation failed. Ensure your Kubernetes cluster is reachable." -ForegroundColor Red
    exit 1
}

# 3. Apply Alert Rules, Alertmanager Config, and Dashboard ConfigMap
Write-Host "`n[3/4] Applying Custom Alert Rules and SRE Golden Signals Dashboard..." -ForegroundColor Yellow
kubectl apply -f "$PSScriptRoot\..\monitoring\prometheus-rules.yaml"
kubectl apply -f "$PSScriptRoot\..\monitoring\alertmanager-config.yaml"
kubectl apply -f "$PSScriptRoot\..\monitoring\dashboard-configmap.yaml"

# 4. Display Access Instructions
Write-Host "`n======================================================" -ForegroundColor Green
Write-Host " [✓] Observability Stack Successfully Deployed!" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host "`nTo access Grafana Dashboards:" -ForegroundColor Cyan
Write-Host "  Command:  kubectl port-forward -n monitoring svc/prometheus-grafana 3001:80" -ForegroundColor White
Write-Host "  URL:      http://localhost:3001" -ForegroundColor Yellow
Write-Host "  User:     admin" -ForegroundColor Yellow
Write-Host "  Pass:     admin" -ForegroundColor Yellow
Write-Host "`nTo access Prometheus Query UI:" -ForegroundColor Cyan
Write-Host "  Command:  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090" -ForegroundColor White
Write-Host "  URL:      http://localhost:9090" -ForegroundColor Yellow
