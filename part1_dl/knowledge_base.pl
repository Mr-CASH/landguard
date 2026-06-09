%% ============================================================
%% LandGuard Neuro-Symbolic AI
%% MODULE : knowledge_base.pl
%% Partie 1 — Base de connaissances issue de la Logique de Description
%% ============================================================

:- module(knowledge_base, [
    acteur/1, citoyen/1, agent_public/1, promoteur/1, notaire/1,
    parcelle_urbaine/1, parcelle_rurale/1,
    possede/2, traite/2, beneficiaire/2,
    lien_familial/2, lien_professionnel/2, lien_financier/2,
    vend_a/4, partage_telephone/2, partage_adresse/2, partage_iban/2,
    attribution/3, revente/4, heritage/3,
    dossier_actif/1, dossier_suspect/1,
    valeur_parcelle/2, date_attribution/2, valorise/1
]).

% ============================================================
% TAXONOMIE DES ACTEURS
% ============================================================
% Hiérarchie : Acteur -> {Citoyen, AgentPublic, Promoteur, Notaire}

acteur(X) :- citoyen(X).
acteur(X) :- agent_public(X).
acteur(X) :- promoteur(X).
acteur(X) :- notaire(X).

% ============================================================
% TAXONOMIE DES PARCELLES
% ============================================================

parcelle(P) :- parcelle_urbaine(P).
parcelle(P) :- parcelle_rurale(P).

% ============================================================
% TAXONOMIE DES AFFECTATIONS
% ============================================================

affectation(A) :- attribution(A, _, _).
affectation(A) :- revente(A, _, _, _).
affectation(A) :- heritage(A, _, _).

% ============================================================
% FAITS — CITOYENS
% ============================================================

citoyen(abdou).
citoyen(mariam).
citoyen(ibrahim).
citoyen(fatou).
citoyen(moussa).
citoyen(aissatou).
citoyen(boubacar).
citoyen(roukiatou).
citoyen(seydou).
citoyen(aminata).
citoyen(oumar).
citoyen(kadiatou).
citoyen(mamadou).
citoyen(hawa).
citoyen(saliou).
citoyen(binta).
citoyen(lamine).
citoyen(ndaye).
citoyen(thierno).
citoyen(mariama).

% ============================================================
% FAITS — AGENTS PUBLICS
% ============================================================

agent_public(kouyate).
agent_public(diallo_agent).
agent_public(traore_agent).
agent_public(barry_agent).
agent_public(camara_agent).

% ============================================================
% FAITS — PROMOTEURS
% ============================================================

promoteur(promo_sarl).
promoteur(atlas_immo).
promoteur(fantome_invest).   % promoteur suspect sans adresse stable
promoteur(sahel_dev).

% ============================================================
% FAITS — NOTAIRES
% ============================================================

notaire(me_diallo).
notaire(me_toure).
notaire(me_conde).

% ============================================================
% FAITS — PARCELLES URBAINES
% ============================================================

parcelle_urbaine(p01). parcelle_urbaine(p02). parcelle_urbaine(p03).
parcelle_urbaine(p04). parcelle_urbaine(p05). parcelle_urbaine(p06).
parcelle_urbaine(p07). parcelle_urbaine(p08). parcelle_urbaine(p09).
parcelle_urbaine(p10). parcelle_urbaine(p11). parcelle_urbaine(p12).
parcelle_urbaine(p13). parcelle_urbaine(p14). parcelle_urbaine(p15).
parcelle_urbaine(p16). parcelle_urbaine(p17). parcelle_urbaine(p18).
parcelle_urbaine(p19). parcelle_urbaine(p20).

% ============================================================
% FAITS — PARCELLES RURALES
% ============================================================

parcelle_rurale(r01). parcelle_rurale(r02). parcelle_rurale(r03).
parcelle_rurale(r04). parcelle_rurale(r05). parcelle_rurale(r06).
parcelle_rurale(r07). parcelle_rurale(r08). parcelle_rurale(r09).
parcelle_rurale(r10).

% ============================================================
% FAITS — PROPRIETE (possede/2)
% AX-01 : abdou possède 5 parcelles urbaines => AccapareurUrbain
% ============================================================

possede(abdou, p01). possede(abdou, p02). possede(abdou, p03).
possede(abdou, p04). possede(abdou, p05).   % 5 parcelles => accapareur

possede(mariam, p06). possede(mariam, p07). possede(mariam, p08).  % 3 parcelles

possede(ibrahim, p09). possede(ibrahim, r01).

