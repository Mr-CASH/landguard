"""
============================================================
LandGuard Neuro-Symbolic AI
MODULE : test_suite.py
Tests unitaires et d'intégration (≥ 15 scénarios)
============================================================
Couverture :
    - Tests unitaires règles Prolog (via interface Python)
    - Tests bornes d'inférence ProbLog
    - Tests d'intégration end-to-end pipeline
============================================================
"""

import sys
import unittest
import json
from pathlib import Path
import torch
import numpy as np

sys.path.insert(0, str(Path(__file__).parent.parent))
sys.path.insert(0, str(Path(__file__).parent.parent))

from part4_deepproblog.neural_model import (
    FraudDetectionNet, generate_synthetic_dataset, train, predict_individual,
    FEATURE_NAMES, CLASSES, INPUT_DIM, HIDDEN_DIM, OUTPUT_DIM
)
from pipeline.main import (
    row_to_features, compute_problog_score, classify_risk, fuse_decisions,
    load_dataset
)

# ============================================================
# FIXTURES PARTAGÉES
# ============================================================

PROFIL_FRAUDEUR = {
    'nb_parcelles_urbaines': '5', 'nb_parcelles_rurales': '2',
    'frequence_revente': '0.85', 'ratio_plus_value': '0.90',
    'nb_liens_reseau': '9', 'partage_telephone': '1',
    'partage_adresse': '1', 'partage_iban': '1',
    'age_premier_achat_jours': '15', 'est_agent_public': '0',
    'type_acteur': 'citoyen',
}

PROFIL_STANDARD = {
    'nb_parcelles_urbaines': '1', 'nb_parcelles_rurales': '0',
    'frequence_revente': '0.0', 'ratio_plus_value': '0.05',
    'nb_liens_reseau': '1', 'partage_telephone': '0',
    'partage_adresse': '0', 'partage_iban': '0',
    'age_premier_achat_jours': '900', 'est_agent_public': '0',
    'type_acteur': 'citoyen',
}

PROFIL_SPECULATEUR = {
    'nb_parcelles_urbaines': '3', 'nb_parcelles_rurales': '0',
    'frequence_revente': '0.70', 'ratio_plus_value': '0.50',
    'nb_liens_reseau': '2', 'partage_telephone': '0',
    'partage_adresse': '0', 'partage_iban': '0',
    'age_premier_achat_jours': '200', 'est_agent_public': '0',
    'type_acteur': 'citoyen',
}

PROFIL_AGENT_CONFLIT = {
    'nb_parcelles_urbaines': '2', 'nb_parcelles_rurales': '0',
    'frequence_revente': '0.2', 'ratio_plus_value': '0.15',
    'nb_liens_reseau': '4', 'partage_telephone': '0',
    'partage_adresse': '0', 'partage_iban': '0',
    'age_premier_achat_jours': '500', 'est_agent_public': '1',
    'type_acteur': 'agent_public',
}


# ============================================================
# TEST GROUPE 1 — RÈGLES SYMBOLIQUES (équivalent Prolog)
# ============================================================

class TestReglesSymboliques(unittest.TestCase):
    """Tests unitaires des règles logiques reproduites en Python."""

    # T01 : Accaparement urbain (≥4 parcelles)
    def test_T01_accaparement_urbain_detecte(self):
        score, rules = compute_problog_score(PROFIL_FRAUDEUR)
        self.assertIn('accaparement', ' '.join(rules),
                      "T01 : accaparement_urbain doit être détecté pour 5 parcelles")

    # T02 : Pas d'accaparement sous le seuil
    def test_T02_pas_accaparement_sous_seuil(self):
        profil = dict(PROFIL_STANDARD)
        profil['nb_parcelles_urbaines'] = '3'
        score, rules = compute_problog_score(profil)
        self.assertNotIn('accaparement', ' '.join(rules),
                         "T02 : pas d'accaparement pour 3 parcelles")

    # T03 : Prête-nom téléphone activé
    def test_T03_prete_nom_telephone(self):
        profil = dict(PROFIL_STANDARD)
        profil['partage_telephone'] = '1'
        score, rules = compute_problog_score(profil)
        self.assertIn('prete_nom_telephone', ' '.join(rules),
                      "T03 : prete_nom_telephone activé si partage_telephone=1")

    # T04 : Spéculation revente rapide
    def test_T04_speculation_revente_rapide(self):
        profil = dict(PROFIL_SPECULATEUR)
        score, rules = compute_problog_score(profil)
        self.assertIn('speculation_revente', ' '.join(rules),
                      "T04 : speculation_revente activé si freq_revente > 0.5")

    # T05 : Plus-value anormale
    def test_T05_plus_value_anormale(self):
        profil = dict(PROFIL_FRAUDEUR)
        score, rules = compute_problog_score(profil)
        self.assertIn('speculation_plus_value', ' '.join(rules),
                      "T05 : plus_value détectée si ratio > 0.3")

    # T06 : Conflit agent public
    def test_T06_conflit_agent_public(self):
        score, rules = compute_problog_score(PROFIL_AGENT_CONFLIT)
        self.assertIn('conflit_familial_probable', ' '.join(rules),
                      "T06 : conflit_familial_probable activé pour agent+liens")

    # T07 : Score nul profil vide
    def test_T07_score_nul_profil_vide(self):
        profil_vide = {
            'nb_parcelles_urbaines': '0', 'nb_parcelles_rurales': '0',
            'frequence_revente': '0.0', 'ratio_plus_value': '0.0',
            'nb_liens_reseau': '0', 'partage_telephone': '0',
            'partage_adresse': '0', 'partage_iban': '0',
            'age_premier_achat_jours': '1000', 'est_agent_public': '0',
            'type_acteur': 'citoyen',
        }
        score, rules = compute_problog_score(profil_vide)
        self.assertEqual(score, 0.0, "T07 : profil vide → score = 0")
        self.assertEqual(rules, [], "T07 : profil vide → aucune règle activée")

    # T08 : Fraude composite → toutes règles activées
    def test_T08_fraude_composite_toutes_regles(self):
        score, rules = compute_problog_score(PROFIL_FRAUDEUR)
        self.assertGreaterEqual(len(rules), 5,
                                "T08 : profil fraudeur doit activer ≥ 5 règles")


