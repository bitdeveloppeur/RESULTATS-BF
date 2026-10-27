# Tests d'intégration - Scénarios de validation V1 à V6
# Automatise les scénarios demandés par le prof avec mesures

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "TESTS D'INTÉGRATION - SCÉNARIOS V1-V6" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$RESULTS = @()

# Fonction pour enregistrer les résultats
function Record-Result {
    param(
        [string]$Scenario,
        [string]$Status,
        [string]$Measure,
        [string]$Details
    )
    $script:RESULTS += [PSCustomObject]@{
        Scenario = $Scenario
        Status = $Status
        Measure = $Measure
        Details = $Details
    }
}

# ========================================
# V1: RÉPARTITION (Load Balancing)
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "V1: RÉPARTITION - 20 appels /api/sante" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

$servers = @{}
Write-Host "Envoi de 20 requêtes..." -ForegroundColor Gray
for ($i = 1; $i -le 20; $i++) {
    try {
        $response = curl.exe -s http://localhost:8080/api/sante | ConvertFrom-Json
        $hostname = $response.hostname
        if ($servers.ContainsKey($hostname)) {
            $servers[$hostname]++
        } else {
            $servers[$hostname] = 1
        }
        Write-Host "  Requête $i → $hostname" -ForegroundColor Gray
    } catch {
        Write-Host "  Requête $i → ERREUR" -ForegroundColor Red
    }
}

Write-Host "`nRésultat distribution:" -ForegroundColor Cyan
$total = 20
$counts = $servers.Values | Sort-Object
if ($counts.Count -ge 2) {
    $min = $counts[0]
    $max = $counts[-1]
    $ecart = [math]::Round((($max - $min) / $total) * 100, 2)
    
    foreach ($srv in $servers.Keys) {
        $pct = [math]::Round(($servers[$srv] / $total) * 100, 2)
        Write-Host "  $srv : $($servers[$srv])/20 ($pct%)" -ForegroundColor White
    }
    
    Write-Host "`nÉcart: $ecart%" -ForegroundColor $(if ($ecart -lt 20) { "Green" } else { "Red" })
    
    if ($ecart -lt 20) {
        Record-Result "V1" " PASS" "Écart: $ecart%" "Load balancing équilibré"
    } else {
        Record-Result "V1" " WARN" "Écart: $ecart%" "Distribution déséquilibrée"
    }
} else {
    Write-Host "  Un seul serveur répond!" -ForegroundColor Red
    Record-Result "V1" " FAIL" "N/A" "Un seul serveur actif"
}

# ========================================
# V2: PANNE D'UN SERVEUR APPLICATIF
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "V2: PANNE SERVEUR - Arrêt app1" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Write-Host "État initial..." -ForegroundColor Gray
$initialStatus = curl.exe -s http://localhost:8080/api/sante 2>$null

Write-Host "Arrêt de app1..." -ForegroundColor Gray
vagrant halt app1 2>&1 | Out-Null

Write-Host "Test pendant la période de détection (15s)..." -ForegroundColor Gray
$errors = 0
$requests = 0
$startTime = Get-Date

for ($i = 1; $i -le 30; $i++) {
    $requests++
    try {
        $test = curl.exe -s http://localhost:8080/api/sante 2>$null
        if (-not $test -or $test -like "*error*") {
            $errors++
        }
    } catch {
        $errors++
    }
    Start-Sleep -Milliseconds 500
}

$endTime = Get-Date
$degradedTime = [math]::Round(($endTime - $startTime).TotalSeconds, 2)
$errorRate = [math]::Round(($errors / $requests) * 100, 2)

Write-Host "`nRésultat:" -ForegroundColor Cyan
Write-Host "  Requêtes totales: $requests" -ForegroundColor White
Write-Host "  Requêtes perdues: $errors" -ForegroundColor White
Write-Host "  Durée période dégradée: $degradedTime s" -ForegroundColor White
Write-Host "  Taux d'erreur: $errorRate %" -ForegroundColor White

if ($degradedTime -le 10) {
    Record-Result "V2" " PASS" "Durée: $degradedTime s" "Détection et bascule rapides"
} else {
    Record-Result "V2" " WARN" "Durée: $degradedTime s" "Détection plus lente qu'attendu"
}

Write-Host "`nRedémarrage app1..." -ForegroundColor Gray
vagrant up app1 2>&1 | Out-Null
Write-Host "Attente stabilisation (30s)..." -ForegroundColor Gray
Start-Sleep -Seconds 30

# ========================================
# V3: MONTÉE EN CHARGE
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "V3: MONTÉE EN CHARGE - 2000 requêtes" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Write-Host "Test avec N=2 serveurs (app1, app2)..." -ForegroundColor Gray
$startTime = Get-Date
$completed = 0

# Simule 2000 requêtes avec concurrence de 50
1..2000 | ForEach-Object -Parallel {
    try {
        curl.exe -s http://localhost:8080/api/sante | Out-Null
    } catch {}
} -ThrottleLimit 50

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds
$rps = [math]::Round(2000 / $duration, 2)

Write-Host "`nRésultat:" -ForegroundColor Cyan
Write-Host "  Durée totale: $([math]::Round($duration, 2)) s" -ForegroundColor White
Write-Host "  Requêtes/seconde: $rps req/s" -ForegroundColor White

if ($rps -gt 50) {
    Record-Result "V3" " PASS" "Débit: $rps req/s" "Performance acceptable"
} else {
    Record-Result "V3" " WARN" "Débit: $rps req/s" "Performance faible"
}

# ========================================
# V4: PANNE BASE PRIMAIRE
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "V4: PANNE BDD - Arrêt bdd1" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Write-Host "Arrêt de bdd1..." -ForegroundColor Gray
vagrant halt bdd1 2>&1 | Out-Null

