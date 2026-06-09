"""
============================================================
LandGuard Neuro-Symbolic AI
MODULE : neural_model.py
Partie 4 — Module neuronal PyTorch pour la classification de fraude
============================================================
Classes de sortie :
    0 : STANDARD
    1 : ATYPIQUE
    2 : SPECULATEUR
    3 : FRAUDEUR_PROBABLE
============================================================
"""

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset
import numpy as np
import os

# ============================================================
# CONFIGURATION
# ============================================================
CLASSES = ['standard', 'atypique', 'speculateur', 'fraude']
INPUT_DIM = 10   # nombre de features
HIDDEN_DIM = 64
OUTPUT_DIM = 4   # 4 classes
DROPOUT_RATE = 0.3
LR = 1e-3
EPOCHS = 100
BATCH_SIZE = 16
MODEL_PATH = 'model_weights.pth'

# ============================================================
# FEATURES UTILISÉES
# ============================================================
FEATURE_NAMES = [
    'nb_parcelles_urbaines',   # F1
    'nb_parcelles_rurales',    # F2
    'frequence_revente',       # F3 : nb reventes / durée totale
    'ratio_plus_value',        # F4 : (prix_vente - val_cadastre) / val_cadastre
    'nb_liens_reseau',         # F5 : nb de liens familiaux/financiers
    'partage_telephone',       # F6 : binaire 0/1
    'partage_adresse',         # F7 : binaire 0/1
    'partage_iban',            # F8 : binaire 0/1
    'age_premier_achat',       # F9 : ancienneté en jours
    'est_agent_public',        # F10 : binaire 0/1
]

