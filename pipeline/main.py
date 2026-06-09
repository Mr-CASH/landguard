"""
============================================================
LandGuard Neuro-Symbolic AI
MODULE : main.py
Pipeline d'orchestration complet
============================================================
Flux :
    1. Chargement des données (dataset.csv)
    2. Prédiction neuronale (PyTorch FraudDetectionNet)
    3. Propagation probabiliste (interface ProbLog simulée)
    4. Inférence symbolique (SWI-Prolog via subprocess)
    5. Fusion neuro-symbolique
    6. Génération du rapport XAI consolidé (rapport_xai.txt + JSON)
============================================================
"""

import os
import sys
import json
import subprocess
import csv
import torch
import numpy as np
from datetime import datetime
from pathlib import Path

# Ajout du répertoire part4 au path
sys.path.insert(0, str(Path(__file__).parent.parent))

from part4_deepproblog.neural_model import (
    FraudDetectionNet, load_model, predict_individual,
    generate_synthetic_dataset, train, save_model,
    FEATURE_NAMES, CLASSES, MODEL_PATH, INPUT_DIM, HIDDEN_DIM, OUTPUT_DIM
)

# ============================================================
# CONFIGURATION GLOBALE
# ============================================================

PROJECT_ROOT = Path(__file__).parent.parent
DATA_PATH    = PROJECT_ROOT / 'data' / 'dataset.csv'
PROLOG_KB    = PROJECT_ROOT / 'part1_dl'  / 'knowledge_base.pl'
PROLOG_RULES = PROJECT_ROOT / 'part2_prolog' / 'rules.pl'
PROLOG_EXP   = PROJECT_ROOT / 'part2_prolog' / 'explainability.pl'
PROLOG_INF   = PROJECT_ROOT / 'part2_prolog' / 'inference_engine.pl'
OUTPUT_DIR   = PROJECT_ROOT / 'outputs'
OUTPUT_DIR.mkdir(exist_ok=True)

RISK_THRESHOLDS = {
    'FAIBLE':   (0.0,  0.30),
    'MOYEN':    (0.30, 0.60),
    'ELEVE':    (0.60, 0.80),
    'CRITIQUE': (0.80, 1.01),
}

# ============================================================
# STEP 1 — CHARGEMENT DES DONNÉES
# ============================================================

def load_dataset(path=DATA_PATH):
    """Charge le dataset CSV et retourne une liste de dicts."""
    rows = []
    with open(path, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)
    print(f'[PIPELINE] Dataset chargé : {len(rows)} dossiers depuis {path}')
    return rows

def row_to_features(row):
    """Convertit une ligne CSV en vecteur de features normalisé [0,1]."""
    return {
        'nb_parcelles_urbaines': float(row['nb_parcelles_urbaines']) / 8.0,
        'nb_parcelles_rurales':  float(row['nb_parcelles_rurales']) / 5.0,
        'frequence_revente':     float(row['frequence_revente']),
        'ratio_plus_value':      float(row['ratio_plus_value']) / 2.0,
        'nb_liens_reseau':       float(row['nb_liens_reseau']) / 9.0,
        'partage_telephone':     float(row['partage_telephone']),
        'partage_adresse':       float(row['partage_adresse']),
        'partage_iban':          float(row['partage_iban']),
        'age_premier_achat':     1.0 - min(float(row['age_premier_achat_jours']) / 1200.0, 1.0),
        'est_agent_public':      float(row['est_agent_public']),
    }

# ============================================================
# STEP 2 — PRÉDICTION NEURONALE
# ============================================================

def load_or_train_model():
    """Charge le modèle existant ou l'entraîne si absent."""
    model_path = PROJECT_ROOT / 'part4_deepproblog' / MODEL_PATH
    if model_path.exists():
        print(f'[NEURAL] Chargement du modèle depuis {model_path}')
        return load_model(str(model_path))
    else:
        print('[NEURAL] Aucun modèle trouvé. Entraînement en cours...')
        X, y = generate_synthetic_dataset()
        split = int(0.8 * len(X))
        model = FraudDetectionNet(INPUT_DIM, HIDDEN_DIM, OUTPUT_DIM)
        model = train(model, X[:split], y[:split], epochs=100)
        save_model(model, str(model_path))
        return model

