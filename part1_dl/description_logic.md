# LandGuard — Modélisation en Logique de Description (DL)

## 1. Taxonomie des Concepts (TBox)

```
Acteur ≡ Citoyen ⊔ AgentPublic ⊔ Promoteur ⊔ Notaire
Parcelle ≡ ParcelleUrbaine ⊔ ParcelleRurale
Affectation ≡ Attribution ⊔ Revente ⊔ Heritage
Dossier ≡ DossierActif ⊔ DossierSuspect
LienSocial ≡ LienFamilial ⊔ LienProfessionnel ⊔ LienFinancier
```

## 2. Rôles & Relations

| Rôle               | Domaine       | Co-domaine    | Description                                      |
| -------------------- | --------------- | --------------- | -------------------------------------------------- |
| possede(X,Y)       | Acteur        | Parcelle      | X est propriétaire de Y                         |
| traite(X,Y)        | AgentPublic   | Dossier       | X instruit le dossier Y                         |
| beneficiaire(X,Y)  | Acteur        | Affectation   | X bénéficie de l'affectation Y                  |
| lienFamilial(X,Y)  | Acteur        | Acteur        | X et Y ont un lien de parenté                   |
| vendA(X,Y)         | Acteur        | Acteur        | X a vendu une parcelle à Y                      |
| partageTelephone(X,Y) | Acteur     | Acteur        | X et Y partagent le même numéro de téléphone    |
| partageAdresse(X,Y)| Acteur        | Acteur        | X et Y partagent la même adresse physique       |
| partageIBAN(X,Y)   | Acteur        | Acteur        | X et Y utilisent le même compte bancaire        |
| concerne(D,P)      | Dossier       | Parcelle      | Le dossier D porte sur la parcelle P            |

## 3. Axiomes DL — 10 Axiomes Complexes

### AX-01 : Accaparement Urbain
```
Citoyen ⊓ (≥ 4 possede.ParcelleUrbaine) ⊑ AccapareurUrbain
```
**Sémantique :** Tout citoyen possédant au moins 4 parcelles urbaines est classé accapareur urbain.

---

### AX-02 : Conflit d'Intérêt Direct
```
AgentPublic ⊓ ∃traite.Dossier ⊓ ∃beneficiaire.Affectation ⊑ ConflitInteret
```
**Sémantique :** Un agent public qui traite un dossier dont il est lui-même bénéficiaire est en situation de conflit d'intérêt.

---

### AX-03 : Prête-nom par Téléphone Partagé
```
Citoyen ⊓ ∃partageTelephone.(Citoyen ⊓ ∃possede.Parcelle) ⊑ SuspectPreteNom
```
**Sémantique :** Un citoyen partageant son numéro de téléphone avec un autre propriétaire est suspecté d'être un prête-nom.

---

### AX-04 : Spéculateur Foncier
```
Acteur ⊓ (∃vendA.Acteur) ⊓ (≥ 2 possede.Parcelle) ⊑ Speculateur
```
**Sémantique :** Tout acteur ayant revendu et possédant encore au moins 2 parcelles est qualifié de spéculateur.

---

### AX-05 : Réseau Circulaire de Transactions
```
Acteur ⊓ ∃vendA.(Acteur ⊓ ∃vendA.(Acteur ⊓ ∃vendA.Self)) ⊑ ReseauCirculaire
```
**Sémantique :** Une chaîne de ventes qui revient au vendeur d'origine constitue un réseau circulaire suspect de blanchiment.

---

### AX-06 : Conflit d'Intérêt Familial (Agent)
```
AgentPublic ⊓ ∃traite.(Dossier ⊓ ∃concerne.(Parcelle ⊓ ∃possede⁻.(Acteur ⊓ ∃lienFamilial.Self))) ⊑ ConflitFamilial
```
**Sémantique :** Un agent traitant un dossier portant sur une parcelle appartenant à un de ses proches est en conflit familial.

---

### AX-07 : Promoteur Fantôme
```
Promoteur ⊓ (≤ 0 partageAdresse.Promoteur) ⊓ (= 1 partageIBAN.Acteur) ⊑ PromoteurFantome
```
**Sémantique :** Un promoteur sans adresse stable partageable mais lié à un compte IBAN commun est potentiellement fantôme.

---

### AX-08 : Multipropriété Familiale
```
Citoyen ⊓ ∃lienFamilial.(Citoyen ⊓ (≥ 3 possede.Parcelle)) ⊓ (≥ 2 possede.Parcelle) ⊑ MultiproprieteFamiliale
```
**Sémantique :** Un citoyen possédant ≥ 2 parcelles et ayant un proche possédant ≥ 3 parcelles forme un réseau de multipropriété familiale.

