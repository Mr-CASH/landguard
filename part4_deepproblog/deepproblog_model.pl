%% ============================================================
%% LandGuard Neuro-Symbolic AI
%% MODULE : deepproblog_model.pl
%% Partie 4 — Modèle Neuro-Symbolique DeepProbLog
%% ============================================================
%% Ce module fusionne les prédictions du réseau neuronal PyTorch
%% (FraudDetectionNet) avec les contraintes logiques définies en Prolog.
%%
%% Prédicat neuronal déclaré :
%%   nn(fraud_model, [Features], Class, [standard, atypique, speculateur, fraude])
%%
%% Le modèle est chargé depuis model_weights.pth via le bridge DeepProbLog.
%% ============================================================

%% ------------------------------------------------------------
%% 1. DÉCLARATION DU PRÉDICAT NEURONAL
%% ------------------------------------------------------------

%% Déclaration du réseau de neurones comme prédicat probabiliste.
%% fraud_model : identifiant du modèle enregistré dans le bridge Python
%% [Features]  : vecteur de features (liste de 10 valeurs flottantes)
%% Class       : variable de sortie (classe prédite)
%% [standard, atypique, speculateur, fraude] : domaine des classes
nn(fraud_model, [Features], Class, [standard, atypique, speculateur, fraude]).

%% ------------------------------------------------------------
%% 2. PRÉDICATS NEURONAUX NOMMÉS (interface haut-niveau)
%% ------------------------------------------------------------

%% neural_prediction(+Acteur, -Classe)
%% Appelle le modèle neuronal avec les features de l'acteur
neural_prediction(Acteur, Classe) :-
    get_features(Acteur, Features),
    neural(fraud_model, [Features], Classe).

%% get_features(+Acteur, -Features)
%% Extrait le vecteur de features normalisé pour un acteur donné
get_features(Acteur, Features) :-
    get_feature_nb_parcelles_urbaines(Acteur, F1),
    get_feature_nb_parcelles_rurales(Acteur, F2),
    get_feature_frequence_revente(Acteur, F3),
    get_feature_ratio_plus_value(Acteur, F4),
    get_feature_nb_liens(Acteur, F5),
    get_feature_partage_telephone(Acteur, F6),
    get_feature_partage_adresse(Acteur, F7),
    get_feature_partage_iban(Acteur, F8),
    get_feature_age_premier_achat(Acteur, F9),
    get_feature_est_agent(Acteur, F10),
    Features = [F1, F2, F3, F4, F5, F6, F7, F8, F9, F10].

%% Extraction des features individuelles
get_feature_nb_parcelles_urbaines(X, N) :-
    findall(P, (possede(X,P), parcelle_urbaine(P)), Ps),
    length(Ps, N0),
    N is min(N0 / 8.0, 1.0).  % normalisation : max 8 parcelles

get_feature_nb_parcelles_rurales(X, N) :-
    findall(P, (possede(X,P), parcelle_rurale(P)), Ps),
    length(Ps, N0),
    N is min(N0 / 5.0, 1.0).

get_feature_frequence_revente(X, F) :-
    findall(_, vend_a(X, _, _, _), Ventes),
    length(Ventes, NV),
    F is min(NV / 5.0, 1.0).

get_feature_ratio_plus_value(X, R) :-
    (   vend_a(X, _, P, _),
        valeur_parcelle(P, Val),
        prix_vente(X, _, Prix),
        Val > 0
    ->  R0 is (Prix - Val) / Val,
        R is max(0.0, min(R0, 2.0)) / 2.0
    ;   R = 0.0
    ).

get_feature_nb_liens(X, F) :-
    findall(Y, lien_familial(X, Y), Fam),
    findall(Y, lien_professionnel(X, Y), Pro),
    findall(Y, lien_financier(X, Y), Fin),
    length(Fam, NF), length(Pro, NP), length(Fin, NFin),
    Total is NF + NP + NFin,
    F is min(Total / 6.0, 1.0).

get_feature_partage_telephone(X, F) :-
    (partage_telephone(X, _) -> F = 1.0 ; F = 0.0).

get_feature_partage_adresse(X, F) :-
    (partage_adresse(X, _) ; partage_adresse(_, X) -> F = 1.0 ; F = 0.0).

get_feature_partage_iban(X, F) :-
    (partage_iban(X, _) ; partage_iban(_, X) -> F = 1.0 ; F = 0.0).

get_feature_age_premier_achat(X, F) :-
    (   attribution(_, X, Date)
    ->  F is max(0.0, 1.0 - Date / 1200.0)
    ;   F = 0.5
    ).

get_feature_est_agent(X, F) :-
    (agent_public(X) -> F = 1.0 ; F = 0.0).

