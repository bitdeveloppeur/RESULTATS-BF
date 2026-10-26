# Script maître - Lance tous les tests (unitaires + intégration)
# Génère un rapport complet

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "      RÉSULTATS-BF - SUITE DE TESTS      " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "Début des tests: $timestamp" -ForegroundColor Gray
Write-Host ""

$allPassed = $true

# ==========================================
# PHASE 1: TESTS UNITAIRES
# ==========================================
Write-Host "┌──────────────────────────────────────────┐" -ForegroundColor Yellow
Write-Host "│    PHASE 1: TESTS UNITAIRES             │" -ForegroundColor Yellow
Write-Host "└──────────────────────────────────────────┘" -ForegroundColor Yellow
Write-Host ""

# Test 1.1: Infrastructure
Write-Host "[1/3] Tests unitaires - Infrastructure..." -ForegroundColor Cyan
$infra = powershell -ExecutionPolicy Bypass -File tests/unit/test-infrastructure.ps1
if ($LASTEXITCODE -ne 0) { $allPassed = $false }
Write-Host ""

# Test 1.2: API
Write-Host "[2/3] Tests unitaires - API..." -ForegroundColor Cyan
$api = powershell -ExecutionPolicy Bypass -File tests/unit/test-api.ps1
if ($LASTEXITCODE -ne 0) { $allPassed = $false }
Write-Host ""

# Test 1.3: Base de données
Write-Host "[3/3] Tests unitaires - Base de données..." -ForegroundColor Cyan
$db = powershell -ExecutionPolicy Bypass -File tests/unit/test-database.ps1
if ($LASTEXITCODE -ne 0) { $allPassed = $false }
Write-Host ""

# ==========================================
# PHASE 2: TESTS D'INTÉGRATION
# ==========================================
Write-Host "┌──────────────────────────────────────────┐" -ForegroundColor Yellow
Write-Host "│    PHASE 2: TESTS D'INTÉGRATION         │" -ForegroundColor Yellow
Write-Host "│    (Scénarios V1-V6)                    │" -ForegroundColor Yellow
Write-Host "└──────────────────────────────────────────┘" -ForegroundColor Yellow
Write-Host ""

Write-Host "⚠️  Les tests d'intégration vont:" -ForegroundColor Yellow
Write-Host "   - Arrêter/redémarrer des VMs" -ForegroundColor Yellow
Write-Host "   - Prendre 5-10 minutes" -ForegroundColor Yellow
Write-Host "   - Modifier l'état de l'infrastructure" -ForegroundColor Yellow
Write-Host ""
Write-Host "Continuer? (o/N): " -ForegroundColor Cyan -NoNewline
$confirm = Read-Host

if ($confirm -eq "o" -or $confirm -eq "O") {
    Write-Host ""
    Write-Host "Lancement tests d'intégration..." -ForegroundColor Cyan
    $integration = powershell -ExecutionPolicy Bypass -File tests/integration/test-scenarios.ps1
    if ($LASTEXITCODE -ne 0) { $allPassed = $false }
} else {
    Write-Host ""
    Write-Host "Tests d'intégration ignorés" -ForegroundColor Yellow
}

# ==========================================
# RAPPORT FINAL
# ==========================================
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "      RAPPORT FINAL - TOUS LES TESTS     " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$endTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "Fin des tests: $endTimestamp" -ForegroundColor Gray
Write-Host ""

if ($allPassed) {
    Write-Host "════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  🎉 TOUS LES TESTS SONT PASSÉS! ✅    " -ForegroundColor Green
    Write-Host "════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Infrastructure prête pour la démonstration!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Accès:" -ForegroundColor Cyan
    Write-Host "  • Frontend:  http://localhost:8080" -ForegroundColor White
    Write-Host "  • Dashboard: http://localhost:8080/haproxy?stats" -ForegroundColor White
    Write-Host "  • API:       http://localhost:8080/api/sante" -ForegroundColor White
    exit 0
} else {
    Write-Host "════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  ⚠️  CERTAINS TESTS ONT ÉCHOUÉ        " -ForegroundColor Yellow
    Write-Host "════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Vérifiez les logs ci-dessus pour plus de détails" -ForegroundColor Yellow
    exit 1
}
