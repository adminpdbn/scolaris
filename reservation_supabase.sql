-- ════════════════════════════════════════════════════════════════
--  RÉSERVATION DE CRÉNEAUX — SQL à exécuter dans Supabase
--  (Dashboard → SQL Editor → New query → coller → Run)
--  Projet : gwmdurhncotftuxfgwkg
--
--  Sûr : ne touche PAS aux tables existantes (dispos, users…) sauf
--  un simple ajout de colonne "email" (facultatif, sans risque).
-- ════════════════════════════════════════════════════════════════

-- ─── 1. Créneaux (disponibilités saisies par l'admin) ───
create table if not exists public.creneaux (
  id            text primary key,
  prof_id       text,
  prof_nom      text,                 -- nom affiché publiquement (pas besoin de lire users)
  date          date,
  debut         numeric,
  fin           numeric,
  mode          text default 'presentiel',   -- presentiel | visio
  matiere       text,
  niveau        text,
  salle         text,
  notes         text,
  tarif_horaire numeric default 40,
  frais_infra   numeric default 0,
  statut        text not null default 'libre',  -- libre | reserve | confirme
  created_at    timestamptz not null default now()
);
create index if not exists creneaux_statut_date_idx on public.creneaux (statut, date);
-- Pour une base déjà créée, ajoute la colonne salle (sans risque) :
alter table public.creneaux add column if not exists salle text;

-- ─── 2. Réservations publiques ───
create table if not exists public.reservations (
  id            text primary key,
  creneau_id    text references public.creneaux(id) on delete set null,
  prof_id       text,
  matiere       text,
  date          date,
  debut         numeric,
  fin           numeric,
  mode          text,
  eleve_nom     text not null,
  eleve_niveau  text,
  parent_nom    text,
  parent_email  text,
  parent_tel    text,
  notes         text,
  montant       numeric default 0,
  statut        text not null default 'en_attente',  -- en_attente | paye | valide | refuse | annule
  created_at    timestamptz not null default now()
);
create index if not exists reservations_statut_idx on public.reservations (statut);

-- ─── 3. users : ajouter la colonne email (affichage admin) — sans risque ───
alter table public.users add column if not exists email text;

-- ─── 4. RLS sur les DEUX NOUVELLES tables uniquement ───
alter table public.creneaux     enable row level security;
alter table public.reservations enable row level security;

-- Privilèges (belt & suspenders — indépendant des réglages par défaut)
grant select        on public.creneaux to anon;
grant update (statut) on public.creneaux to anon;   -- le public ne peut changer QUE le statut (bloquer)
grant all           on public.creneaux to authenticated;
grant insert        on public.reservations to anon; -- le public crée une résa (pas de lecture)
grant all           on public.reservations to authenticated;

-- creneaux : le PUBLIC lit uniquement les créneaux libres
drop policy if exists creneaux_read_public on public.creneaux;
create policy creneaux_read_public on public.creneaux
  for select to anon using (statut = 'libre');

-- creneaux : le PUBLIC peut passer un créneau libre → réservé (blocage)
drop policy if exists creneaux_hold_public on public.creneaux;
create policy creneaux_hold_public on public.creneaux
  for update to anon using (statut = 'libre') with check (statut in ('libre','reserve'));

-- creneaux : les utilisateurs connectés (admin/prof) → accès complet
drop policy if exists creneaux_auth_all on public.creneaux;
create policy creneaux_auth_all on public.creneaux
  for all to authenticated using (true) with check (true);

-- reservations : le PUBLIC crée (toujours "en_attente"), sans pouvoir lire les autres
drop policy if exists resa_insert_public on public.reservations;
create policy resa_insert_public on public.reservations
  for insert to anon, authenticated with check (statut = 'en_attente');

-- reservations : l'ADMIN connecté gère tout
drop policy if exists resa_admin_all on public.reservations;
create policy resa_admin_all on public.reservations
  for all to authenticated
  using (exists (select 1 from public.users u where u.auth_id = auth.uid() and u.role = 'admin'))
  with check (true);

-- ════════════════════════════════════════════════════════════════
--  Fait. reservation.html peut maintenant :
--   • lire les créneaux libres (anon)          → page publique
--   • enregistrer une réservation (anon)       → bouton Réserver
--   • bloquer le créneau (anon, statut seul)   → anti double-résa
--  L'admin connecté saisit les créneaux et valide/refuse les résas.
--  Aucune table existante n'est modifiée (hors ajout email).
-- ════════════════════════════════════════════════════════════════


-- ════════════════════════════════════════════════════════════════
--  AJOUT — Espace élève connecté (réservation directe)
--  À exécuter si tu as déjà lancé le SQL précédent.
-- ════════════════════════════════════════════════════════════════
alter table public.reservations add column if not exists eleve_id text;

-- L'élève connecté peut créer sa réservation (statut 'valide' inclus)
drop policy if exists resa_insert_auth on public.reservations;
create policy resa_insert_auth on public.reservations
  for insert to authenticated with check (true);

-- L'élève connecté peut lire SES réservations
drop policy if exists resa_select_own on public.reservations;
create policy resa_select_own on public.reservations
  for select to authenticated
  using (exists (select 1 from public.users u where u.auth_id = auth.uid() and u.id = reservations.eleve_id));