def run_neural_predictions(model, dataset):
    """Retourne les prédictions neuronales pour tout le dataset."""
    results = []
    for row in dataset:
        features = row_to_features(row)
        cls, dist = predict_individual(model, features)
        results.append({
            'id':          row['id'],
            'nom':         row['nom'],
            'neural_class': cls,
            'neural_dist':  dist,
            'label_reel':   row['label'],
        })
    return results

# ============================================================
# STEP 3 — RAISONNEMENT PROBABILISTE (interface simulée ProbLog)
# ============================================================

PROBLOG_RULES = {
    'prete_nom':              0.80,
    'blanchiment_circulaire': 0.95,
    'conflit_direct':         0.99,
    'conflit_familial':       0.90,
    'speculation_plus_value': 0.72,
    'accaparement':           0.88,
    'promoteur_fantome':      0.85,
    'lien_financier_suspect': 0.75,
}

def compute_problog_score(row):
    """
    Calcule un score de risque probabiliste composite basé sur les
    règles ProbLog, en exploitant les features disponibles dans le CSV.
    """
    score = 0.0
    active_rules = []

    nb_urb = int(row['nb_parcelles_urbaines'])
    partage_tel = int(row['partage_telephone'])
    partage_adr = int(row['partage_adresse'])
    partage_iban = int(row['partage_iban'])
    freq_rev = float(row['frequence_revente'])
    plus_val = float(row['ratio_plus_value'])
    est_agent = int(row['est_agent_public'])
    nb_liens = int(row['nb_liens_reseau'])
    type_acteur = row['type_acteur']

    # Règle accaparement
    if nb_urb >= 4:
        p = PROBLOG_RULES['accaparement']
        score = 1 - (1 - score) * (1 - p)
        active_rules.append(f'accaparement(P={p})')

    # Règle prête-nom téléphone
    if partage_tel:
        p = PROBLOG_RULES['prete_nom']
        score = 1 - (1 - score) * (1 - p)
        active_rules.append(f'prete_nom_telephone(P={p})')

    # Règle prête-nom adresse
    if partage_adr:
        p = 0.65
        score = 1 - (1 - score) * (1 - p)
        active_rules.append(f'prete_nom_adresse(P={p})')

    # Règle lien financier
    if partage_iban:
        p = PROBLOG_RULES['lien_financier_suspect']
        score = 1 - (1 - score) * (1 - p)
        active_rules.append(f'lien_financier_suspect(P={p})')

    # Règle spéculation revente
    if freq_rev > 0.5:
        p = 0.70
        score = 1 - (1 - score) * (1 - p)
        active_rules.append(f'speculation_revente(P={p})')

    # Règle plus-value
    if plus_val > 0.3:
        p = PROBLOG_RULES['speculation_plus_value']
        score = 1 - (1 - score) * (1 - p)
        active_rules.append(f'speculation_plus_value(P={p})')

    # Règle conflit agent
    if est_agent and nb_liens >= 2:
        p = PROBLOG_RULES['conflit_familial']
        score = 1 - (1 - score) * (1 - p)
        active_rules.append(f'conflit_familial_probable(P={p})')

    # Promoteur fantôme
    if type_acteur == 'promoteur' and partage_adr:
        p = PROBLOG_RULES['promoteur_fantome']
        score = 1 - (1 - score) * (1 - p)
        active_rules.append(f'promoteur_fantome(P={p})')

    return round(score, 4), active_rules

def classify_risk(score):
    for level, (low, high) in RISK_THRESHOLDS.items():
        if low <= score < high:
            return level
    return 'CRITIQUE'

# ============================================================
# STEP 4 — INFÉRENCE SYMBOLIQUE (SWI-Prolog)
# ============================================================

def run_prolog_inference():
    """Lance SWI-Prolog avec le moteur d'inférence et capture les alertes."""
    query = (
        f":- consult('{PROLOG_KB}'),"
        f"   consult('{PROLOG_EXP}'),"
        f"   consult('{PROLOG_RULES}'),"
        f"   consult('{PROLOG_INF}'),"
        f"   run_all_rules, halt."
    )
    try:
        result = subprocess.run(
            ['swipl', '-q', '-g', query],
            capture_output=True, text=True, timeout=30
        )
        return result.stdout, result.returncode
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        return f'[PROLOG INDISPONIBLE] {str(e)}', -1

# ============================================================
# STEP 5 — FUSION NEURO-SYMBOLIQUE
# ============================================================