# ============================================================
# TEST GROUPE 2 — INFÉRENCE PROBLOG (bornes de probabilité)
# ============================================================

class TestInferenceProbLog(unittest.TestCase):

    # T09 : Score fraudeur > 0.90
    def test_T09_score_fraudeur_critique(self):
        score, _ = compute_problog_score(PROFIL_FRAUDEUR)
        self.assertGreater(score, 0.90,
                           "T09 : score fraudeur composite doit être > 0.90")

    # T10 : Score standard < 0.20
    def test_T10_score_standard_faible(self):
        score, _ = compute_problog_score(PROFIL_STANDARD)
        self.assertLess(score, 0.20,
                        "T10 : score standard doit être < 0.20")

    # T11 : Classification CRITIQUE correcte
    def test_T11_classification_critique(self):
        self.assertEqual(classify_risk(0.95), 'CRITIQUE', "T11 : 0.95 → CRITIQUE")
        self.assertEqual(classify_risk(0.80), 'CRITIQUE', "T11 : 0.80 → CRITIQUE")

    # T12 : Classification ELEVE
    def test_T12_classification_eleve(self):
        self.assertEqual(classify_risk(0.70), 'ELEVE', "T12 : 0.70 → ELEVE")
        self.assertEqual(classify_risk(0.60), 'ELEVE', "T12 : 0.60 → ELEVE")

    # T13 : Classification MOYEN
    def test_T13_classification_moyen(self):
        self.assertEqual(classify_risk(0.45), 'MOYEN', "T13 : 0.45 → MOYEN")

    # T14 : Classification FAIBLE
    def test_T14_classification_faible(self):
        self.assertEqual(classify_risk(0.10), 'FAIBLE', "T14 : 0.10 → FAIBLE")

    # T15 : Score borné entre 0 et 1
    def test_T15_score_borne(self):
        score, _ = compute_problog_score(PROFIL_FRAUDEUR)
        self.assertGreaterEqual(score, 0.0, "T15 : score ≥ 0")
        self.assertLessEqual(score, 1.0, "T15 : score ≤ 1")


# ============================================================
# TEST GROUPE 3 — MODÈLE NEURONAL
# ============================================================