# ============================================================
# ARCHITECTURE DU RÉSEAU
# ============================================================
class FraudDetectionNet(nn.Module):
    """
    Réseau de neurones entièrement connecté (MLP) pour la classification
    de fraude foncière. Architecture :
        Input(10) → BN → Dense(64) → ReLU → Dropout(0.3)
                 → Dense(32) → ReLU → Dropout(0.3)
                 → Dense(16) → ReLU
                 → Output(4) → Softmax
    """
    def __init__(self, input_dim=INPUT_DIM, hidden_dim=HIDDEN_DIM,
                 output_dim=OUTPUT_DIM, dropout=DROPOUT_RATE):
        super(FraudDetectionNet, self).__init__()

        self.batch_norm = nn.BatchNorm1d(input_dim)

        self.network = nn.Sequential(
            nn.Linear(input_dim, hidden_dim),
            nn.ReLU(),
            nn.Dropout(dropout),

            nn.Linear(hidden_dim, hidden_dim // 2),
            nn.ReLU(),
            nn.Dropout(dropout),

            nn.Linear(hidden_dim // 2, hidden_dim // 4),
            nn.ReLU(),

            nn.Linear(hidden_dim // 4, output_dim)
        )

        self.softmax = nn.Softmax(dim=1)
        self._init_weights()

    def _init_weights(self):
        """Initialisation Xavier pour stabiliser l'entraînement."""
        for layer in self.network:
            if isinstance(layer, nn.Linear):
                nn.init.xavier_uniform_(layer.weight)
                nn.init.zeros_(layer.bias)

    def forward(self, x):
        x = self.batch_norm(x)
        logits = self.network(x)
        probs = self.softmax(logits)
        return probs

    def predict_class(self, x):
        """Retourne la classe prédite et la distribution de probabilité."""
        with torch.no_grad():
            probs = self.forward(x)
            cls_idx = torch.argmax(probs, dim=1)
            cls_labels = [CLASSES[i] for i in cls_idx.tolist()]
            return cls_labels, probs

# ============================================================
# GÉNÉRATION DE DONNÉES SYNTHÉTIQUES D'ENTRAÎNEMENT
# ============================================================

def generate_synthetic_dataset(n_standard=60, n_atypique=20,
                                n_speculateur=15, n_fraude=15,
                                noise_std=0.05):
    """
    Génère un dataset synthétique réaliste basé sur les prototypes
    de chaque classe de fraude foncière.
    """
    rng = np.random.default_rng(42)

    def noisy(arr):
        return arr + rng.normal(0, noise_std, arr.shape)

    # --- STANDARD (classe 0) ---
    standard = noisy(np.array([
        [rng.uniform(0, 1), rng.uniform(0, 1),    # nb parcelles (0-1)
         rng.uniform(0, 0.1), rng.uniform(-0.05, 0.15),  # revente lente, pas de plus-value
         rng.integers(0, 2), 0, 0, 0,              # peu de liens, pas de partage
         rng.uniform(500, 1000), 0]                # ancienneté normale, pas agent
        for _ in range(n_standard)
    ]))

    # --- ATYPIQUE (classe 1) ---
    atypique = noisy(np.array([
        [rng.uniform(1, 2), rng.uniform(0, 1),
         rng.uniform(0.1, 0.3), rng.uniform(0.1, 0.3),
         rng.integers(1, 3), rng.choice([0, 1], p=[0.7, 0.3]),
         rng.choice([0, 1], p=[0.8, 0.2]), 0,
         rng.uniform(200, 700), rng.choice([0, 1], p=[0.9, 0.1])]
        for _ in range(n_atypique)
    ]))

    # --- SPECULATEUR (classe 2) ---
    speculateur = noisy(np.array([
        [rng.uniform(2, 5), rng.uniform(0, 2),
         rng.uniform(0.4, 0.8), rng.uniform(0.3, 0.8),
         rng.integers(2, 5), rng.choice([0, 1], p=[0.5, 0.5]),
         rng.choice([0, 1], p=[0.6, 0.4]), rng.choice([0, 1], p=[0.7, 0.3]),
         rng.uniform(100, 400), 0]
        for _ in range(n_speculateur)
    ]))

    # --- FRAUDEUR PROBABLE (classe 3) ---
    fraudeur = noisy(np.array([
        [rng.uniform(4, 8), rng.uniform(1, 3),
         rng.uniform(0.6, 1.0), rng.uniform(0.5, 1.5),
         rng.integers(4, 8), 1, 1,
         rng.choice([0, 1], p=[0.3, 0.7]),
         rng.uniform(50, 300), rng.choice([0, 1], p=[0.6, 0.4])]
        for _ in range(n_fraude)
    ]))

    X = np.vstack([standard, atypique, speculateur, fraudeur]).astype(np.float32)
    y = np.array(
        [0] * n_standard + [1] * n_atypique +
        [2] * n_speculateur + [3] * n_fraude,
        dtype=np.int64
    )

    # Normalisation min-max feature par feature
    X_min = X.min(axis=0, keepdims=True)
    X_max = X.max(axis=0, keepdims=True)
    X = (X - X_min) / (X_max - X_min + 1e-8)

    # Mélange
    idx = np.random.permutation(len(y))
    return X[idx], y[idx]

# ============================================================
# ENTRAÎNEMENT
# ============================================================

def train(model, X_train, y_train, epochs=EPOCHS, lr=LR):
    """Boucle d'entraînement avec loss CrossEntropy et optim Adam."""
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=lr, weight_decay=1e-4)
    scheduler = optim.lr_scheduler.StepLR(optimizer, step_size=30, gamma=0.5)

    X_t = torch.FloatTensor(X_train)
    y_t = torch.LongTensor(y_train)

    dataset = TensorDataset(X_t, y_t)
    loader = DataLoader(dataset, batch_size=BATCH_SIZE, shuffle=True)

    model.train()
    for epoch in range(epochs):
        total_loss = 0.0
        for batch_X, batch_y in loader:
            optimizer.zero_grad()
            outputs = model(batch_X)
            loss = criterion(outputs, batch_y)
            loss.backward()
            optimizer.step()
            total_loss += loss.item()

        scheduler.step()
        if (epoch + 1) % 20 == 0:
            avg_loss = total_loss / len(loader)
            print(f'  Époque [{epoch+1:3d}/{epochs}] | Loss: {avg_loss:.4f}')

    return model

# ============================================================
# ÉVALUATION
# ============================================================

def evaluate(model, X_test, y_test):
    """Calcul précision et matrice de confusion simplifiée."""
    model.eval()
    X_t = torch.FloatTensor(X_test)
    with torch.no_grad():
        probs = model(X_t)
        preds = torch.argmax(probs, dim=1).numpy()

    accuracy = (preds == y_test).mean()
    print(f'\n  Accuracy : {accuracy:.4f} ({accuracy*100:.1f}%)')

    # Matrice de confusion
    from collections import Counter
    print('\n  Distribution des prédictions :')
    counter = Counter(preds)
    for i, cls in enumerate(CLASSES):
        print(f'    {cls:<20} : {counter.get(i, 0)} prédictions')

    return accuracy

# ============================================================
# PRÉDICTION SUR UN INDIVIDU (interface pour DeepProbLog)
# ============================================================

def predict_individual(model, features_dict):
    """
    Prédit la classe d'un individu donné ses features.
    features_dict : dict {feature_name: value}
    Retourne : (classe_str, distribution_dict)
    """
    model.eval()
    features = np.array([features_dict.get(f, 0.0) for f in FEATURE_NAMES],
                        dtype=np.float32)
    x = torch.FloatTensor(features).unsqueeze(0)
    with torch.no_grad():
        probs = model(x).squeeze(0).numpy()

    cls_idx = int(np.argmax(probs))
    return CLASSES[cls_idx], {cls: float(p) for cls, p in zip(CLASSES, probs)}

# ============================================================
# SAUVEGARDE / CHARGEMENT
# ============================================================

def save_model(model, path=MODEL_PATH):
    torch.save({
        'model_state_dict': model.state_dict(),
        'input_dim': INPUT_DIM,
        'hidden_dim': HIDDEN_DIM,
        'output_dim': OUTPUT_DIM,
    }, path)
    print(f'\n  Modèle sauvegardé : {path}')

def load_model(path=MODEL_PATH):
    checkpoint = torch.load(path, weights_only=False)
    model = FraudDetectionNet(
        input_dim=checkpoint['input_dim'],
        hidden_dim=checkpoint['hidden_dim'],
        output_dim=checkpoint['output_dim']
    )
    model.load_state_dict(checkpoint['model_state_dict'])
    model.eval()
    print(f'  Modèle chargé : {path}')
    return model

# ============================================================
# POINT D'ENTRÉE
# ============================================================

if __name__ == '__main__':
    print('=' * 60)
    print('LandGuard — Entraînement du modèle neuronal')
    print('=' * 60)

    # Génération données
    print('\n[1] Génération du dataset synthétique...')
    X, y = generate_synthetic_dataset()
    split = int(0.8 * len(X))
    X_train, X_test = X[:split], X[split:]
    y_train, y_test = y[:split], y[split:]
    print(f'    Train: {len(X_train)} | Test: {len(X_test)}')

    # Instanciation
    print('\n[2] Instanciation du réseau FraudDetectionNet...')
    model = FraudDetectionNet()
    total_params = sum(p.numel() for p in model.parameters())
    print(f'    Paramètres totaux : {total_params}')

    # Entraînement
    print('\n[3] Entraînement...')
    model = train(model, X_train, y_train)

    # Évaluation
    print('\n[4] Évaluation...')
    evaluate(model, X_test, y_test)

    # Test sur un individu fictif (profil fraudeur)
    print('\n[5] Prédiction individuelle — Profil "abdou"...')
    abdou_features = {
        'nb_parcelles_urbaines': 0.9,
        'nb_parcelles_rurales': 0.2,
        'frequence_revente': 0.7,
        'ratio_plus_value': 0.5,
        'nb_liens_reseau': 0.6,
        'partage_telephone': 1.0,
        'partage_adresse': 1.0,
        'partage_iban': 1.0,
        'age_premier_achat': 0.3,
        'est_agent_public': 0.0,
    }
    cls, dist = predict_individual(model, abdou_features)
    print(f'    Classe prédite : {cls.upper()}')
    print(f'    Distribution   : { {k: f"{v:.3f}" for k,v in dist.items()} }')

    # Sauvegarde
    print('\n[6] Sauvegarde...')
    save_model(model)

    print('\n✓ Pipeline neuronal terminé avec succès.')