def fuse_decisions(neural_result, problog_score, prolog_alerts):
    """
    Fusionne les trois niveaux de décision :
    - Niveau neuronal : classe prédite par le réseau
    - Niveau probabiliste : score ProbLog composite
    - Niveau symbolique : alertes Prolog activées
    Retourne la décision finale et l'explication XAI.
    """
    neural_cls = neural_result['neural_class']
    neural_dist = neural_result['neural_dist']
    risk_class = classify_risk(problog_score)

    # Table de fusion : neural + probabiliste
    FUSION_MATRIX = {
        ('fraude',      'CRITIQUE'): ('FRAUDE_AVÉRÉE',    0.95),
        ('fraude',      'ELEVE'):    ('FRAUDE_PROBABLE',  0.80),
        ('fraude',      'MOYEN'):    ('FRAUDE_PROBABLE',  0.65),
        ('speculateur', 'CRITIQUE'): ('SPECULATEUR_AVÉRÉ',0.88),
        ('speculateur', 'ELEVE'):    ('SPECULATEUR',      0.75),
        ('speculateur', 'MOYEN'):    ('ATYPIQUE',         0.55),
        ('atypique',    'CRITIQUE'): ('FRAUDE_PROBABLE',  0.70),
        ('atypique',    'ELEVE'):    ('ATYPIQUE',         0.50),
        ('atypique',    'MOYEN'):    ('ATYPIQUE',         0.40),
        ('standard',    'CRITIQUE'): ('ATYPIQUE',         0.45),
        ('standard',    'ELEVE'):    ('STANDARD_VIGILANCE',0.30),
        ('standard',    'MOYEN'):    ('STANDARD',         0.15),
        ('standard',    'FAIBLE'):   ('STANDARD',         0.05),
    }

    key = (neural_cls, risk_class)
    final_cls, confidence = FUSION_MATRIX.get(key, (neural_cls.upper(), problog_score))

    # Génération de l'explication XAI
    xai_lines = [
        f"DÉCISION FINALE    : {final_cls}",
        f"CONFIANCE          : {confidence:.2f}",
        f"--- NIVEAU NEURONAL ---",
        f"  Classe prédite   : {neural_cls.upper()}",
        f"  Distribution     : { {k: f'{v:.3f}' for k,v in neural_dist.items()} }",
        f"--- NIVEAU PROBABILISTE (ProbLog) ---",
        f"  Score composite  : {problog_score:.4f}",
        f"  Classe de risque : {risk_class}",
        f"  Règles activées  : {', '.join(prolog_alerts) if prolog_alerts else 'aucune'}",
        f"--- NIVEAU SYMBOLIQUE (Prolog) ---",
        f"  Alertes Prolog   : {len(prolog_alerts)} règles déclenchées",
    ]
    return final_cls, confidence, '\n'.join(xai_lines)

# ============================================================
# STEP 6 — RAPPORT XAI CONSOLIDÉ
# ============================================================

