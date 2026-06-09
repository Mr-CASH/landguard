%% ============================================================
%% LandGuard Neuro-Symbolic AI
%% MODULE : inference_engine.pl
%% Partie 2 — Moteur d'inférence principal
%% ============================================================

:- module(inference_engine, [
    run_all_rules/0,
    analyse_acteur/1,
    analyse_dossier/1,
    rapport_complet/0
]).

:- use_module('../part1_dl/knowledge_base').
:- use_module(rules).
:- use_module(explainability).

%% ============================================================
%% POINT D'ENTRÉE PRINCIPAL
%% run_all_rules/0 : exécute toutes les catégories de règles
%% ============================================================

run_all_rules :-
    clear_alertes,
    format('~n=== LandGuard : Démarrage du moteur d inférence ===~n~n'),

    format('--- CATÉGORIE A : ACCAPAREMENT ---~n'),
    run_accaparement,

    format('--- CATÉGORIE B : SPÉCULATION ---~n'),
    run_speculation,

    format('--- CATÉGORIE C : CONFLITS D INTÉRÊTS ---~n'),
    run_conflits,

    format('--- CATÉGORIE D : RÉSEAUX & PRÊTE-NOMS ---~n'),
    run_reseaux,

    format('--- SYNTHÈSE ---~n'),
    run_synthese,

    afficher_rapport_xai.

%% ============================================================
%% RUNNERS PAR CATÉGORIE
%% ============================================================

run_accaparement :-
    forall(citoyen(X), ignore(accaparement_urbain(X))),
    forall(acteur(X), ignore(accaparement_rural(X))),
    forall(
        (citoyen(X), citoyen(Y), X @< Y),
        ignore(multipropriete_familiale(X, Y))
    ).

run_speculation :-
    forall(
        (acteur(X), possede(X, P)),
        ignore(speculation_revente_rapide(X, P, _))
    ),
    forall(
        (acteur(X), possede(X, P)),
        ignore(speculation_plus_value_anormale(X, P, _))
    ),
    forall(parcelle_urbaine(P), ignore(non_mise_en_valeur(P))).

run_conflits :-
    forall(agent_public(A), ignore(conflit_interet_direct(A))),
    forall(
        (agent_public(A), citoyen(B)),
        ignore(conflit_interet_familial(A, B))
    ),
    forall(
        (agent_public(A), acteur(B)),
        ignore(conflit_interet_professionnel(A, B))
    ),
    forall(
        (agent_public(A), acteur(B)),
        ignore(favoritisme_repetitif(A, B))
    ),
    forall(
        (notaire(N), acteur(B)),
        ignore(conflit_notaire(N, B))
    ).

run_reseaux :-
    forall(
        (citoyen(X), citoyen(Y), X @< Y),
        ignore(prete_nom_telephone(X, Y))
    ),
    forall(
        (acteur(X), acteur(Y), X @< Y),
        ignore(prete_nom_adresse(X, Y))
    ),
    forall(
        (acteur(X), acteur(Y), acteur(Z), X \= Y, Y \= Z, X \= Z),
        ignore(reseau_circulaire(X, Y, Z))
    ),
    forall(
        (acteur(X), acteur(Y), X @< Y),
        ignore(structure_financiere_partagee(X, Y))
    ),
    forall(promoteur(P), ignore(promoteur_fantome(P))).

run_synthese :-
    forall(dossier_actif(D), ignore(dossier_suspect_derivee(D))),
    forall(acteur(X), ignore(fraude_composite(X))).

%% ============================================================
%% ANALYSE PAR ACTEUR
%% ============================================================

analyse_acteur(X) :-
    format('~n=== Analyse de l acteur : ~w ===~n~n', [X]),
    clear_alertes,
    ignore(accaparement_urbain(X)),
    ignore(accaparement_rural(X)),
    forall(citoyen(Y), ignore(multipropriete_familiale(X, Y))),
    forall(possede(X, P), ignore(speculation_revente_rapide(X, P, _))),
    forall(possede(X, P), ignore(speculation_plus_value_anormale(X, P, _))),
    (agent_public(X) -> (
        ignore(conflit_interet_direct(X)),
        forall(acteur(B), ignore(conflit_interet_familial(X, B))),
        forall(acteur(B), ignore(conflit_interet_professionnel(X, B)))
    ) ; true),
    ignore(prete_nom_telephone(X, _)),
    ignore(prete_nom_adresse(X, _)),
    ignore(structure_financiere_partagee(X, _)),
    ignore(fraude_composite(X)),
    afficher_rapport_xai.

%% ============================================================
%% ANALYSE PAR DOSSIER
%% ============================================================

analyse_dossier(D) :-
    format('~n=== Analyse du dossier : ~w ===~n~n', [D]),
    clear_alertes,
    ignore(dossier_suspect_derivee(D)),
    (beneficiaire(X, D) ->
        analyse_acteur(X)
    ;
        format('Aucun bénéficiaire trouvé pour le dossier ~w~n', [D])
    ).

%% ============================================================
%% RAPPORT COMPLET SYNTHÉTIQUE
%% ============================================================

rapport_complet :-
    run_all_rules,
    format('~n╔══════════════════════════════════════════════════╗~n'),
    format('║         RAPPORT DE DÉTECTION — RÉSUMÉ           ║~n'),
    format('╚══════════════════════════════════════════════════╝~n~n'),

    % Accapareurs
    findall(X, accaparement_urbain(X), AccU),
    format('Accapareurs urbains détectés       : ~w~n', [AccU]),

    % Spéculateurs
    findall(X-P, speculation_revente_rapide(X,P,_), Spec),
    format('Reventes rapides détectées         : ~w~n', [Spec]),

    % Conflits
    findall(X, conflit_interet_direct(X), ConfDir),
    format('Conflits d intérêt directs         : ~w~n', [ConfDir]),

    % Réseaux
    findall(X-Y, prete_nom_telephone(X,Y), Pretes),
    format('Suspects prête-nom (téléphone)     : ~w~n', [Pretes]),

    findall(X-Y-Z, reseau_circulaire(X,Y,Z), Circuits),
    format('Réseaux circulaires détectés       : ~w~n', [Circuits]),

    % Fraudes composites
    findall(X, fraude_composite(X), FraudesComp),
    format('Fraudes composites détectées       : ~w~n', [FraudesComp]).

%% ============================================================
%% UTILITAIRE : ignorer les échecs prédicats (pour forall)
%% ============================================================
ignore(Goal) :- call(Goal), !.
ignore(_).
