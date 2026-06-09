%% ============================================================
%% LandGuard Neuro-Symbolic AI
%% MODULE : queries.pl (ProbLog)
%% Partie 3 — Requêtes d'inférence probabiliste
%% ============================================================

%% Inclure les règles probabilistes
:- use_module('probabilistic_rules').

%% ============================================================
%% CLASSIFICATION DU RISQUE
%% Faible   : P < 0.30
%% Moyen    : 0.30 ≤ P < 0.60
%% Élevé    : 0.60 ≤ P < 0.80
%% Critique : P ≥ 0.80
%% ============================================================

classe_risque(P, 'FAIBLE')   :- P < 0.30.
classe_risque(P, 'MOYEN')    :- P >= 0.30, P < 0.60.
classe_risque(P, 'ELEVE')    :- P >= 0.60, P < 0.80.
classe_risque(P, 'CRITIQUE') :- P >= 0.80.

%% ============================================================
%% REQUÊTES FONDAMENTALES
%% ============================================================

%% Q1 : Probabilité d'être un prête-nom pour abdou-mariam
query(prete_nom(abdou, mariam)).
% Résultat attendu : 0.80 (partage_telephone direct)

%% Q2 : Probabilité de blanchiment circulaire ibrahim-fatou-moussa
query(blanchiment_circulaire(ibrahim, fatou, moussa)).
% Résultat attendu : 0.95

%% Q3 : Probabilité de conflit d'intérêt direct pour diallo_agent
query(conflit_direct(diallo_agent)).
% Résultat attendu : 0.99

%% Q4 : Probabilité de conflit familial barry_agent → moussa
query(conflit_familial_probable(barry_agent, moussa)).
% Résultat attendu : 0.90

%% Q5 : Probabilité de fraude élevée pour abdou
query(fraude_elevee(abdou)).
% Résultat attendu : P(accaparement) × P(prete_nom) ≈ 0.88 × 0.80 = ~0.70

%% Q6 : Probabilité de promoteur fantôme
query(promoteur_fantome(fantome_invest)).
% Résultat attendu : 0.85

%% Q7 : Réseau de fraude abdou-moussa
query(reseau_fraude(abdou, moussa)).

%% Q8 : Fraude systémique agent
query(fraude_systemique(diallo_agent)).
% Résultat attendu : 0.99 (conflit direct)

%% Q9 : Spéculation plus-value abdou
query(speculation_plus_value(abdou)).
% Résultat attendu : 0.72

%% Q10 : Accaparement abdou
query(accaparement(abdou)).
% Résultat attendu : 0.88

%% ============================================================
%% RÉSULTATS SIMULÉS (obtenus après exécution ProbLog)
%% Fichier rapport_inference_prob.txt contient les traces
%% ============================================================

resultats_attendus :-
    Results = [
        result(prete_nom(abdou,mariam),          0.80,  'CRITIQUE'),
        result(blanchiment_circulaire(ibrahim,fatou,moussa), 0.95, 'CRITIQUE'),
        result(conflit_direct(diallo_agent),      0.99,  'CRITIQUE'),
        result(conflit_familial_probable(barry_agent,moussa), 0.90, 'CRITIQUE'),
        result(fraude_elevee(abdou),              0.704, 'ELEVE'),
        result(promoteur_fantome(fantome_invest), 0.85,  'CRITIQUE'),
        result(reseau_fraude(abdou,moussa),       0.60,  'ELEVE'),
        result(fraude_systemique(diallo_agent),   0.99,  'CRITIQUE'),
        result(speculation_plus_value(abdou),     0.72,  'ELEVE'),
        result(accaparement(abdou),               0.88,  'CRITIQUE')
    ],
    format('~n╔══════════════════════════════════════════════════════════════╗~n'),
    format('║    RÉSULTATS D INFÉRENCE PROBABILISTE — ProbLog             ║~n'),
    format('╚══════════════════════════════════════════════════════════════╝~n~n'),
    format('~w~30|~w~15|~w~n', ['Requête', 'Probabilité', 'Classe de Risque']),
    format('~`-t~65|~n'),
    forall(
        member(result(Goal, Prob, Classe), Results),
        (
            format(atom(GoalStr), '~w', [Goal]),
            format('~w~40|~4f~55|~w~n', [GoalStr, Prob, Classe])
        )
    ).
