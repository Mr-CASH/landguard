%% ============================================================
%% LandGuard Neuro-Symbolic AI
%% MODULE : explainability.pl
%% Partie 2 — Mécanismes d'explicabilité (XAI) — Journalisation des règles
%% ============================================================

:- module(explainability, [
    log_alerte/3,
    get_alertes/1,
    clear_alertes/0,
    afficher_rapport_xai/0,
    alerte_to_text/2
]).

:- dynamic alerte/4.   % alerte(Timestamp, RegleID, Bindings, Motif)

%% ============================================================
%% COMPTEUR DE TIMESTAMPS (simulé par compteur auto-incrémenté)
%% ============================================================
:- dynamic compteur_ts/1.
compteur_ts(0).

next_ts(TS) :-
    retract(compteur_ts(N)),
    TS is N + 1,
    assert(compteur_ts(TS)).

%% ============================================================
%% JOURNALISATION PRINCIPALE
%% log_alerte(+RegleID, +Bindings, +Motif)
%%   RegleID : identifiant de la règle (atom, ex: 'REGLE-A1')
%%   Bindings : liste de paires Key=Value
%%   Motif    : texte explicatif normé
%% ============================================================

log_alerte(RegleID, Bindings, Motif) :-
    next_ts(TS),
    assertz(alerte(TS, RegleID, Bindings, Motif)),
    format(atom(BindStr), '~w', [Bindings]),
    format('[ALERTE #~w] Règle: ~w | Contexte: ~w~n         Motif: ~w~n~n',
           [TS, RegleID, BindStr, Motif]).

%% ============================================================
%% ACCESSEURS
%% ============================================================

get_alertes(Alertes) :-
    findall(alerte(TS, R, B, M), alerte(TS, R, B, M), Alertes).

clear_alertes :-
    retractall(alerte(_, _, _, _)),
    retract(compteur_ts(_)),
    assert(compteur_ts(0)).

%% ============================================================
%% AFFICHAGE RAPPORT XAI
%% ============================================================

afficher_rapport_xai :-
    findall(alerte(TS,R,B,M), alerte(TS,R,B,M), Alertes),
    length(Alertes, N),
    format('~n╔══════════════════════════════════════════════════╗~n'),
    format('║     RAPPORT XAI — LandGuard Neuro-Symbolic AI   ║~n'),
    format('╚══════════════════════════════════════════════════╝~n~n'),
    format('Nombre total d alertes : ~w~n~n', [N]),
    forall(
        member(alerte(TS, RegleID, Bindings, Motif), Alertes),
        afficher_alerte(TS, RegleID, Bindings, Motif)
    ).

afficher_alerte(TS, RegleID, Bindings, Motif) :-
    format('┌─ Alerte #~w ─────────────────────────────────────~n', [TS]),
    format('│  Règle      : ~w~n', [RegleID]),
    format('│  Contexte   : ~n'),
    forall(member(K=V, Bindings),
           format('│    ~w = ~w~n', [K, V])),
    format('│  Motif XAI  : ~w~n', [Motif]),
    format('└────────────────────────────────────────────────~n~n').

%% ============================================================
%% CONVERSION ALERTE → TEXTE (pour export Python)
%% ============================================================

alerte_to_text(alerte(TS, RegleID, Bindings, Motif), Text) :-
    format(atom(BindStr), '~w', [Bindings]),
    format(atom(Text),
           '[#~w][~w] ~w | Variables: ~w',
           [TS, RegleID, Motif, BindStr]).