%% ------------------------------------------------------------
%% 3. RÈGLES HYBRIDES NEURO-SYMBOLIQUES
%% Combinent prédictions neuronales ET contraintes logiques
%% ------------------------------------------------------------

%% HYBRID-1 : Fraude avérée = prédiction neuronale "fraude" + accaparement logique
fraude_avere(X) :-
    neural_prediction(X, fraude),
    accaparement_urbain(X).

%% HYBRID-2 : Fraude avérée = prédiction "fraude" + réseau circulaire
fraude_avere(X) :-
    neural_prediction(X, fraude),
    (reseau_circulaire(X, _, _) ; reseau_circulaire(_, X, _) ; reseau_circulaire(_, _, X)).

%% HYBRID-3 : Spéculation confirmée = prédiction "speculateur" + revente rapide symbolique
speculation_confirmee(X) :-
    neural_prediction(X, speculateur),
    speculation_revente_rapide(X, _, _).

%% HYBRID-4 : Spéculation confirmée = prédiction "speculateur" + plus-value anormale
speculation_confirmee(X) :-
    neural_prediction(X, speculateur),
    speculation_plus_value_anormale(X, _, _).

%% HYBRID-5 : Prête-nom confirmé = prédiction + preuve symbolique
prete_nom_confirme(X, Y) :-
    neural_prediction(X, fraude),
    prete_nom_telephone(X, Y).

prete_nom_confirme(X, Y) :-
    neural_prediction(X, atypique),
    prete_nom_adresse(X, Y).

%% HYBRID-6 : Conflit systémique = prédiction agent corrompu + conflit logique
conflit_systemique(A) :-
    agent_public(A),
    neural_prediction(A, fraude),
    conflit_interet_direct(A).

conflit_systemique(A) :-
    agent_public(A),
    neural_prediction(A, atypique),
    conflit_interet_familial(A, _).

%% HYBRID-7 : Alerte haute priorité (tout signal neuronal fort + signal symbolique)
alerte_haute_priorite(X, Raison) :-
    fraude_avere(X),
    Raison = 'fraude_accaparement_combine'.

alerte_haute_priorite(X, Raison) :-
    conflit_systemique(X),
    Raison = 'conflit_agent_public_confirme'.

alerte_haute_priorite(X, Raison) :-
    prete_nom_confirme(X, _),
    Raison = 'prete_nom_neuronal_symbolique'.

%% ------------------------------------------------------------
%% 4. EXPLICATION NEURO-SYMBOLIQUE (XAI hybride)
%% ------------------------------------------------------------

%% expliquer_decision(+Acteur, -Explication)
expliquer_decision(X, Explication) :-
    neural_prediction(X, Classe),
    get_features(X, Features),
    (fraude_avere(X) ->
        format(atom(Explication),
               'DÉCISION: fraude_avérée | Réseau: ~w | Logique: accaparement+réseau | Features: ~w',
               [Classe, Features])
    ; speculation_confirmee(X) ->
        format(atom(Explication),
               'DÉCISION: spéculation_confirmée | Réseau: ~w | Logique: revente_rapide+plus_value | Features: ~w',
               [Classe, Features])
    ; prete_nom_confirme(X, Y) ->
        format(atom(Explication),
               'DÉCISION: prête_nom_confirmé | Réseau: ~w | Logique: partage_identifiant avec ~w | Features: ~w',
               [Classe, Y, Features])
    ;
        format(atom(Explication),
               'DÉCISION: ~w | Logique: aucune règle critique | Features: ~w',
               [Classe, Features])
    ).

%% ------------------------------------------------------------
%% 5. INTERFACE POUR LE PIPELINE PYTHON (main.py)
%% ------------------------------------------------------------

%% run_hybrid_analysis(+Acteur, -Result)
%% Result = result(Acteur, ClasseNeurale, ClasseHybride, Probabilites, Explication)
run_hybrid_analysis(X, result(X, ClasseN, ClasseH, Explication)) :-
    neural_prediction(X, ClasseN),
    (fraude_avere(X)        -> ClasseH = fraude_avere
    ; speculation_confirmee(X) -> ClasseH = speculation_confirmee
    ; prete_nom_confirme(X, _) -> ClasseH = prete_nom_confirme
    ; conflit_systemique(X)    -> ClasseH = conflit_systemique
    ;                            ClasseH = ClasseN
    ),
    expliquer_decision(X, Explication).

%% batch_analyse(+Acteurs, -Resultats)
batch_analyse([], []).
batch_analyse([X|Rest], [R|RestR]) :-
    (run_hybrid_analysis(X, R) -> true ; R = result(X, inconnu, inconnu, 'Analyse échouée')),
    batch_analyse(Rest, RestR).
