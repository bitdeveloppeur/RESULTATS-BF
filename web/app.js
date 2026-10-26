const { createApp } = Vue;

createApp({
    data() {
        return {
            matricule: '',
            resultat: null,
            loading: false,
            error: null,
            systemInfo: {
                hostname: null,
                database: null
            }
        }
    },
    computed: {
        notes() {
            if (!this.resultat) return [];
            
            return [
                { matiere: 'Mathématiques', valeur: this.resultat.maths, icon: 'bi bi-calculator' },
                { matiere: 'Français', valeur: this.resultat.francais, icon: 'bi bi-book' },
                { matiere: 'Anglais', valeur: this.resultat.anglais, icon: 'bi bi-globe' },
                { matiere: 'SVT', valeur: this.resultat.svt, icon: 'bi bi-flower1' }
            ];
        }
    },
    methods: {
        async rechercherResultat() {
            this.loading = true;
            this.error = null;
            this.resultat = null;

            try {
                const response = await fetch(`/api/resultat?matricule=${this.matricule}`);
                
                if (!response.ok) {
                    if (response.status === 404) {
                        throw new Error('Matricule introuvable. Vérifiez le numéro saisi.');
                    }
                    throw new Error('Erreur lors de la récupération des résultats.');
                }

                this.resultat = await response.json();
            } catch (err) {
                this.error = err.message;
            } finally {
                this.loading = false;
            }
        },

        async chargerInfoSysteme() {
            try {
                const response = await fetch('/api/info');
                if (response.ok) {
                    const data = await response.json();
                    this.systemInfo.hostname = data.hostname;
                    this.systemInfo.database = data.database;
                }
            } catch (err) {
                console.error('Erreur chargement info système:', err);
            }
        },

        getBadgeClass(note) {
            if (note >= 16) return 'bg-success';
            if (note >= 14) return 'bg-info';
            if (note >= 10) return 'bg-primary';
            if (note >= 8) return 'bg-warning';
            return 'bg-danger';
        },

        getAppreciation(note) {
            if (note >= 16) return '🌟 Excellent';
            if (note >= 14) return '👍 Très bien';
            if (note >= 12) return '✅ Bien';
            if (note >= 10) return '👌 Assez bien';
            if (note >= 8) return '⚠️ Passable';
            return '❌ Insuffisant';
        },

        getAppreciationClass(note) {
            if (note >= 10) return 'text-success fw-bold';
            if (note >= 8) return 'text-warning fw-bold';
            return 'text-danger fw-bold';
        }
    },
    mounted() {
        // Charger les infos système au démarrage
        this.chargerInfoSysteme();
    }
}).mount('#app');