possede(fatou, p10). possede(fatou, p11).

possede(moussa, p12). possede(moussa, p13). possede(moussa, p14).
possede(moussa, p15).   % 4 parcelles => accapareur

possede(aissatou, p16).
possede(boubacar, p17).
possede(roukiatou, p18).
possede(seydou, p19).
possede(aminata, p20).

possede(oumar, r02). possede(oumar, r03).
possede(kadiatou, r04).
possede(mamadou, r05). possede(mamadou, r06).
possede(hawa, r07).
possede(saliou, r08).

% Promoteurs
possede(atlas_immo, p09).   % redoublé => conflit latent
possede(fantome_invest, p07). possede(fantome_invest, p08).

% ============================================================
% FAITS — TRAITEMENT DE DOSSIERS (traite/2)
% ============================================================

traite(kouyate,   dossier_001).
traite(kouyate,   dossier_002).
traite(diallo_agent, dossier_003).
traite(diallo_agent, dossier_004).   % AX-02 conflict : diallo est bénéficiaire de dossier_004
traite(traore_agent, dossier_005).
traite(barry_agent,  dossier_006).
traite(barry_agent,  dossier_007).   % AX-06 conflit familial
traite(camara_agent, dossier_008).
traite(camara_agent, dossier_009).

% ============================================================
% FAITS — BENEFICIAIRES (beneficiaire/2)
% ============================================================

beneficiaire(abdou,       dossier_001).
beneficiaire(diallo_agent, dossier_004).  % CONFLIT DIRECT AX-02
beneficiaire(mariam,      dossier_003).
beneficiaire(ibrahim,     dossier_005).
beneficiaire(fatou,       dossier_006).
beneficiaire(moussa,      dossier_007).
beneficiaire(aissatou,    dossier_008).
beneficiaire(boubacar,    dossier_009).
beneficiaire(atlas_immo,  dossier_002).

% ============================================================
% FAITS — LIENS FAMILIAUX (lien_familial/2)
% ============================================================

lien_familial(barry_agent, moussa).     % Barry traite un dossier bénéficiant à son proche
lien_familial(abdou, mariam).
lien_familial(abdou, ibrahim).
lien_familial(moussa, fatou).
lien_familial(me_diallo, diallo_agent). % notaire lié à un agent public
lien_familial(kouyate, seydou).
lien_familial(mamadou, oumar).
lien_familial(mamadou, saliou).

lien_familial(X, Y) :- lien_familial(Y, X).  % Symétrie

% ============================================================
% FAITS — LIENS PROFESSIONNELS
% ============================================================

lien_professionnel(kouyate, atlas_immo).
lien_professionnel(me_toure, promo_sarl).
lien_professionnel(traore_agent, sahel_dev).

% ============================================================
% FAITS — LIENS FINANCIERS
% ============================================================

lien_financier(abdou, moussa).
lien_financier(fantome_invest, mamadou).

% ============================================================
% FAITS — VENTES (vend_a/4 : Vendeur, Acheteur, Parcelle, Date_en_jours)
% date = nombre de jours depuis l'epoch pour simplification
% ============================================================

% Réseau circulaire : ibrahim -> fatou -> moussa -> ibrahim (AX-05 + CI-8)
vend_a(ibrahim, fatou,  p09, 1000).
vend_a(fatou,   moussa, p09, 1060).
vend_a(moussa,  ibrahim,p09, 1120).  % boucle en 120 jours

% Revente rapide d'abdou
vend_a(abdou, seydou, p03, 800).
vend_a(seydou, aminata, p03, 830). % 30 jours seulement

% Transaction normale
vend_a(atlas_immo, boubacar, p17, 900).
vend_a(oumar, kadiatou, r02, 950).

% ============================================================
% FAITS — TELEPHONE / ADRESSE / IBAN PARTAGÉS (CI-5, CI-7)
% ============================================================

partage_telephone(abdou,   mariam).   % AX-03 prête-nom suspect
partage_telephone(moussa,  fatou).    % Réseau familial suspect
partage_telephone(ndaye,   thierno).  % CI-5

partage_adresse(fantome_invest, mamadou). % CI-7 promoteur sans adresse propre
partage_adresse(abdou, ibrahim).

partage_iban(moussa, abdou).          % Lien financier fort
partage_iban(fantome_invest, lamine). % Promoteur fantôme

% ============================================================
% FAITS — ATTRIBUTIONS (attribution/3 : Dossier, Beneficiaire, Date)
% ============================================================

