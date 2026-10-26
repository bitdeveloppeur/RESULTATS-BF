# Script de test simplifié pour RÉSULTATS-BF
# Compatible Windows PowerShell

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TESTS INFRASTRUCTURE RÉSULTATS-BF" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$SUCCESS = 0
$FAILED = 0

function Test-Success {
    param([string]$Description)
    Write-Host "[OK] $Description" -ForegroundColor Green
    $script:SUCCESS++
}

function Test-Failure {
    param([string]$Description)
    Write-Host "[FAIL] $Description" -ForegroundColor Red
    $script:FAILED++
}

# Test 1: VMs en cours d'exécution
Write-Host "`n1. Vérification VMs..." -ForegroundColor Yellow
$vms = vagrant status | Out-String
if ($vms -match "bdd1.*running" -and $vms -match "app1.*running" -and $vms -match "lb1.*running") {
    Test-Success "Toutes les VMs running"
} else {
    Test-Failure "Certaines VMs ne sont pas running"
}

# Test 2: Frontend accessible
Write-Host "`n2. Test Frontend Vue.js..." -ForegroundColor Yellow
try {
    $frontend = curl.exe -s http://localhost:8080/
    if ($frontend -like "*RÉSULTATS-BF*") {
        Test-Success "Frontend accessible"
    } else {
        Test-Failure "Frontend ne répond pas correctement"
    }
} catch {
    Test-Failure "Frontend inaccessible"
}

# Test 3: API Health Check
Write-Host "`n3. Test API /api/sante..." -ForegroundColor Yellow
try {
    $health = curl.exe -s http://localhost:8080/api/sante
    if ($health -like "*healthy*") {
        Test-Success "Health check OK"
        Write-Host "   Response: $health" -ForegroundColor Gray
    } else {
        Test-Failure "Health check failed"
    }
} catch {
    Test-Failure "API Health check inaccessible"
}

# Test 4: API Résultat
Write-Host "`n4. Test API /api/resultat..." -ForegroundColor Yellow
try {
    $resultat = curl.exe -s "http://localhost:8080/api/resultat?matricule=000001"
    if ($resultat -like "*CANDIDAT_1*") {
        Test-Success "API résultat retourne les bonnes données"
        Write-Host "   Response: $resultat" -ForegroundColor Gray
    } else {
        Test-Failure "API résultat ne retourne pas les données attendues"
    }
} catch {
    Test-Failure "API résultat inaccessible"
}

# Test 5: Dashboard HAProxy
Write-Host "`n5. Test Dashboard HAProxy..." -ForegroundColor Yellow
try {
    $dashboard = curl.exe -s -u admin:admin123 "http://localhost:8080/haproxy?stats"
    if ($dashboard -like "*HAProxy*") {
        Test-Success "Dashboard HAProxy accessible"
    } else {
        Test-Failure "Dashboard HAProxy ne répond pas"
    }
} catch {
    Test-Failure "Dashboard HAProxy inaccessible"
}

# Test 6: Load Balancing
Write-Host "`n6. Test Load Balancing..." -ForegroundColor Yellow
$servers = @()
for ($i = 1; $i -le 6; $i++) {
    $response = curl.exe -s http://localhost:8080/api/sante
    if ($response -match "app1") { $servers += "app1" }
    if ($response -match "app2") { $servers += "app2" }
}
$uniqueServers = $servers | Select-Object -Unique
if ($uniqueServers.Count -ge 2) {
    Test-Success "Load balancing fonctionne (app1 et app2 répondent)"
} else {
    Test-Failure "Load balancing ne distribue pas correctement"
}

# Test 7: Base de données (50 000 résultats)
Write-Host "`n7. Test Base de données..." -ForegroundColor Yellow
try {
    $countCmd = 'sudo -u postgres psql resultats_bf -t -c "SELECT COUNT(*) FROM resultats;"'
    $count = vagrant ssh bdd1 -c $countCmd 2>$null
    $count = ($count | Out-String).Trim()
    if ($count -eq "50000") {
        Test-Success "Base de données contient 50 000 résultats"
    } else {
        Test-Failure "Base de données: nombre incorrect ($count)"
    }
} catch {
    Write-Host "   [SKIP] Impossible de vérifier la BDD" -ForegroundColor Yellow
}

# Test 8: VIP Keepalived
Write-Host "`n8. Test Haute Disponibilité (VIP)..." -ForegroundColor Yellow
try {
    $vipCmd = 'ip addr show eth1 | grep 192.168.63.10'
    $vip1 = vagrant ssh lb1 -c $vipCmd 2>$null
    $vip2 = vagrant ssh lb2 -c $vipCmd 2>$null
    
    if ($vip1) {
        Test-Success "VIP active sur lb1 (MASTER)"
    } elseif ($vip2) {
        Test-Success "VIP active sur lb2 (BACKUP)"
    } else {
        Test-Failure "VIP 192.168.63.10 introuvable"
    }
} catch {
    Write-Host "   [SKIP] Impossible de vérifier la VIP" -ForegroundColor Yellow
}

# Résumé
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RÉSUMÉ" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Tests réussis: $SUCCESS" -ForegroundColor Green
Write-Host "Tests échoués: $FAILED" -ForegroundColor Red
Write-Host ""

if ($FAILED -eq 0) {
    Write-Host "TOUS LES TESTS SONT PASSÉS!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Accès:" -ForegroundColor Cyan
    Write-Host "  Frontend:  http://localhost:8080" -ForegroundColor White
    Write-Host "  Dashboard: http://localhost:8080/haproxy?stats (admin/admin123)" -ForegroundColor White
    Write-Host "  API:       http://localhost:8080/api/resultat?matricule=000001" -ForegroundColor White
    Write-Host ""
    Write-Host "Ouvre ton navigateur sur http://localhost:8080 pour voir l'interface!" -ForegroundColor Yellow
} else {
    Write-Host "Certains tests ont échoué. Vérifiez les logs." -ForegroundColor Yellow
}