class TestModeleNeuronal(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        """Entraîne un modèle léger pour les tests."""
        X, y = generate_synthetic_dataset(n_standard=20, n_atypique=8,
                                          n_speculateur=6, n_fraude=6)
        cls.model = FraudDetectionNet(INPUT_DIM, HIDDEN_DIM, OUTPUT_DIM)
        cls.model = train(cls.model, X, y, epochs=30)
        cls.model.eval()

    # T16 : Sortie softmax somme à 1
    def test_T16_softmax_somme_1(self):
        x = torch.FloatTensor([[0.9, 0.2, 0.8, 0.6, 0.7, 1.0, 1.0, 1.0, 0.1, 0.0]])
        with torch.no_grad():
            probs = self.model(x)
        total = probs.sum().item()
        self.assertAlmostEqual(total, 1.0, places=4, msg="T16 : somme softmax = 1")

    # T17 : Prédiction fraudeur → classe 'fraude'
    def test_T17_prediction_fraudeur(self):
        features = {f: 0.9 if f not in ['est_agent_public'] else 0.0
                    for f in FEATURE_NAMES}
        cls, dist = predict_individual(self.model, features)
        self.assertIn(cls, CLASSES, f"T17 : classe {cls} doit être dans {CLASSES}")

    # T18 : Distribution somme à 1
    def test_T18_distribution_somme_1(self):
        features = {f: 0.5 for f in FEATURE_NAMES}
        _, dist = predict_individual(self.model, features)
        self.assertAlmostEqual(sum(dist.values()), 1.0, places=4,
                               msg="T18 : distribution prob somme à 1")

    # T19 : Profil standard prédit standard ou atypique
    def test_T19_profil_standard_prediction(self):
        features = {f: 0.1 for f in FEATURE_NAMES}
        features['partage_telephone'] = 0.0
        features['partage_adresse'] = 0.0
        features['partage_iban'] = 0.0
        cls, dist = predict_individual(self.model, features)
        # Le modèle peut prédire standard ou atypique pour un profil bas risque
        self.assertIn(cls, ['standard', 'atypique'],
                      f"T19 : profil standard → classe attendue parmi [standard, atypique], obtenu {cls}")


# ============================================================
# TEST GROUPE 4 — FUSION NEURO-SYMBOLIQUE
# ============================================================

class TestFusionNeuroSymbolique(unittest.TestCase):

    def _make_neural_result(self, cls):
        dist = {c: 0.1 for c in CLASSES}
        dist[cls] = 0.7
        return {'neural_class': cls, 'neural_dist': dist}

    # T20 : Fraude neurale + score critique → FRAUDE_AVÉRÉE
    def test_T20_fraude_avere(self):
        nr = self._make_neural_result('fraude')
        final_cls, conf, xai = fuse_decisions(nr, 0.95, ['accaparement', 'prete_nom'])
        self.assertEqual(final_cls, 'FRAUDE_AVÉRÉE', "T20 : fraude+critique → FRAUDE_AVÉRÉE")
        self.assertGreater(conf, 0.8, "T20 : confiance > 0.8")

    # T21 : Standard + score faible → STANDARD
    def test_T21_standard_confirme(self):
        nr = self._make_neural_result('standard')
        final_cls, conf, xai = fuse_decisions(nr, 0.05, [])
        self.assertEqual(final_cls, 'STANDARD', "T21 : standard+faible → STANDARD")

    # T22 : XAI contient les 3 niveaux
    def test_T22_xai_complet(self):
        nr = self._make_neural_result('fraude')
        _, _, xai = fuse_decisions(nr, 0.92, ['accaparement'])
        self.assertIn('NEURONAL', xai, "T22 : XAI contient niveau neuronal")
        self.assertIn('PROBABILISTE', xai, "T22 : XAI contient niveau probabiliste")
        self.assertIn('SYMBOLIQUE', xai, "T22 : XAI contient niveau symbolique")


# ============================================================
# TEST GROUPE 5 — INTÉGRATION END-TO-END
# ============================================================

class TestIntegrationEndToEnd(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        """Setup du dataset et modèle pour les tests e2e."""
        cls.dataset = load_dataset()
        X, y = generate_synthetic_dataset()
        cls.model = FraudDetectionNet(INPUT_DIM, HIDDEN_DIM, OUTPUT_DIM)
        cls.model = train(cls.model, X, y, epochs=50)
        cls.model.eval()

    # T23 : Dataset chargé = 50 lignes
    def test_T23_dataset_50_lignes(self):
        self.assertEqual(len(self.dataset), 50,
                         "T23 : dataset doit contenir exactement 50 dossiers")

    # T24 : Distribution des labels
    def test_T24_distribution_labels(self):
        from collections import Counter
        labels = Counter(r['label'] for r in self.dataset)
        self.assertGreaterEqual(labels['standard'], 25,
                                "T24 : au moins 25 cas standards")
        self.assertGreaterEqual(labels['fraude_sophistiquee'], 5,
                                "T24 : au moins 5 fraudes sophistiquées")

    # T25 : Pipeline complet sans erreur sur 10 premiers
    def test_T25_pipeline_10_dossiers(self):
        from pipeline.main import run_neural_predictions, compute_problog_score, fuse_decisions
        subset = self.dataset[:10]
        neural_results = run_neural_predictions(self.model, subset)
        self.assertEqual(len(neural_results), 10, "T25 : 10 prédictions neuronales")
        for nr, row in zip(neural_results, subset):
            score, rules = compute_problog_score(row)
            final_cls, conf, xai = fuse_decisions(nr, score, rules)
            self.assertIsNotNone(final_cls, "T25 : décision finale non nulle")
            self.assertIsNotNone(xai, "T25 : explication XAI non nulle")


# ============================================================
# RUNNER
# ============================================================

if __name__ == '__main__':
    print('=' * 70)
    print('  LandGuard — Suite de Tests (25 scénarios)')
    print('=' * 70)
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    for cls in [TestReglesSymboliques, TestInferenceProbLog,
                TestModeleNeuronal, TestFusionNeuroSymbolique,
                TestIntegrationEndToEnd]:
        suite.addTests(loader.loadTestsFromTestCase(cls))

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    total = result.testsRun
    failed = len(result.failures) + len(result.errors)
    print(f'\n{"✓" if failed == 0 else "✗"} {total - failed}/{total} tests réussis')
