%% ============================================================
%% LandGuard Neuro-Symbolic AI
%% MODULE : rules.pl
%% Partie 2 — Règles logiques Prolog (4 catégories)
%% ============================================================

:- module(rules, [
    accaparement_urbain/1,
    accaparement_rural/1,
    multipropriete_familiale/2,
    speculation_revente_rapide/3,
    speculation_plus_value_anormale/3,
    non_mise_en_valeur/1,
    conflit_interet_direct/1,
    conflit_interet_familial/2,
    conflit_interet_professionnel/2,
    favoritisme_repetitif/2,
    prete_nom_telephone/2,
    prete_nom_adresse/2,
    reseau_circulaire/3,
    structure_financiere_partagee/2,
    fraude_composite/1,
    dossier_suspect_derivee/1
]).

:- use_module('../part1_dl/knowledge_base').
:- use_module(explainability).

%% ============================================================
%% CATÉGORIE A — ACCAPAREMENT
%% ============================================================

%% REGLE-A1 : Accaparement Urbain
%% Un citoyen possédant ≥ 4 parcelles urbaines
accaparement_urbain(X) :-
    citoyen(X),
    findall(P, (possede(X, P), parcelle_urbaine(P)), Parcelles),
    length(Parcelles, N),
    N >= 4,
    log_alerte('REGLE-A1', [citoyen=X, nb_parcelles_urbaines=N],
               'Accaparement urbain : concentration excessive de parcelles urbaines').

%% REGLE-A2 : Accaparement Rural
%% Un acteur possédant ≥ 3 parcelles rurales
accaparement_rural(X) :-
    acteur(X),
    findall(P, (possede(X, P), parcelle_rurale(P)), Parcelles),
    length(Parcelles, N),
    N >= 3,
    log_alerte('REGLE-A2', [acteur=X, nb_parcelles_rurales=N],
               'Accaparement rural : concentration excessive de parcelles rurales').

%% REGLE-A3 : Multipropriété Familiale
%% Deux proches cumulant > 5 parcelles au total
multipropriete_familiale(X, Y) :-
    citoyen(X), citoyen(Y), X \= Y,
    lien_familial(X, Y),
    findall(P, possede(X, P), PX),
    findall(Q, possede(Y, Q), PY),
    length(PX, NX), length(PY, NY),
    Total is NX + NY,
    Total > 5,
    log_alerte('REGLE-A3', [citoyen1=X, citoyen2=Y, total_parcelles=Total],
               'Multipropriété familiale : cumul suspect de parcelles dans un réseau familial').

%% ============================================================
%% CATÉGORIE B — SPÉCULATION
%% ============================================================

%% REGLE-B1 : Revente Ultra-Rapide (< 90 jours après attribution)
speculation_revente_rapide(X, P, DeltaJours) :-
    acteur(X),
    possede(X, P),
    attribution(_, X, DateAttrib),
    vend_a(X, _, P, DateVente),
    DeltaJours is DateVente - DateAttrib,
    DeltaJours < 90,
    log_alerte('REGLE-B1', [vendeur=X, parcelle=P, delai_jours=DeltaJours],
               'Spéculation : revente ultra-rapide dans les 90 jours suivant l attribution').

%% REGLE-B2 : Plus-Value Anormale (> 30% au-dessus valeur cadastrale)
speculation_plus_value_anormale(X, P, TauxPlusValue) :-
    vend_a(X, _, P, _),
    valeur_parcelle(P, ValeurCadastre),
    prix_vente(X, _, PrixVente),
    PrixVente > ValeurCadastre,
    TauxPlusValue is ((PrixVente - ValeurCadastre) * 100) // ValeurCadastre,
    TauxPlusValue > 30,
    log_alerte('REGLE-B2', [vendeur=X, parcelle=P, taux_plus_value=TauxPlusValue],
               'Spéculation : plus-value anormale supérieure à 30% de la valeur cadastrale').

%% REGLE-B3 : Non-Mise en Valeur (≥ 5 ans sans valorisation)
%% Seuil simplifié : date_attribution < 200 (> 800 jours sans projet)
non_mise_en_valeur(P) :-
    parcelle_urbaine(P),
    date_attribution(P, DateAttrib),
    DateAttrib < 200,
    \+ valorise(P),
    log_alerte('REGLE-B3', [parcelle=P, date_attribution=DateAttrib],
               'Spéculation passive : parcelle urbaine non valorisée depuis plus de 5 ans').

%% REGLE-B4 : Double Revente en Chaîne (X vend à Y qui revend < 60 jours)
speculation_chaine_revente(X, Y, Z, P) :-
    vend_a(X, Y, P, D1),
    vend_a(Y, Z, P, D2),
    Delta is D2 - D1,
    Delta < 60,
    log_alerte('REGLE-B4', [vendeur1=X, intermediaire=Y, acheteur_final=Z, parcelle=P, delta_jours=Delta],
               'Spéculation en chaîne : revente dans les 60 jours après acquisition').

%% ============================================================
%% CATÉGORIE C — CONFLITS D'INTÉRÊTS
%% ============================================================

%% REGLE-C1 : Conflit d'Intérêt Direct (agent traite son propre dossier)
conflit_interet_direct(Agent) :-
    agent_public(Agent),
    traite(Agent, Dossier),
    beneficiaire(Agent, Dossier),
    log_alerte('REGLE-C1', [agent=Agent, dossier=Dossier],
               'CONFLIT DIRECT : agent public traitant un dossier dont il est lui-même bénéficiaire').

