# Script de test complet de l'infrastructure RÉSULTATS-BF
# Compatible Windows PowerShell

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "TESTS INFRASTRUCTURE RÉSULTATS-BF" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$SUCCESS = 0
$FAILED = 0

# Charger les credentials depuis .env ou utiliser les valeurs par défaut
$LB_STATS_USER = if ($env:LB_STATS_USER) { $env:LB_STATS_USER } else { "admin" }
$LB_STATS_PASSWORD = if ($env:LB_STATS_PASSWORD) { $env:LB_STATS_PASSWORD } else { "changeme_lb_password" }

function Test-Result {
    param(
        [bool]$Result,
        [string]$Description
    )
    
    if ($Result) {
        Write-Host "✓ PASS" -ForegroundColor Green -NoNewline
        Write-Host ": $Description"
        $script:SUCCESS++
    } else {
        Write-Host "✗ FAIL" -ForegroundColor Red -NoNewline
        Write-Host ": $Description"
        $script:FAILED++
    }
}

# Test 1: Vérification des VMs
Write-Host "`n Test 1: Vérification des VMs" -ForegroundColor Yellow
Write-Host "================================" -ForegroundColor Yellow
$status = vagrant status
$running = ($status | Select-String "bdd1.*running" | Measure-Object).Count -eq 1 -and `
           ($status | Select-String "bdd2.*running" | Measure-Object).Count -eq 1 -and `
           ($status | Select-String "app1.*running" | Measure-Object).Count -eq 1 -and `
           ($status | Select-String "app2.*running" | Measure-Object).Count -eq 1 -and `
           ($status | Select-String "lb1.*running" | Measure-Object).Count -eq 1 -and `
           ($status | Select-String "lb2.*running" | Measure-Object).Count -eq 1
Test-Result $running "Toutes les VMs sont en état running"

# Test 2: Connectivité Load Balancer
Write-Host "`n Test 2: Connectivité Load Balancer" -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Yellow
try {
    $response = curl.exe -s http://localhost:8080/api/sante
    Test-Result ($null -ne $response) "Load balancer accessible sur http://localhost:8080"
} catch {
    Test-Result $false "Load balancer accessible sur http://localhost:8080"
}

# Test 3: Endpoint /api/sante (Health Check)
Write-Host "`n Test 3: Endpoint /api/sante (Health Check)" -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Yellow
try {
    $health = curl.exe -s http://localhost:8080/api/sante
    Write-Host "Réponse: $health" -ForegroundColor Gray
    Test-Result ($health -like "*healthy*") "Endpoint /api/sante retourne 'healthy'"
    Test-Result ($health -like "*database*connected*") "Connexion base de données OK"
} catch {
    Test-Result $false "Endpoint /api/sante accessible"
}

# Test 4: Endpoit /api/resultat (Données étudiant)
Write-Host "`n Test 4: Endpoint /api/resultat (Données étudiant)" -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Yellow
try {
    $resultat = curl.exe -s "http://localhost:8080/api/resultat?matricule=000001"
    Write-Host "Réponse: $resultat" -ForegroundColor Gray
    Test-Result ($resultat -like "*matricule*") "Endpoint /api/resultat retourne des données"
    Test-Result ($resultat -like "*CANDIDAT_1*") "Données de l'étudiant 000001 correctes"
} catch {
    Test-Result $false "Endpoint /api/resultat accessible"
}

# Test 5: Interface Vue.js (Frontend)
Write-Host "`n Test 5: Interface Vue.js (Frontend)" -ForegroundColor Yellow
Write-Host "======================================" -ForegroundColor Yellow
try {
    $frontend = curl.exe -s http://localhost:8080/
    Test-Result ($frontend -like "*RÉSULTATS-BF*") "Frontend accessible avec titre RÉSULTATS-BF"
    Test-Result (($frontend -like "*Vue*") -or ($frontend -like "*createApp*")) "Application Vue.js chargée"
} catch {
    Test-Result $false "Frontend accessible"
}

# Test 6: Base de données PostgreSQL
Write-Host "`n Test 6: Base de données PostgreSQL" -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Yellow
try {
    $count = vagrant ssh bdd1 -c "sudo -u postgres psql resultats_bf -t -c 'SELECT COUNT(*) FROM resultats;'" 2>$null
    $count = $count.Trim()
    Write-Host "Nombre de résultats en BDD: $count" -ForegroundColor Gray
    Test-Result ($count -eq "50000") "50 000 résultats en base de données"
} catch {
    Test-Result $false "Accès base de données"
}