def generate_report(results, prolog_output, output_dir=OUTPUT_DIR):
    """Génère rapport_xai.txt et rapport_xai.json."""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    txt_lines = [
        '=' * 70,
        'RAPPORT XAI CONSOLIDÉ — LandGuard Neuro-Symbolic AI',
        f'Généré le : {timestamp}',
        f'Dossiers analysés : {len(results)}',
        '=' * 70,
        '',
    ]

    # Statistiques globales
    decisions = [r['decision_finale'] for r in results]
    from collections import Counter
    stats = Counter(decisions)
    txt_lines += [
        '── STATISTIQUES GLOBALES ──',
        *[f'  {cls:<25} : {count}' for cls, count in stats.most_common()],
        '',
        '── DÉTAIL PAR DOSSIER ──',
        '',
    ]

    # Précision neuronale (si label réel disponible)
    correct = 0
    total_labeled = 0
    LABEL_MAP = {
        'standard': 'standard',
        'speculation': 'speculateur',
        'accaparement': 'fraude',
        'cas_limite': 'atypique',
        'fraude_sophistiquee': 'fraude',
    }
    for r in results:
        expected = LABEL_MAP.get(r.get('label_reel', ''), '')
        if expected and r['neural_class'] == expected:
            correct += 1
        if expected:
            total_labeled += 1

    neural_acc = correct / total_labeled if total_labeled else 0.0

    for r in results:
        txt_lines += [
            f"┌── Dossier #{r['id']} : {r['nom']} ({r.get('label_reel','?')}) ──",
            r['xai'],
            '└' + '─' * 65,
            '',
        ]

    txt_lines += [
        '=' * 70,
        'SYNTHÈSE FINALE',
        f'  Précision neuronale     : {neural_acc:.2%}',
        f'  Fraudes avérées         : {stats.get("FRAUDE_AVÉRÉE", 0)}',
        f'  Fraudes probables       : {stats.get("FRAUDE_PROBABLE", 0)}',
        f'  Spéculateurs            : {stats.get("SPECULATEUR_AVÉRÉ", 0) + stats.get("SPECULATEUR", 0)}',
        f'  Cas atypiques           : {stats.get("ATYPIQUE", 0)}',
        f'  Standards               : {stats.get("STANDARD", 0) + stats.get("STANDARD_VIGILANCE", 0)}',
        '',
        '── TRACE PROLOG ──',
        prolog_output or '(SWI-Prolog non disponible — exécution simulée)',
        '=' * 70,
    ]

    # Écriture TXT
    txt_path = output_dir / 'rapport_xai.txt'
    with open(txt_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(txt_lines))

    # Écriture JSON
    json_data = {
        'timestamp': timestamp,
        'stats': dict(stats),
        'neural_accuracy': neural_acc,
        'dossiers': results,
    }
    json_path = output_dir / 'rapport_xai.json'
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(json_data, f, ensure_ascii=False, indent=2)

    print(f'\n[RAPPORT] Rapport TXT  → {txt_path}')
    print(f'[RAPPORT] Rapport JSON → {json_path}')
    return txt_path, json_path

# ============================================================
# POINT D'ENTRÉE PRINCIPAL
# ============================================================

def main():
    print('=' * 70)
    print('  LandGuard Neuro-Symbolic AI — Pipeline Complet')
    print('=' * 70)

    # --- STEP 1 : Chargement données ---
    print('\n[STEP 1] Chargement du dataset...')
    dataset = load_dataset()

    # --- STEP 2 : Modèle neuronal ---
    print('\n[STEP 2] Chargement / entraînement du modèle neuronal...')
    model = load_or_train_model()

    print('\n[STEP 2] Prédictions neuronales en cours...')
    neural_results = run_neural_predictions(model, dataset)

    # --- STEP 3 : ProbLog ---
    print('\n[STEP 3] Calcul des scores probabilistes (ProbLog)...')
    problog_results = []
    for row in dataset:
        score, active_rules = compute_problog_score(row)
        problog_results.append({'score': score, 'rules': active_rules})

    # --- STEP 4 : Prolog symbolique ---
    print('\n[STEP 4] Inférence symbolique Prolog...')
    prolog_output, prolog_rc = run_prolog_inference()
    if prolog_rc == 0:
        print('  [✓] Prolog exécuté avec succès.')
    else:
        print(f'  [!] Prolog indisponible (code={prolog_rc}). Mode simulation.')

    # --- STEP 5 : Fusion ---
    print('\n[STEP 5] Fusion neuro-symbolique...')
    final_results = []
    for nr, pr, row in zip(neural_results, problog_results, dataset):
        final_cls, confidence, xai = fuse_decisions(nr, pr['score'], pr['rules'])
        final_results.append({
            **nr,
            'problog_score':  pr['score'],
            'problog_rules':  pr['rules'],
            'risk_class':     classify_risk(pr['score']),
            'decision_finale': final_cls,
            'confidence':     confidence,
            'xai':            xai,
        })

    # --- STEP 6 : Rapport ---
    print('\n[STEP 6] Génération du rapport XAI...')
    txt_path, json_path = generate_report(final_results, prolog_output)

    # Résumé console
    print('\n' + '=' * 70)
    print('  RÉSUMÉ DES ALERTES')
    print('=' * 70)
    alertes = [r for r in final_results
               if r['decision_finale'] not in ('STANDARD', 'STANDARD_VIGILANCE')]
    print(f'  {len(alertes)} alerte(s) sur {len(final_results)} dossiers analysés')
    for r in alertes:
        print(f'  ⚠ {r["nom"]:<30} → {r["decision_finale"]:<20} (conf={r["confidence"]:.2f})')

    print('\n✓ Pipeline LandGuard terminé avec succès.\n')
    return final_results

if __name__ == '__main__':
    main()