attribution(dossier_001, abdou,       700).
attribution(dossier_002, atlas_immo,  710).
attribution(dossier_003, mariam,      750).
attribution(dossier_004, diallo_agent,760).
attribution(dossier_005, ibrahim,     800).
attribution(dossier_006, fatou,       820).
attribution(dossier_007, moussa,      850).
attribution(dossier_008, aissatou,    870).
attribution(dossier_009, boubacar,    900).

% ============================================================
% FAITS — REVENTES (revente/4 : Dossier, Vendeur, Acheteur, Date)
% ============================================================

revente(rev_001, abdou,   seydou,   800).   % 100 jours après attribution => spéculatif
revente(rev_002, seydou,  aminata,  830).   % 30 jours => très rapide
revente(rev_003, ibrahim, fatou,    1000).
revente(rev_004, fatou,   moussa,   1060).
revente(rev_005, moussa,  ibrahim,  1120).  % CI-8 circuit fermé

% ============================================================
% FAITS — HÉRITAGES (heritage/3 : Dossier, De, Vers)
% ============================================================

heritage(her_001, aminata, roukiatou).
heritage(her_002, oumar,   kadiatou).

% ============================================================
% FAITS — VALEUR DES PARCELLES (valeur_parcelle/2 : Parcelle, Valeur)
% ============================================================

valeur_parcelle(p01, 5000000). valeur_parcelle(p02, 4500000).
valeur_parcelle(p03, 6000000). valeur_parcelle(p04, 3800000).
valeur_parcelle(p05, 4200000). valeur_parcelle(p06, 5500000).
valeur_parcelle(p07, 2000000). valeur_parcelle(p08, 2100000).
valeur_parcelle(p09, 3000000). valeur_parcelle(p10, 4700000).
valeur_parcelle(p11, 3300000). valeur_parcelle(p12, 6200000).
valeur_parcelle(p13, 5900000). valeur_parcelle(p14, 4400000).
valeur_parcelle(p15, 5100000). valeur_parcelle(p16, 2800000).
valeur_parcelle(p17, 3600000). valeur_parcelle(p18, 4100000).
valeur_parcelle(p19, 3200000). valeur_parcelle(p20, 4800000).
valeur_parcelle(r01, 800000).  valeur_parcelle(r02, 950000).
valeur_parcelle(r03, 700000).  valeur_parcelle(r04, 1100000).
valeur_parcelle(r05, 1200000). valeur_parcelle(r06, 900000).
valeur_parcelle(r07, 750000).  valeur_parcelle(r08, 880000).

% ============================================================
% FAITS — DATE D'ATTRIBUTION (date_attribution/2)
% ============================================================

date_attribution(p01, 200). date_attribution(p02, 300).
date_attribution(p03, 700). date_attribution(p04, 710).
date_attribution(p05, 720). date_attribution(p06, 750).
date_attribution(p07, 680). date_attribution(p08, 690).
date_attribution(p09, 800). date_attribution(p12, 400).
date_attribution(p13, 450). date_attribution(p14, 500).
date_attribution(p15, 550).

% ============================================================
% FAITS — VALORISATION (valorise/1)
% Parcelles valorisées (projet en cours ou construit)
% ============================================================

valorise(p06). valorise(p10). valorise(p11).
valorise(p16). valorise(p17). valorise(p18).
valorise(p19). valorise(p20).
valorise(r01). valorise(r02). valorise(r03).
valorise(r07). valorise(r08).

% ============================================================
% FAITS — DOSSIERS ACTIFS
% ============================================================

dossier_actif(dossier_001). dossier_actif(dossier_002).
dossier_actif(dossier_003). dossier_actif(dossier_004).
dossier_actif(dossier_005). dossier_actif(dossier_006).
dossier_actif(dossier_007). dossier_actif(dossier_008).
dossier_actif(dossier_009).

% ============================================================
% FAITS — DOSSIERS SUSPECTS
% ============================================================

dossier_suspect(dossier_001). dossier_suspect(dossier_002).
dossier_suspect(dossier_003). dossier_suspect(dossier_004).

% ============================================================
% FAITS — PRIX DE VENTE (prix_vente/3 : Vendeur, Acheteur, Prix)
% ============================================================

prix_vente(abdou,   seydou,  9000000).   % valeur_parcelle p03=6000000 => plus-value 50%
prix_vente(seydou,  aminata, 9500000).   % revente immédiate
prix_vente(ibrahim, fatou,   3000000).
prix_vente(fatou,   moussa,  3200000).
prix_vente(moussa,  ibrahim, 3500000).   % +16% en 120 jours
