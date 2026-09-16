# =============================================================================
# Automated Zero-Leak Teardown Script for GitOps EKS Platform
# =============================================================================
# Run this script to destroy all AWS resources and avoid unexpected charges.

Write-Host "======================================================" -ForegroundColor Red
Write-Host " [CAUTION] Starting Complete AWS Infrastructure Teardown" -ForegroundColor Red
Write-Host "======================================================" -ForegroundColor Red

Set-Location -Path "$PSScriptRoot\..\terraform"

Write-Host ""
Write-Host "Destroying EKS Cluster, Worker Nodes, VPC, and NAT Gateways..." -ForegroundColor Yellow
terraform destroy -auto-approve

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[SUCCESS] All cloud resources destroyed successfully. Zero ongoing AWS charges!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[!] Some resources may not have destroyed cleanly. Check the Terraform logs above." -ForegroundColor Red
}
