# Tests unitaires - Base de données PostgreSQL
# Teste la structure et les données

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TESTS UNITAIRES - BASE DE DONNÉES" -ForegroundColor Cyan
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

# Test 1: PostgreSQL est actif
Write-Host "`nTest 1: Service PostgreSQL" -ForegroundColor Yellow
$pgStatus = vagrant ssh bdd1 -c "sudo systemctl is-active postgresql" 2>$null
if ($pgStatus -match "active") {
    Test-Pass "PostgreSQL actif sur bdd1"
} else {
    Test-Fail "PostgreSQL" "Service non actif"
}

# Test 2: Base de données existe
Write-Host "`nTest 2: Base de données resultats_bf" -ForegroundColor Yellow
$dbExists = vagrant ssh bdd1 -c "sudo -u postgres psql -lqt | grep resultats_bf" 2>$null
if ($dbExists) {
    Test-Pass "Base de données resultats_bf existe"
} else {
    Test-Fail "Base de données" "resultats_bf introuvable"
}

# Test 3: Table resultats existe
Write-Host "`nTest 3: Table resultats" -ForegroundColor Yellow
$tableExists = vagrant ssh bdd1 -c "sudo -u postgres psql resultats_bf -c '\dt resultats'" 2>$null
if ($tableExists -match "resultats") {
    Test-Pass "Table resultats existe"
} else {
    Test-Fail "Table" "resultats introuvable"
}

# Test 4: Nombre de résultats (50 000)
Write-Host "`nTest 4: Nombre de résultats" -ForegroundColor Yellow
$countCmd = 'sudo -u postgres psql resultats_bf -t -c "SELECT COUNT(*) FROM resultats;"'
$count = vagrant ssh bdd1 -c $countCmd 2>$null
$count = ($count | Out-String).Trim()
if ($count -eq "50000") {
    Test-Pass "50 000 résultats en base"
} else {
    Test-Fail "Nombre de résultats" "Attendu 50000, trouvé $count"
}

# Test 5: Structure de la table
Write-Host "`nTest 5: Colonnes de la table" -ForegroundColor Yellow
$columns = vagrant ssh bdd1 -c "sudo -u postgres psql resultats_bf -c '\d resultats'" 2>$null
$requiredColumns = @("matricule", "nom", "serie", "moyenne", "admis")
$allPresent = $true
foreach ($col in $requiredColumns) {
    if ($columns -notmatch $col) {
        Test-Fail "Colonne $col" "Manquante"
        $allPresent = $false
    }
}
if ($allPresent) {
    Test-Pass "Toutes les colonnes présentes"
}

# Test 6: Données valides (échantillon)
Write-Host "`nTest 6: Validation données" -ForegroundColor Yellow
$sampleCmd = 'sudo -u postgres psql resultats_bf -t -c "SELECT COUNT(*) FROM resultats WHERE serie IN (' + "'A', 'C', 'D'" + ');"'
$validSeries = vagrant ssh bdd1 -c $sampleCmd 2>$null
$validSeries = ($validSeries | Out-String).Trim()
if ($validSeries -eq "50000") {
    Test-Pass "Toutes les séries sont valides (A, C ou D)"
} else {
    Test-Fail "Séries" "Données invalides détectées"
}

# Test 7: Moyenne dans l'intervalle [0, 20]
Write-Host "`nTest 7: Validation moyennes" -ForegroundColor Yellow
$avgCmd = 'sudo -u postgres psql resultats_bf -t -c "SELECT COUNT(*) FROM resultats WHERE moyenne >= 0 AND moyenne <= 20;"'
$validAvg = vagrant ssh bdd1 -c $avgCmd 2>$null
$validAvg = ($validAvg | Out-String).Trim()
if ($validAvg -eq "50000") {
    Test-Pass "Toutes les moyennes dans [0, 20]"
} else {
    Test-Fail "Moyennes" "Valeurs hors intervalle détectées"
}

# Test 8: Réplication configurée
Write-Host "`nTest 8: Réplication PostgreSQL" -ForegroundColor Yellow
$replicationCmd = 'sudo -u postgres psql -t -c "SELECT COUNT(*) FROM pg_stat_replication;"'
$replCount = vagrant ssh bdd1 -c $replicationCmd 2>$null
$replCount = ($replCount | Out-String).Trim()
if ([int]$replCount -ge 1) {
    Test-Pass "Réplication configurée (1 replica)"
} else {
    Test-Fail "Réplication" "Aucun replica détecté"
}

# Résumé
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RÉSUMÉ TESTS UNITAIRES BDD" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Tests réussis: $SUCCESS" -ForegroundColor Green
Write-Host "Tests échoués: $FAILED" -ForegroundColor Red

if ($FAILED -eq 0) {
    Write-Host "`nTous les tests unitaires BDD sont passés! ✅" -ForegroundColor Green
    exit 0
} else {
    exit 1
}