%% REGLE-C2 : Conflit d'Intérêt Familial
conflit_interet_familial(Agent, ProcheBeneficiaire) :-
    agent_public(Agent),
    traite(Agent, Dossier),
    beneficiaire(ProcheBeneficiaire, Dossier),
    lien_familial(Agent, ProcheBeneficiaire),
    Agent \= ProcheBeneficiaire,
    log_alerte('REGLE-C2', [agent=Agent, proche=ProcheBeneficiaire, dossier=Dossier],
               'Conflit familial : agent traitant un dossier bénéficiant à un proche parent').

%% REGLE-C3 : Conflit d'Intérêt Professionnel
conflit_interet_professionnel(Agent, Partenaire) :-
    agent_public(Agent),
    traite(Agent, Dossier),
    beneficiaire(Partenaire, Dossier),
    lien_professionnel(Agent, Partenaire),
    log_alerte('REGLE-C3', [agent=Agent, partenaire=Partenaire, dossier=Dossier],
               'Conflit professionnel : agent traitant un dossier bénéficiant à un partenaire commercial').

%% REGLE-C4 : Favoristisme Répétitif (même agent attribue ≥ 2 dossiers au même bénéficiaire)
favoritisme_repetitif(Agent, Beneficiaire) :-
    agent_public(Agent),
    findall(D, (traite(Agent, D), beneficiaire(Beneficiaire, D)), Dossiers),
    length(Dossiers, N),
    N >= 2,
    log_alerte('REGLE-C4', [agent=Agent, beneficiaire=Beneficiaire, nb_dossiers=N],
               'Favoritisme répétitif : agent attribuant systématiquement au même bénéficiaire').

%% REGLE-C5 : Notaire Lié (notaire instrumentant au profit d'un proche)
conflit_notaire(Notaire, Proche) :-
    notaire(Notaire),
    lien_familial(Notaire, Proche),
    beneficiaire(Proche, Dossier),
    dossier_actif(Dossier),
    log_alerte('REGLE-C5', [notaire=Notaire, proche=Proche, dossier=Dossier],
               'Conflit notarial : notaire instrumentant un acte bénéficiant à un proche').

%% ============================================================
%% CATÉGORIE D — RÉSEAUX & PRÊTE-NOMS
%% ============================================================

%% REGLE-D1 : Prête-Nom par Téléphone Partagé
prete_nom_telephone(X, Y) :-
    citoyen(X), citoyen(Y), X \= Y,
    partage_telephone(X, Y),
    possede(X, _),
    possede(Y, _),
    log_alerte('REGLE-D1', [suspect1=X, suspect2=Y],
               'Suspect prête-nom : deux propriétaires distincts partagent le même numéro de téléphone').

%% REGLE-D2 : Prête-Nom par Adresse Partagée
prete_nom_adresse(X, Y) :-
    acteur(X), acteur(Y), X \= Y,
    partage_adresse(X, Y),
    possede(X, _),
    possede(Y, _),
    log_alerte('REGLE-D2', [suspect1=X, suspect2=Y],
               'Suspect prête-nom : deux propriétaires partagent la même adresse physique').

%% REGLE-D3 : Réseau Circulaire de Blanchiment (X->Y->Z->X)
reseau_circulaire(X, Y, Z) :-
    acteur(X), acteur(Y), acteur(Z),
    X \= Y, Y \= Z, X \= Z,
    vend_a(X, Y, P, D1),
    vend_a(Y, Z, P, D2),
    vend_a(Z, X, P, D3),
    D2 > D1, D3 > D2,
    DureeCircuit is D3 - D1,
    DureeCircuit < 365,
    log_alerte('REGLE-D3', [acteur1=X, acteur2=Y, acteur3=Z, parcelle=P, duree_jours=DureeCircuit],
               'RÉSEAU CIRCULAIRE : transactions en boucle fermée en moins d un an — blanchiment probable').

%% REGLE-D4 : Structure Financière Partagée (IBAN commun entre acheteur et vendeur)
structure_financiere_partagee(X, Y) :-
    acteur(X), acteur(Y), X \= Y,
    partage_iban(X, Y),
    (vend_a(X, Y, _, _) ; vend_a(Y, X, _, _)),
    log_alerte('REGLE-D4', [acteur1=X, acteur2=Y],
               'Structure financière suspecte : acheteur et vendeur partagent le même IBAN').

%% REGLE-D5 : Promoteur Fantôme (sans adresse et IBAN partagé avec un tiers)
promoteur_fantome(P) :-
    promoteur(P),
    \+ partage_adresse(_, P),
    partage_iban(P, _),
    log_alerte('REGLE-D5', [promoteur=P],
               'Promoteur fantôme : aucune adresse officielle, compte bancaire partagé avec un tiers').

%% ============================================================
%% RÈGLES DE SYNTHÈSE
%% ============================================================

%% REGLE-S1 : Dossier Suspect par dérivation
dossier_suspect_derivee(D) :-
    dossier_actif(D),
    beneficiaire(X, D),
    (accaparement_urbain(X) ; conflit_interet_direct(X)),
    log_alerte('REGLE-S1', [dossier=D, acteur=X],
               'Dossier suspect : bénéficiaire identifié comme accapareur ou en conflit d intérêt').

%% REGLE-S2 : Fraude Composite (plusieurs signaux simultanés)
fraude_composite(X) :-
    acteur(X),
    (accaparement_urbain(X) ; accaparement_rural(X)),
    (prete_nom_telephone(X, _) ; prete_nom_adresse(X, _) ; partage_iban(X, _)),
    log_alerte('REGLE-S2', [acteur=X],
               'FRAUDE COMPOSITE : accumulation foncière ET réseau de dissimulation simultanément détectés').
