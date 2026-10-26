# Tests unitaires - API FastAPI
# Teste chaque endpoint individuellement

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TESTS UNITAIRES - API" -ForegroundColor Cyan
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

# Test 1: Endpoint root (/)
Write-Host "`nTest 1: GET /" -ForegroundColor Yellow
try {
    $response = curl.exe -s http://localhost:8080/
    if ($response -like "*RÉSULTATS-BF*") {
        Test-Pass "Endpoint root retourne du HTML valide"
    } else {
        Test-Fail "Endpoint root" "Contenu invalide"
    }
} catch {
    Test-Fail "Endpoint root" "Erreur HTTP"
}

# Test 2: Endpoint /api/sante
Write-Host "`nTest 2: GET /api/sante" -ForegroundColor Yellow
try {
    $health = curl.exe -s http://localhost:8080/api/sante | ConvertFrom-Json
    
    if ($health.status -eq "healthy") {
        Test-Pass "Health check status = healthy"
    } else {
        Test-Fail "Health check" "Status != healthy"
    }
    
    if ($health.database -eq "connected") {
        Test-Pass "Database connection OK"
    } else {
        Test-Fail "Database" "Not connected"
    }
    
    if ($health.hostname -match "^app[12]$") {
        Test-Pass "Hostname valide (app1 ou app2)"
    } else {
        Test-Fail "Hostname" "Format invalide: $($health.hostname)"
    }
} catch {
    Test-Fail "Endpoint /api/sante" "Erreur parsing JSON"
}

# Test 3: Endpoint /api/resultat avec matricule valide
Write-Host "`nTest 3: GET /api/resultat?matricule=000001" -ForegroundColor Yellow
try {
    $resultat = curl.exe -s "http://localhost:8080/api/resultat?matricule=000001" | ConvertFrom-Json
    
    if ($resultat.matricule -eq "000001") {
        Test-Pass "Matricule correct"
    } else {
        Test-Fail "Matricule" "Valeur incorrecte"
    }
    
    if ($resultat.nom) {
        Test-Pass "Nom étudiant présent"
    } else {
        Test-Fail "Nom" "Champ vide"
    }
    
    if ($resultat.serie -match "^[ACD]$") {
        Test-Pass "Série valide (A, C ou D)"
    } else {
        Test-Fail "Série" "Format invalide"
    }
    
    if ($resultat.moyenne -is [double]) {
        Test-Pass "Moyenne est un nombre"
    } else {
        Test-Fail "Moyenne" "Type invalide"
    }
    
    if ($null -ne $resultat.admis) {
        Test-Pass "Champ admis présent (boolean)"
    } else {
        Test-Fail "Admis" "Champ manquant"
    }
} catch {
    Test-Fail "Endpoint /api/resultat" "Erreur parsing JSON"
}

# Test 4: Endpoint /api/resultat avec matricule invalide
Write-Host "`nTest 4: GET /api/resultat?matricule=999999" -ForegroundColor Yellow
try {
    $response = curl.exe -s -w "%{http_code}" "http://localhost:8080/api/resultat?matricule=999999" -o nul
    if ($response -eq "404") {
        Test-Pass "Retourne 404 pour matricule inexistant"
    } else {
        Test-Fail "Code HTTP" "Attendu 404, reçu $response"
    }
} catch {
    Test-Fail "Endpoint /api/resultat (404)" "Erreur test"
}

# Test 5: Temps de réponse
Write-Host "`nTest 5: Performance API" -ForegroundColor Yellow
$times = @()
for ($i = 1; $i -le 10; $i++) {
    $start = Get-Date
    curl.exe -s http://localhost:8080/api/sante | Out-Null
    $end = Get-Date
    $times += ($end - $start).TotalMilliseconds
}
$avgTime = ($times | Measure-Object -Average).Average
if ($avgTime -lt 500) {
    Test-Pass "Temps de réponse moyen: $([math]::Round($avgTime))ms (< 500ms)"
} else {
    Test-Fail "Performance" "Temps moyen: $([math]::Round($avgTime))ms (trop lent)"
}

# Résumé
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RÉSUMÉ TESTS UNITAIRES API" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Tests réussis: $SUCCESS" -ForegroundColor Green
Write-Host "Tests échoués: $FAILED" -ForegroundColor Red

if ($FAILED -eq 0) {
    Write-Host "`nTous les tests unitaires API sont passés! ✅" -ForegroundColor Green
    exit 0
} else {
    exit 1
}
