# Tests unitaires - Infrastructure
# Teste les composants individuels (VMs, services, réseau)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TESTS UNITAIRES - INFRASTRUCTURE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$SUCCESS = 0
$FAILED = 0

function Test-Pass {
    param([string]$Name)
    Write-Host "[PASS] $Name" -ForegroundColor Green
    $script:SUCCESS++
}

function Test-Fail {
    param([string]$Name, [string]$Reason)
    Write-Host "[FAIL] $Name - $Reason" -ForegroundColor Red
    $script:FAILED++
}

# Test 1: Toutes les VMs sont running
Write-Host "`nTest 1: État des VMs" -ForegroundColor Yellow
$vms = @("bdd1", "bdd2", "app1", "app2", "lb1", "lb2")
$status = vagrant status | Out-String
foreach ($vm in $vms) {
    if ($status -match "$vm\s+running") {
        Test-Pass "VM $vm est running"
    } else {
        Test-Fail "VM $vm" "N'est pas running"
    }
}

# Test 2: Services HAProxy sur lb1 et lb2
Write-Host "`nTest 2: Services HAProxy" -ForegroundColor Yellow
$lb1Status = vagrant ssh lb1 -c "sudo systemctl is-active haproxy" 2>$null
$lb2Status = vagrant ssh lb2 -c "sudo systemctl is-active haproxy" 2>$null
if ($lb1Status -match "active") {
    Test-Pass "HAProxy actif sur lb1"
} else {
    Test-Fail "HAProxy lb1" "Service non actif"
}
if ($lb2Status -match "active") {
    Test-Pass "HAProxy actif sur lb2"
} else {
    Test-Fail "HAProxy lb2" "Service non actif"
}

# Test 3: Services Keepalived (VRRP)
Write-Host "`nTest 3: Services Keepalived" -ForegroundColor Yellow
$ka1Status = vagrant ssh lb1 -c "sudo systemctl is-active keepalived" 2>$null
$ka2Status = vagrant ssh lb2 -c "sudo systemctl is-active keepalived" 2>$null
if ($ka1Status -match "active") {
    Test-Pass "Keepalived actif sur lb1"
} else {
    Test-Fail "Keepalived lb1" "Service non actif"
}
if ($ka2Status -match "active") {
    Test-Pass "Keepalived actif sur lb2"
} else {
    Test-Fail "Keepalived lb2" "Service non actif"
}

# Test 4: VIP Keepalived active
Write-Host "`nTest 4: VIP Keepalived (192.168.63.10)" -ForegroundColor Yellow
$vip1 = vagrant ssh lb1 -c "ip addr show eth1 | grep 192.168.63.10" 2>$null
$vip2 = vagrant ssh lb2 -c "ip addr show eth1 | grep 192.168.63.10" 2>$null
if ($vip1) {
    Test-Pass "VIP active sur lb1 (MASTER)"
} elseif ($vip2) {
    Test-Pass "VIP active sur lb2 (BACKUP)"
} else {
    Test-Fail "VIP" "192.168.63.10 introuvable"
}

# Test 5: Services FastAPI sur app1 et app2
Write-Host "`nTest 5: Services FastAPI" -ForegroundColor Yellow
$app1Status = vagrant ssh app1 -c "sudo systemctl is-active resultats-bf" 2>$null
$app2Status = vagrant ssh app2 -c "sudo systemctl is-active resultats-bf" 2>$null
if ($app1Status -match "active") {
    Test-Pass "FastAPI actif sur app1"
} else {
    Test-Fail "FastAPI app1" "Service non actif"
}
if ($app2Status -match "active") {
    Test-Pass "FastAPI actif sur app2"
} else {
    Test-Fail "FastAPI app2" "Service non actif"
}

# Test 6: Ports réseau ouverts
Write-Host "`nTest 6: Ports réseau" -ForegroundColor Yellow
$lb1Port80 = vagrant ssh lb1 -c "sudo netstat -tlnp | grep ':80 '" 2>$null
$app1Port3000 = vagrant ssh app1 -c "sudo netstat -tlnp | grep ':3000 '" 2>$null
$bdd1Port5432 = vagrant ssh bdd1 -c "sudo netstat -tlnp | grep ':5432 '" 2>$null

if ($lb1Port80) {
    Test-Pass "Port 80 ouvert sur lb1 (HAProxy)"
} else {
    Test-Fail "Port 80" "Non ouvert sur lb1"
}
if ($app1Port3000) {
    Test-Pass "Port 3000 ouvert sur app1 (FastAPI)"
} else {
    Test-Fail "Port 3000" "Non ouvert sur app1"
}
if ($bdd1Port5432) {
    Test-Pass "Port 5432 ouvert sur bdd1 (PostgreSQL)"
} else {
    Test-Fail "Port 5432" "Non ouvert sur bdd1"
}

# Test 7: Fichiers de configuration
Write-Host "`nTest 7: Fichiers de configuration" -ForegroundColor Yellow
$haproxyConf = vagrant ssh lb1 -c "test -f /etc/haproxy/haproxy.cfg && echo exists" 2>$null
$appEnv = vagrant ssh app1 -c "test -f /opt/resultats-bf/.env && echo exists" 2>$null
$pgConf = vagrant ssh bdd1 -c "sudo test -f /etc/postgresql/16/main/postgresql.conf && echo exists" 2>$null

if ($haproxyConf -match "exists") {
    Test-Pass "Config HAProxy présente"
} else {
    Test-Fail "Config HAProxy" "Fichier manquant"
}
if ($appEnv -match "exists") {
    Test-Pass "Config application (.env) présente"
} else {
    Test-Fail "Config app" "Fichier .env manquant"
}
if ($pgConf -match "exists") {
    Test-Pass "Config PostgreSQL présente"
} else {
    Test-Fail "Config PostgreSQL" "Fichier manquant"
}

# Résumé
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RÉSUMÉ TESTS UNITAIRES INFRA" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Tests réussis: $SUCCESS" -ForegroundColor Green
Write-Host "Tests échoués: $FAILED" -ForegroundColor Red

if ($FAILED -eq 0) {
    Write-Host "`nTous les tests unitaires infrastructure sont passés! ✅" -ForegroundColor Green
    exit 0
} else {
    exit 1
}