# Test 7: Réplication PostgreSQL
Write-Host "`n Test 7: Réplication PostgreSQL" -ForegroundColor Yellow
Write-Host "=================================" -ForegroundColor Yellow
try {
    $cmd = 'sudo -u postgres psql -t -c "SELECT state FROM pg_stat_replication;"'
    $replication = vagrant ssh bdd1 -c $cmd 2>$null
    $replication = $replication.Trim()
    Write-Host "État réplication: $replication" -ForegroundColor Gray
    Test-Result ($replication -like "*streaming*") "Réplication PostgreSQL active (streaming)"
} catch {
    Test-Result $false "Réplication PostgreSQL"
}

# Test 8: Haute isponibilité (VIP Keepalived)
Write-Host "`n Test 8: Haute disponibilité (VIP Keepalived)" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Yellow
try {
    $vip_lb1 = vagrant ssh lb1 -c "ip addr show eth1 | grep 192.168.63.10" 2>$null
    $vip_lb2 = vagrant ssh lb2 -c "ip addr show eth1 | grep 192.168.63.10" 2>$null
    
    if ($vip_lb1) {
        Write-Host "VIP 192.168.63.10 trouvée sur lb1 (MASTER)" -ForegroundColor Gray
        Test-Result $true "VIP active sur lb1"
    } elseif ($vip_lb2) {
        Write-Host "VIP 192.168.63.10 trouvée sur lb2 (BACKUP devenu MASTER)" -ForegroundColor Gray
        Test-Result $true "VIP active sur lb2"
    } else {
        Test-Result $false "VIP 192.168.63.10 introuvable"
    }
} catch {
    Test-Result $false "Vérification VIP"
}

# Test 9: Load Balancing (Round Robin)
Write-Host "`n Test 9: Load Balancing (Round Robin)" -ForegroundColor Yellow
Write-Host "=======================================" -ForegroundColor Yellow
$hostnames = @()
for ($i = 1; $i -le 5; $i++) {
    try {
        $response = curl.exe -s http://localhost:8080/api/sante
        if ($response -match '"hostname":"(app\d)"') {
            $hostname = $matches[1]
        } else {
            $hostname = "unknown"
        }
        $hostnames += $hostname
        Write-Host "Requête $i : hostname=$hostname" -ForegroundColor Gray
    } catch {
        Write-Host "Requête $i : erreur" -ForegroundColor Red
    }
}
$unique = $hostnames | Select-Object -Unique
Test-Result ($unique.Count -gt 1) "Requêtes distribuées entre app1 et app2"

# Test 10: Dashboard HAProxy
Write-Host "`n Test 10: Dashboard HAProxy" -ForegroundColor Yellow
Write-Host "=============================" -ForegroundColor Yellow
try {
    $dashboard = curl.exe -s "http://localhost:8080/haproxy?stats" -u "${LB_STATS_USER}:${LB_STATS_PASSWORD}"
    Test-Result ($dashboard -like "*HAProxy*Statistics*") "Dashboard HAProxy accessible"
} catch {
    Test-Result $false "Dashboard HAProxy accessible"
}

# Résumé
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host " RÉSUMÉ DES TESTS" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Tests réussis: " -NoNewline
Write-Host $SUCCESS -ForegroundColor Green
Write-Host "Tests échoués: " -NoNewline
Write-Host $FAILED -ForegroundColor Red
Write-Host ""

if ($FAILED -eq 0) {
    Write-Host " TOUS LES TESTS SONT PASSÉS !" -ForegroundColor Green
    Write-Host "Infrastructure prête pour la démonstration." -ForegroundColor Green
    Write-Host ""
    Write-Host " Accès:" -ForegroundColor Cyan
    Write-Host "   Frontend:  http://localhost:8080" -ForegroundColor White
    Write-Host "   Dashboard: http://localhost:8080/haproxy?stats (voir .env)" -ForegroundColor White
    Write-Host "   API:       http://localhost:8080/api/resultat?matricule=000001" -ForegroundColor White
    exit 0
} else {
    Write-Host " Certains tests ont échoué." -ForegroundColor Yellow
    Write-Host "Vérifiez les logs avec: vagrant ssh <vm> -c `"sudo journalctl -xe`"" -ForegroundColor Yellow
    exit 1
}
