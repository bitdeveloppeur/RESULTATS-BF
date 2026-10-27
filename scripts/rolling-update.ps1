# ==============================================================================
# RESULTATS-BF - Extension E4 : Deploiement sans coupure (Rolling Update)
# Role : Ingenieur applicatif
# Description : Met a jour les serveurs applicatifs un par un (Zero-Downtime)
#               en drainant le trafic via HAProxy.
# ==============================================================================

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [E4] LANCEMENT DU DEPLOIEMENT SANS COUPURE (ROLLING UPDATE)     " -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# 1. Lire la liste des serveurs applicatifs depuis config/noeuds.yml (source unique de verite)
$noeudsFile = "config/noeuds.yml"
if (-not (Test-Path $noeudsFile)) {
    Write-Error "Fichier $noeudsFile introuvable ! Lancez vagrant up d'abord."
    exit 1
}

$content = Get-Content $noeudsFile -Raw
$appServers = [regex]::Matches($content, "- :nom: (app\d+)") | ForEach-Object { $_.Groups[1].Value }

if ($appServers.Count -eq 0) {
    Write-Error "Aucun serveur applicatif trouve dans $noeudsFile !"
    exit 1
}

Write-Host "Serveurs detectes : $($appServers -join ', ')" -ForegroundColor Yellow
Write-Host "Nombre total de serveurs a mettre a jour : $($appServers.Count)" -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------"

# 2. Verifier la version actuelle avant le deploiement
try {
    $before = Invoke-RestMethod -Uri "http://localhost:8080/" -TimeoutSec 3 -ErrorAction SilentlyContinue
    Write-Host "Version actuelle en production : $($before.version)" -ForegroundColor Green
} catch {
    Write-Host "Impossible de contacter http://localhost:8080/ (verifiez si lb1 est demarre)" -ForegroundColor Red
}

$startTime = Get-Date

# 3. Boucle de mise a jour serveur par serveur
foreach ($app in $appServers) {
    Write-Host "`n>>> [Etape] Deploiement sur $app..." -ForegroundColor Cyan

    # A. Passer le serveur en mode MAINTENANCE dans HAProxy (Drainage du trafic)
    Write-Host "  1. Isolation de $app dans HAProxy (etat: MAINT)..." -NoNewline
    $setMaintCmd = "echo 'set server app_servers/$app state maint' | sudo socat stdio /run/haproxy/admin.sock"
    vagrant ssh lb1 -c "$setMaintCmd" | Out-Null
    Write-Host " [OK]" -ForegroundColor Green

    # Pause de drainage : laisser 2 secondes pour terminer les requetes en cours
    Start-Sleep -Seconds 2

    # B. Mettre a jour le code de l'application et redemarrer le service
    Write-Host "  2. Synchronisation du code et redemarrage du service sur $app..." -NoNewline
    $updateCmd = "sudo cp -r /vagrant/app/* /opt/resultats-bf/app/ && sudo systemctl restart resultats-bf"
    vagrant ssh $app -c "$updateCmd" | Out-Null
    Write-Host " [OK]" -ForegroundColor Green

    # C. Verifier que la sonde de sante repond 200 OK
    Write-Host "  3. Verification de la sonde de sante /sante sur $app..." -NoNewline
    $healthy = $false
    for ($i = 0; $i -lt 10; $i++) {
        Start-Sleep -Seconds 1
        $checkHealthCmd = "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/sante"
        $status = (vagrant ssh $app -c "$checkHealthCmd" 2>$null).Trim()
        if ($status -eq "200") {
            $healthy = $true
            break
        }
    }

    if (-not $healthy) {
        Write-Host " [ECHEC : la sonde ne repond pas 200]" -ForegroundColor Red
        Write-Host "Interruption du deploiement pour proteger la production !" -ForegroundColor Red
        exit 1
    }
    Write-Host " [OK (200)]" -ForegroundColor Green

    # D. Reactiver le serveur dans HAProxy
    Write-Host "  4. Reintegration de $app dans le pool actif HAProxy (etat: READY)..." -NoNewline
    $setReadyCmd = "echo 'set server app_servers/$app state ready' | sudo socat stdio /run/haproxy/admin.sock"
    vagrant ssh lb1 -c "$setReadyCmd" | Out-Null
    Write-Host " [OK]" -ForegroundColor Green

    Write-Host "  ==> $app est desormais a jour et actif !" -ForegroundColor Green
}

$elapsed = [Math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)

# 4. Verifier la nouvelle version en production
Write-Host "`n------------------------------------------------------------------"
Write-Host "Verification finale apres deploiement :" -ForegroundColor Cyan
try {
    $after = Invoke-RestMethod -Uri "http://localhost:8080/" -TimeoutSec 3
    Write-Host "Service : $($after.service)" -ForegroundColor Green
    Write-Host "Nouvelle version : $($after.version)" -ForegroundColor Green
} catch {
    Write-Host "Erreur lors de la verification finale" -ForegroundColor Red
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [SUCCES] Deploiement sans coupure termine en $elapsed secondes ! " -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan
