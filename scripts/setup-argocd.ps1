# =============================================================================
# Automated ArgoCD GitOps Controller Setup Script
# =============================================================================

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " [GitOps EKS Platform] Installing ArgoCD Controller    " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# 1. Add ArgoCD official Helm repository
Write-Host "`n[1/5] Adding and updating ArgoCD Helm repository..." -ForegroundColor Yellow
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# 2. Install ArgoCD via Helm
Write-Host "`n[2/5] Deploying ArgoCD in the 'argocd' namespace..." -ForegroundColor Yellow
helm upgrade --install argo-cd argo/argo-cd `
  --namespace argocd `
  --create-namespace `
  --values "$PSScriptRoot\..\gitops\argocd-values.yaml"

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[!] ArgoCD Helm installation failed. Ensure your Kubernetes cluster is running and kubectl is connected." -ForegroundColor Red
    exit 1
}

# 3. Wait for ArgoCD server to be ready
Write-Host "`n[3/5] Waiting for ArgoCD Server to become ready..." -ForegroundColor Yellow
kubectl wait --namespace argocd `
  --for=condition=ready pod `
  --selector=app.kubernetes.io/name=argocd-server `
  --timeout=180s

# 4. Apply AppProject and Application Manifests
Write-Host "`n[4/5] Applying ArgoCD AppProject and Application manifests..." -ForegroundColor Yellow
kubectl apply -f "$PSScriptRoot\..\gitops\project.yaml"
kubectl apply -f "$PSScriptRoot\..\gitops\application.yaml"

# 5. Extract Admin Password
Write-Host "`n[5/5] Extracting initial ArgoCD admin password..." -ForegroundColor Yellow
$adminPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
if ($adminPassword) {
    $decodedPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($adminPassword))
    Write-Host "`n======================================================" -ForegroundColor Green
    Write-Host " [✓] ArgoCD Successfully Installed & Synchronized!" -ForegroundColor Green
    Write-Host "======================================================" -ForegroundColor Green
    Write-Host " UI Access URL:   https://localhost:8080" -ForegroundColor Cyan
    Write-Host " Username:        admin" -ForegroundColor Cyan
    Write-Host " Password:        $decodedPassword" -ForegroundColor Yellow
    Write-Host "======================================================" -ForegroundColor Green
    Write-Host "`nTo access the ArgoCD Web Dashboard, run:" -ForegroundColor Cyan
    Write-Host "kubectl port-forward -n argocd svc/argo-cd-argocd-server 8080:443" -ForegroundColor White
} else {
    Write-Host "`n[!] Admin secret not yet available. Run the following to check:" -ForegroundColor Yellow
    Write-Host "kubectl -n argocd get secret argocd-initial-admin-secret"
}