---

### AX-09 : Dossier Suspect Automatique
```
Dossier ⊓ ∃concerne.(Parcelle ⊓ ∃possede⁻.AccapareurUrbain) ⊑ DossierSuspect
```
**Sémantique :** Tout dossier portant sur une parcelle appartenant à un accapareur urbain est automatiquement classé suspect.

---

### AX-10 : Non-mise en Valeur
```
ParcelleUrbaine ⊓ (≥ 5 ans depuis Attribution) ⊓ ¬∃valorisation.Projet ⊑ ParcelleNonValorisee
```
**Sémantique :** Toute parcelle urbaine attribuée depuis plus de 5 ans sans projet de valorisation est déclarée non mise en valeur.

---

## 4. Contraintes d'Intégrité (8 CI)

| ID    | Contrainte formelle DL                                                                                              | Description                                                              |
|-------|---------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------|
| CI-1  | ¬∃x : AgentPublic(x) ∧ traite(x,d) ∧ beneficiaire(x,a) ∧ concerne(d,p) ∧ possede(x,p)                            | Un agent ne peut pas traiter son propre dossier foncier                  |
| CI-2  | AgentPublic ⊑ ≤ 3 possede.ParcelleUrbaine                                                                          | Maximum 3 parcelles urbaines par citoyen                                 |
| CI-3  | ¬(ParcelleUrbaine ⊓ ∃possede⁻.⊤ ⊓ ∃possede⁻.⊤) [deux individus distincts]                                        | Une parcelle ne peut appartenir qu'à un seul propriétaire à la fois      |
| CI-4  | ¬∃x,y : Revente(x) ∧ date(x,d1) ∧ Attribution(y) ∧ date(y,d2) ∧ (d1−d2 < 6 mois)                                | Pas de revente dans les 6 mois suivant une attribution                   |
| CI-5  | ∃x,y : partageTelephone(x,y) ∧ possede(x,p1) ∧ possede(y,p2) ∧ x≠y → SuspicionPreteNom(x,y)                      | Même téléphone entre deux acheteurs distincts ⇒ suspicion prête-nom     |
| CI-6  | ¬∃x : Notaire(x) ∧ lienFamilial(x,y) ∧ instruite(x,a) ∧ beneficiaire(y,a)                                         | Un notaire ne peut pas instrumenter une affectation bénéficiant à un proche |
| CI-7  | ∀x : Promoteur(x) → ∃adresse(x)                                                                                    | Tout promoteur doit avoir une adresse officielle enregistrée             |
| CI-8  | ¬∃x,y,z : vendA(x,y) ∧ vendA(y,z) ∧ vendA(z,x) ∧ interval(total) < 12 mois                                       | Circuit de ventes fermé en moins de 12 mois ⇒ blanchiment suspect       |

---

## 5. Correspondance DL → Prédicats Prolog

| Concept DL              | Prédicat Prolog                              |
|-------------------------|----------------------------------------------|
| Citoyen(x)              | `citoyen(X)`                                 |
| AgentPublic(x)          | `agent_public(X)`                            |
| Promoteur(x)            | `promoteur(X)`                               |
| Notaire(x)              | `notaire(X)`                                 |
| ParcelleUrbaine(p)      | `parcelle_urbaine(P)`                        |
| ParcelleRurale(p)       | `parcelle_rurale(P)`                         |
| possede(x,p)            | `possede(X,P)`                               |
| traite(a,d)             | `traite(A,D)`                                |
| beneficiaire(x,a)       | `beneficiaire(X,A)`                          |
| lienFamilial(x,y)       | `lien_familial(X,Y)`                         |
| vendA(x,y)              | `vend_a(X,Y,P,Date)`                         |
| partageTelephone(x,y)   | `partage_telephone(X,Y)`                     |
| partageAdresse(x,y)     | `partage_adresse(X,Y)`                       |
| partageIBAN(x,y)        | `partage_iban(X,Y)`                          |
| AccapareurUrbain(x)     | `accapareur_urbain(X)`                       |
| ConflitInteret(x)       | `conflit_interet(X)`                         |
| SuspectPreteNom(x)      | `suspect_prete_nom(X,Y)`                     |
| ReseauCirculaire        | `reseau_circulaire(X,Y,Z)`                   |
| DossierSuspect(d)       | `dossier_suspect(D)`                         |
