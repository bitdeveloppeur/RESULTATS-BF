-- Script d'initialisation de la base de données resultats_bf
-- Rôle : Ingénieur données

-- Créer la table resultats
CREATE TABLE IF NOT EXISTS resultats (
    id SERIAL PRIMARY KEY,
    matricule VARCHAR(20) UNIQUE NOT NULL,
    nom VARCHAR(100) NOT NULL,
    serie VARCHAR(10) NOT NULL,
    moyenne DECIMAL(4,2) NOT NULL CHECK (moyenne >= 0 AND moyenne <= 20),
    admis BOOLEAN NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index pour optimiser les recherches par matricule
CREATE INDEX IF NOT EXISTS idx_resultats_matricule ON resultats(matricule);

-- Générer 50 000 candidats réalistes
INSERT INTO resultats (matricule, nom, serie, moyenne, admis)
SELECT
    LPAD(i::TEXT, 6, '0') AS matricule,
    'CANDIDAT_' || LPAD(i::TEXT, 5, '0') AS nom,
    CASE (i % 4)
        WHEN 0 THEN 'A'      -- Série A (littéraire)
        WHEN 1 THEN 'C'      -- Série C (scientifique)
        WHEN 2 THEN 'D'      -- Série D (mathématiques)
        ELSE 'S'             -- Série S (sciences)
    END AS serie,
    ROUND((RANDOM() * 10 + 5)::NUMERIC, 2) AS moyenne,  -- Moyenne entre 5 et 15
    CASE WHEN RANDOM() > 0.3 THEN true ELSE false END AS admis  -- 70% d'admis
FROM generate_series(1, 50000) AS i;

-- Statistiques
SELECT 
    'Total candidats' AS statistique,
    COUNT(*) AS valeur
FROM resultats

UNION ALL

SELECT 
    'Candidats admis' AS statistique,
    COUNT(*) AS valeur
FROM resultats
WHERE admis = true

UNION ALL

SELECT 
    'Moyenne générale' AS statistique,
    ROUND(AVG(moyenne)::NUMERIC, 2) AS valeur
FROM resultats;
