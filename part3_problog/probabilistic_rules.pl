%% ============================================================
%% LandGuard Neuro-Symbolic AI
%% MODULE : probabilistic_rules.pl (ProbLog)
%% Partie 3 — Raisonnement probabiliste avec ProbLog
%% ============================================================

%% ------------------------------------------------------------
%% FAITS DE BASE (repris de knowledge_base.pl, simplifiés)
%% ------------------------------------------------------------

% Acteurs
citoyen(abdou). citoyen(mariam). citoyen(ibrahim).
citoyen(fatou).  citoyen(moussa). citoyen(seydou).
citoyen(aminata). citoyen(ndaye). citoyen(thierno).
citoyen(lamine).
agent_public(kouyate). agent_public(diallo_agent). agent_public(barry_agent).
promoteur(fantome_invest). promoteur(atlas_immo).
notaire(me_diallo).

% Parcelles
parcelle_urbaine(p01). parcelle_urbaine(p02). parcelle_urbaine(p03).
parcelle_urbaine(p04). parcelle_urbaine(p05). parcelle_urbaine(p06).
parcelle_urbaine(p07). parcelle_urbaine(p08). parcelle_urbaine(p09).

parcelle_rurale(r01). parcelle_rurale(r02).

% Propriétés
possede(abdou, p01). possede(abdou, p02). possede(abdou, p03).
possede(abdou, p04). possede(abdou, p05).
possede(mariam, p06). possede(mariam, p07). possede(mariam, p08).
possede(moussa, p09). possede(moussa, p01). % multipropriété
possede(ibrahim, r01). possede(oumar, r02).

% Liens
lien_familial(abdou, mariam).
lien_familial(barry_agent, moussa).
lien_familial(me_diallo, diallo_agent).
partage_telephone(abdou, mariam).
partage_telephone(ndaye, thierno).
partage_adresse(fantome_invest, lamine).
partage_iban(moussa, abdou).
partage_iban(fantome_invest, lamine).

% Ventes
vend_a(ibrahim, fatou,  p09, 1000).
vend_a(fatou,   moussa, p09, 1060).
vend_a(moussa,  ibrahim,p09, 1120).
vend_a(abdou, seydou, p03, 800).
vend_a(seydou, aminata, p03, 830).

% Dossiers
traite(barry_agent, dossier_007).
beneficiaire(moussa, dossier_007).
traite(diallo_agent, dossier_004).
beneficiaire(diallo_agent, dossier_004).

% Prix
prix_vente(abdou, seydou, 9000000).
valeur_parcelle(p03, 6000000).

%% ============================================================
%% RÈGLES PROBABILISTES — NIVEAU 1 (faits incertains)
%% ============================================================

%% P1 : Partage de téléphone => suspicion prête-nom (forte)
0.80::prete_nom(X, Y) :- partage_telephone(X, Y), X \= Y.

%% P2 : Partage d'adresse => suspicion prête-nom (modérée)
0.65::prete_nom_adresse(X, Y) :- partage_adresse(X, Y), X \= Y.

%% P3 : Partage IBAN => lien financier suspect
0.75::lien_financier_suspect(X, Y) :- partage_iban(X, Y), X \= Y.

%% P4 : Revente rapide avec lien familial => spéculation concertée
0.70::speculation_concertee(X, Y) :-
    vend_a(X, Y, _, D1),
    vend_a(Y, _, _, D2),
    Delta is D2 - D1, Delta < 90,
    lien_familial(X, Y).

%% P5 : Promoteur sans adresse stable => fantôme probable
0.85::promoteur_fantome(P) :-
    promoteur(P),
    partage_adresse(P, _).

%% P6 : Agent avec lien familial vers bénéficiaire => conflit
0.90::conflit_familial_probable(A, B) :-
    agent_public(A),
    traite(A, D),
    beneficiaire(B, D),
    lien_familial(A, B).

%% P7 : Conflit d'intérêt direct certain (agent bénéficiaire)
0.99::conflit_direct(A) :-
    agent_public(A),
    traite(A, D),
    beneficiaire(A, D).

%% P8 : Plus-value > 30% => spéculation probable
0.72::speculation_plus_value(X) :-
    vend_a(X, _, P, _),
    valeur_parcelle(P, Val),
    prix_vente(X, _, Prix),
    Prix > Val,
    Taux is ((Prix - Val) * 100) // Val,
    Taux > 30.

%% P9 : Réseau circulaire => blanchiment
0.95::blanchiment_circulaire(X, Y, Z) :-
    vend_a(X, Y, P, D1),
    vend_a(Y, Z, P, D2),
    vend_a(Z, X, P, D3),
    D2 > D1, D3 > D2,
    D3 - D1 < 365.

%% P10 : Accaparement urbain simple
0.88::accaparement(X) :-
    citoyen(X),
    \+ \+ (possede(X,A), possede(X,B), possede(X,C), possede(X,D),
           A\=B, B\=C, C\=D, A\=C, A\=D, B\=D,
           parcelle_urbaine(A), parcelle_urbaine(B),
           parcelle_urbaine(C), parcelle_urbaine(D)).

%% ============================================================
%% RÈGLES PROBABILISTES — NIVEAU 2 (composition de risques)
%% ============================================================

%% FRAUDE COMPOSITE : combinaison de plusieurs signaux
fraude_elevee(X) :-
    accaparement(X),
    prete_nom(X, _).

fraude_elevee(X) :-
    accaparement(X),
    lien_financier_suspect(X, _).

fraude_elevee(X) :-
    speculation_plus_value(X),
    prete_nom(X, _).

%% Réseau coordonné
reseau_fraude(X, Y) :-
    prete_nom(X, Y),
    lien_financier_suspect(X, Y).

reseau_fraude(X, Y) :-
    prete_nom_adresse(X, Y),
    prete_nom(X, Y).

%% Fraude systémique (implique un agent public)
fraude_systemique(A) :-
    conflit_direct(A).

fraude_systemique(A) :-
    conflit_familial_probable(A, _),
    agent_public(A).
