# LandGuard Neuro-Symbolic AI

> Système hybride de détection de fraude foncière combinant  
> Logique de Description · SWI-Prolog · ProbLog · DeepProbLog · PyTorch

---

## Architecture du projet

```text
landguard/
├── part1_dl/
│   ├── knowledge_base.pl        # Base de faits (DL → Prolog)
│   └── description_logic.md     # Axiomes DL formalisés (10 axiomes, 8 CI)
├── part2_prolog/
│   ├── rules.pl                 # 15+ règles logiques (4 catégories)
│   ├── inference_engine.pl      # Moteur d'inférence
│   └── explainability.pl        # Traces XAI
├── part3_problog/
│   ├── probabilistic_rules.pl   # Règles pondérées ProbLog
│   ├── queries.pl               # Requêtes d'inférence
│   └── rapport_inference_prob.txt
├── part4_deepproblog/
│   ├── neural_model.py          # FraudDetectionNet (PyTorch)
│   ├── deepproblog_model.pl     # Prédicats neuro-symboliques
│   └── model_weights.pth        # Poids entraînés (généré)
├── pipeline/
│   └── main.py                  # Orchestrateur principal
├── data/
│   └── dataset.csv              # 50 dossiers synthétiques
├── tests/
│   └── test_suite.py            # 25 scénarios de tests
├── outputs/                     # Rapports générés
└── README.md
```

---

## Prérequis

| Outil       | Version recommandée |
|-------------|---------------------|
| Python      | ≥ 3.10              |
| PyTorch     | ≥ 2.0               |
| SWI-Prolog  | ≥ 9.0               |
| ProbLog     | ≥ 2.1               |
| DeepProbLog | ≥ 1.0               |

---

## Installation

### 1. Cloner le dépôt

```bash
git clone https://github.com/Mr-CASH/landguard.git
cd landguard
```

### 2. Environnement Python

```bash
python -m venv venv
source venv/bin/activate          # Linux / macOS
# ou : venv\Scripts\activate      # Windows

pip install torch numpy
```

### 3. SWI-Prolog

```bash
# Ubuntu / Debian
sudo apt install swi-prolog

# macOS
brew install swi-prolog

# Vérification
swipl --version
```

### 4. ProbLog & DeepProbLog

```bash
pip install problog deepproblog
```

---

## Exécution

### Pipeline complet

```bash
python pipeline/main.py
```

Produit dans `outputs/` :

- `rapport_xai.txt`  — rapport texte complet avec traces d'inférence
- `rapport_xai.json` — rapport structuré pour intégration systèmes tiers

---

### Module neuronal seul

```bash
cd part4_deepproblog
python neural_model.py
```

Entraîne le modèle, affiche la précision et sauvegarde `model_weights.pth`.

---

### Inférence Prolog seule

```bash
swipl -q -l part1_dl/knowledge_base.pl \
         -l part2_prolog/explainability.pl \
         -l part2_prolog/rules.pl \
         -l part2_prolog/inference_engine.pl \
         -g "run_all_rules, halt."
```

Pour analyser un acteur spécifique :

```bash
swipl -q -l part1_dl/knowledge_base.pl \
         -l part2_prolog/explainability.pl \
         -l part2_prolog/rules.pl \
         -l part2_prolog/inference_engine.pl \
         -g "analyse_acteur(abdou), halt."
```

---

### Inférence ProbLog

```bash
cd part3_problog
problog probabilistic_rules.pl
problog queries.pl
```

---

### Suite de tests

```bash  
python tests/test_suite.py
```

Exécute les 25 scénarios (unitaires + intégration) et affiche le bilan.

---

## Scénarios de fraude couverts

| ID | Type | Acteur | Mécanisme détecté |
| ---- | ------ | -------- | ------------------- |
| 36 | Accaparement | abdou | 5 parcelles + téléphone + IBAN |
| 46 | Réseau familial prête-noms | reseau_familial | Tous indicateurs combinés |
| 47 | Conflit indirect notaire | conflit_indirect | Agent + notaire lié + bénéficiaire indirect |
| 48 | Blanchiment circulaire | blanchiment_circulaire_act | Circuit ibrahim→fatou→moussa→ibrahim (120j) |
| 49 | Promoteur fantôme | promoteur_fantome_act | Sans adresse + IBAN partagé |
| 50 | Fraude composite | fraude_composite_act | Accaparement + réseau + spéculation |

---

## Auteur

Projet réalisé dans le cadre du cours d'IA Symbolique & Neuro-Symbolique par le groupe composé de :

- **HIEN S. Arrold Claude H.**
- **ZOUGMORE Hubertine**
- **KISSOU René**
