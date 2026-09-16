# =============================================================================
# Automated Zero-Leak Teardown Script for GitOps EKS Platform
# =============================================================================
# Run this script to destroy all AWS resources and avoid unexpected charges.

Write-Host "======================================================" -ForegroundColor Red
Write-Host " [CAUTION] Starting Complete AWS Infrastructure Teardown" -ForegroundColor Red
Write-Host "======================================================" -ForegroundColor Red

# [1/3] Delete Kubernetes LoadBalancers first to release AWS ELBs and Subnet ENIs
Write-Host ""
Write-Host "[1/3] Cleaning up Kubernetes LoadBalancer services..." -ForegroundColor Yellow
try {
    kubectl delete svc gitops-microservice-svc -n default --timeout=30s --ignore-not-found=true 2>$null
    kubectl delete svc argo-cd-argocd-server -n argocd --timeout=30s --ignore-not-found=true 2>$null
} catch {
    # Ignored if cluster is unreachable
}

# [2/3] Delete any orphaned AWS Classic Load Balancers
Write-Host ""
Write-Host "[2/3] Checking for remaining AWS Load Balancers..." -ForegroundColor Yellow
$elbs = aws elb describe-load-balancers --region ap-south-1 --query "LoadBalancerDescriptions[*].LoadBalancerName" --output text 2>$null
if ($elbs) {
    foreach ($elb in ($elbs -split '\s+')) {
        if ($elb.Trim()) {
            Write-Host "Deleting orphaned ELB: $elb" -ForegroundColor Yellow
            aws elb delete-load-balancer --load-balancer-name $elb.Trim() --region ap-south-1 2>$null
        }
    }
    Start-Sleep -Seconds 10
}

Set-Location -Path "$PSScriptRoot\..\terraform"

Write-Host ""
Write-Host "[3/3] Destroying EKS Cluster, Worker Nodes, VPC, and NAT Gateways..." -ForegroundColor Yellow
terraform destroy -auto-approve

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[SUCCESS] All cloud resources destroyed successfully. Zero ongoing AWS charges!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[!] Some resources may not have destroyed cleanly. Check the Terraform logs above." -ForegroundColor Red
}
