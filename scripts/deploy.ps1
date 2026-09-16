# =============================================================================
# Automated Safe Deployment Script for GitOps EKS Platform
# =============================================================================

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " [GitOps EKS Platform] Starting Terraform Deployment   " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

Set-Location -Path "$PSScriptRoot\..\terraform"

Write-Host ""
Write-Host "[1/3] Initializing Terraform Providers and Modules..." -ForegroundColor Yellow
terraform init

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[!] Terraform init failed. Please check errors above." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[2/3] Validating Configuration..." -ForegroundColor Yellow
terraform validate

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[!] Terraform validation failed." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[3/3] Generating Execution Plan and Applying..." -ForegroundColor Yellow
terraform apply -auto-approve

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[SUCCESS] EKS Cluster successfully provisioned!" -ForegroundColor Green
    $clusterName = terraform output -raw cluster_name
    $region = terraform output -raw aws_region

    Write-Host ""
    Write-Host "Updating local kubeconfig..." -ForegroundColor Cyan
    aws eks update-kubeconfig --region $region --name $clusterName

    Write-Host ""
    Write-Host "Verifying cluster connection:" -ForegroundColor Green
    kubectl get nodes
} else {
    Write-Host ""
    Write-Host "[!] Terraform apply encountered an error." -ForegroundColor Red
}