Write-Host "Attente propagation (5s)..." -ForegroundColor Gray
Start-Sleep -Seconds 5

Write-Host "Test réponse API..." -ForegroundColor Gray
$response = curl.exe -s -w "%{http_code}" http://localhost:8080/api/sante -o nul 2>$null

Write-Host "`nRésultat:" -ForegroundColor Cyan
if ($response -match "503" -or $response -match "500") {
    Write-Host "  Code HTTP: $response (erreur propre)" -ForegroundColor Green
    Record-Result "V4" " PASS" "HTTP $response" "Erreur gérée proprement (pas de page blanche)"
} elseif ($response -match "200") {
    Write-Host "  Code HTTP: 200 (connexion fallback?)" -ForegroundColor Yellow
    Record-Result "V4" " WARN" "HTTP 200" "API répond malgré panne BDD"
} else {
    Write-Host "  Code HTTP: $response" -ForegroundColor Red
    Record-Result "V4" " FAIL" "HTTP $response" "Réponse inattendue"
}

Write-Host "`nRedémarrage bdd1..." -ForegroundColor Gray
vagrant up bdd1 2>&1 | Out-Null
Write-Host "Attente stabilisation (40s)..." -ForegroundColor Gray
Start-Sleep -Seconds 40

# ========================================
# V5: RECONSTRUCTION
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "V5: RECONSTRUCTION - destroy + up" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  CE TEST EST DESTRUCTIF ET LONG (8-10 min)" -ForegroundColor Red
Write-Host "Voulez-vous l'exécuter? (o/N)" -ForegroundColor Yellow
$confirm = Read-Host

if ($confirm -eq "o" -or $confirm -eq "O") {
    Write-Host "Destruction complète..." -ForegroundColor Gray
    $startTime = Get-Date
    vagrant destroy -f 2>&1 | Out-Null
    
    Write-Host "Reconstruction..." -ForegroundColor Gray
    vagrant up 2>&1 | Out-Null
    
    $endTime = Get-Date
    $rebuildTime = [math]::Round(($endTime - $startTime).TotalMinutes, 2)
    
    Write-Host "`nRésultat:" -ForegroundColor Cyan
    Write-Host "  Durée totale: $rebuildTime min" -ForegroundColor White
    
    # Vérifier que tout fonctionne
    Start-Sleep -Seconds 10
    $testHealth = curl.exe -s http://localhost:8080/api/sante 2>$null
    
    if ($testHealth -like "*healthy*") {
        Record-Result "V5" " PASS" "Durée: $rebuildTime min" "Infrastructure fonctionnelle"
    } else {
        Record-Result "V5" " FAIL" "Durée: $rebuildTime min" "Infrastructure non fonctionnelle"
    }
} else {
    Write-Host "Test V5 ignoré (trop long)" -ForegroundColor Yellow
    Record-Result "V5" "⏭  SKIP" "N/A" "Test ignoré par l'utilisateur"
}

# ========================================
# V6: PANNE RÉPARTITEUR (HA)
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "V6: PANNE LB - Arrêt lb1 (MASTER)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Write-Host "Vérification VIP initiale..." -ForegroundColor Gray
$vip1Before = vagrant ssh lb1 -c "ip addr show eth1 | grep 192.168.63.10" 2>$null

Write-Host "Arrêt de lb1..." -ForegroundColor Gray
vagrant halt lb1 2>&1 | Out-Null

Write-Host "Attente bascule VRRP (5s)..." -ForegroundColor Gray
Start-Sleep -Seconds 5

Write-Host "Vérification VIP sur lb2..." -ForegroundColor Gray
$vip2After = vagrant ssh lb2 -c "ip addr show eth1 | grep 192.168.63.10" 2>$null

Write-Host "Test accessibilité API..." -ForegroundColor Gray
$apiTest = curl.exe -s http://localhost:8080/api/sante 2>$null

Write-Host "`nRésultat:" -ForegroundColor Cyan
if ($vip2After -and $apiTest -like "*healthy*") {
    Write-Host "  VIP basculée sur lb2: " -ForegroundColor Green
    Write-Host "  API accessible: " -ForegroundColor Green
    Record-Result "V6" " PASS" "Bascule < 5s" "Haute disponibilité fonctionnelle"
} else {
    Write-Host "  VIP basculée: $(if($vip2After){''}else{'❌'})" -ForegroundColor $(if($vip2After){"Green"}else{"Red"})
    Write-Host "  API accessible: $(if($apiTest){''}else{'❌'})" -ForegroundColor $(if($apiTest){"Green"}else{"Red"})
    Record-Result "V6" " FAIL" "N/A" "Bascule VRRP échouée"
}

Write-Host "`nRedémarrage lb1..." -ForegroundColor Gray
vagrant up lb1 2>&1 | Out-Null

# ========================================
# RAPPORT FINAL
# ========================================
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "RAPPORT FINAL - SCÉNARIOS DE VALIDATION" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$RESULTS | Format-Table -AutoSize

$passed = ($RESULTS | Where-Object { $_.Status -like "*PASS*" }).Count
$total = ($RESULTS | Where-Object { $_.Status -notlike "*SKIP*" }).Count

Write-Host "`nRésumé: $passed/$total scénarios validés" -ForegroundColor $(if($passed -eq $total){"Green"}else{"Yellow"})

# Exporter en fichier
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportPath = "tests/integration/rapport-$timestamp.txt"
$RESULTS | Out-File -FilePath $reportPath

Write-Host "`nRapport sauvegardé: $reportPath" -ForegroundColor Cyan

if ($passed -eq $total) {
    Write-Host "`n Tous les scénarios d'intégration sont validés!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n Certains scénarios nécessitent attention" -ForegroundColor Yellow
    exit 1
}
