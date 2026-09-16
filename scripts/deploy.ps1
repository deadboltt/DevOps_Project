# =============================================================================
# Automated Safe Deployment Script for GitOps EKS Platform
# =============================================================================

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " [GitOps EKS Platform] Starting Terraform Deployment   " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

Set-Location -Path "$PSScriptRoot\..\terraform"

Write-Host "`n[1/3] Initializing Terraform Providers & Modules..." -ForegroundColor Yellow
terraform init

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[!] Terraform init failed. Please check errors above." -ForegroundColor Red
    exit 1
}

Write-Host "`n[2/3] Validating Configuration..." -ForegroundColor Yellow
terraform validate

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[!] Terraform validation failed." -ForegroundColor Red
    exit 1
}

Write-Host "`n[3/3] Generating Execution Plan & Applying..." -ForegroundColor Yellow
terraform apply -auto-approve

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[✓] EKS Cluster successfully provisioned!" -ForegroundColor Green
    $clusterName = terraform output -raw cluster_name
    $region = terraform output -raw aws_region

    Write-Host "`nUpdating local kubeconfig..." -ForegroundColor Cyan
    aws eks update-kubeconfig --region $region --name $clusterName

    Write-Host "`nVerifying cluster connection:" -ForegroundColor Green
    kubectl get nodes
} else {
    Write-Host "`n[!] Terraform apply encountered an error." -ForegroundColor Red
}
