-- Trust workspace API. Existing unrelated applications are not changed.
create schema if not exists trust_private;
revoke all on schema trust_private from public,anon;
grant usage on schema trust_private to authenticated;
create table trust_private.organizations (
 id uuid primary key default gen_random_uuid(), name text not null,created_by uuid not null references auth.users(id),created_at timestamptz not null default now()
);
create table trust_private.memberships (
 organization_id uuid not null references trust_private.organizations(id),user_id uuid not null references auth.users(id),
 role text not null check(role in ('owner','manager','employee','trustee','safety_rep')), display_name text not null default '',active boolean not null default true,
 primary key(organization_id,user_id)
);
alter table trust_private.organizations enable row level security;
alter table trust_private.memberships enable row level security;
create table trust_private.records (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references trust_private.organizations(id),
 kind text not null check(kind in ('incident','report','conversation','handbook','improvement','risk','checklist','privacy')),
 creator uuid not null references auth.users(id), participants uuid[] not null default '{}',
 title text not null check(length(trim(title)) between 1 and 200), body text not null default '' check(length(body)<=20000),
 status text not null default 'open', data jsonb not null default '{}', version integer not null default 1,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index trust_records_org on trust_private.records(organization_id,updated_at desc);
create table trust_private.events (
 id bigint generated always as identity primary key, organization_id uuid not null,
 record_id uuid, actor uuid not null, action text not null, created_at timestamptz not null default now()
);
create index trust_events_record on trust_private.events(record_id,id);
create table trust_private.messages (
 id uuid primary key default gen_random_uuid(), record_id uuid not null references trust_private.records(id) on delete cascade,
 author uuid not null references auth.users(id), body text not null check(length(trim(body)) between 1 and 5000),created_at timestamptz not null default now()
);
create index trust_messages_record on trust_private.messages(record_id,created_at);
create table trust_private.invitations (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references trust_private.organizations(id),
 email text not null, role text not null check(role in ('employee','manager','trustee','safety_rep')),
 created_by uuid not null, expires_at timestamptz not null default now()+interval '7 days', accepted_at timestamptz
);
create index trust_invites_email on trust_private.invitations(email,expires_at);
create table trust_private.notifications (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,recipient uuid not null,
 record_id uuid references trust_private.records(id) on delete cascade, message text not null, read_at timestamptz,created_at timestamptz not null default now()
);
create index trust_notifications_recipient on trust_private.notifications(recipient,created_at desc);
create table trust_private.receipts (
 record_id uuid not null references trust_private.records(id) on delete cascade,user_id uuid not null,version integer not null,created_at timestamptz not null default now(),primary key(record_id,user_id,version)
);
create table trust_private.versions (
 record_id uuid not null references trust_private.records(id) on delete cascade,version integer not null,title text not null,body text not null,editor uuid not null,created_at timestamptz not null default now(),primary key(record_id,version)
);
create table trust_private.rate_limits (user_id uuid primary key,window_start timestamptz not null default now(),hits integer not null default 1);
alter table trust_private.records enable row level security;
alter table trust_private.events enable row level security;
alter table trust_private.messages enable row level security;
alter table trust_private.invitations enable row level security;
alter table trust_private.notifications enable row level security;
alter table trust_private.receipts enable row level security;
alter table trust_private.versions enable row level security;
alter table trust_private.rate_limits enable row level security;
revoke all on all tables in schema trust_private from public,anon,authenticated;

create function trust_private.role_for(org uuid) returns text language sql stable security definer set search_path='' as $$
 select role from trust_private.memberships where organization_id=org and user_id=(select auth.uid()) and active;
$$;
create function trust_private.can_read(rid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists (
 select 1 from trust_private.records r join trust_private.memberships m on m.organization_id=r.organization_id and m.user_id=auth.uid() and m.active
 where r.id=rid and (
 (r.kind in ('report','conversation') and (r.creator=auth.uid() or auth.uid()=any(r.participants)))
 or (r.kind='incident' and (r.creator=auth.uid() or auth.uid()=any(r.participants) or m.role in ('owner','manager','safety_rep')))
 or (r.kind='privacy' and (r.creator=auth.uid() or m.role='owner'))
 or (r.kind='handbook' and (r.status='published' or m.role in ('owner','manager')))
 or r.kind in ('improvement','risk','checklist')));
$$;
create function trust_private.has_session() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from auth.users u where u.id=auth.uid() and u.email_confirmed_at is not null and (u.banned_until is null or u.banned_until<now()))
 and exists(select 1 from auth.sessions s where s.id::text=auth.jwt()->>'session_id' and s.user_id=auth.uid() and (s.not_after is null or s.not_after>now()));
$$;
create function trust_private.storage_access(object_name text) returns boolean language plpgsql stable security definer set search_path='' as $$
 begin
 if not trust_private.has_session() then return false; end if;
 return trust_private.can_read(split_part(object_name,'/',2)::uuid) and exists(select 1 from trust_private.records where id=split_part(object_name,'/',2)::uuid and organization_id::text=split_part(object_name,'/',1));
 exception when invalid_text_representation then return false;
 end;
$$;

create function trust_private.dispatch(operation text,payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 uid uuid:=auth.uid(); org uuid; rid uuid; target uuid; role_name text; r trust_private.records%rowtype; inv trust_private.invitations%rowtype;
 result jsonb; d jsonb:=coalesce(payload->'data','{}'); parts uuid[]:='{}'; kind_name text; label text; actor_email text; hit_count int; a jsonb; actions jsonb; idx int; expected int;
begin
 if not trust_private.has_session() then raise exception 'Logg inn med en bekreftet konto.' using errcode='28000'; end if;
 if octet_length(payload::text)>100000 then raise exception 'Forespørselen er for stor.'; end if;
 select lower(email) into actor_email from auth.users where id=uid;
 if operation not in ('bootstrap','list','detail','export','notifications') then
  insert into trust_private.rate_limits(user_id) values(uid) on conflict(user_id) do update set
  hits=case when trust_private.rate_limits.window_start<now()-interval '1 minute' then 1 else trust_private.rate_limits.hits+1 end,
  window_start=case when trust_private.rate_limits.window_start<now()-interval '1 minute' then now() else trust_private.rate_limits.window_start end returning hits into hit_count;
  if hit_count>100 then raise exception 'For mange endringer. Prøv igjen om et minutt.'; end if;
 end if;
 if operation='bootstrap' then
  return jsonb_build_object('user_id',uid,'email',actor_email,'organizations',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name,'role',m.role,'display_name',m.display_name)) from trust_private.organizations o join trust_private.memberships m on m.organization_id=o.id where m.user_id=uid and m.active),'[]'),
  'invitations',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'organization',o.name,'role',i.role)) from trust_private.invitations i join trust_private.organizations o on o.id=i.organization_id where i.email=actor_email and i.expires_at>now() and i.accepted_at is null),'[]'));
 end if;
 if operation='create_org' then
  label:=trim(payload->>'name');
  if label is null or length(label) not between 2 and 150 then raise exception 'Bedriftsnavn må være 2–150 tegn.'; end if;
  if (select count(*) from trust_private.organizations where created_by=uid)>=10 then raise exception 'Maksimalt ti bedrifter per konto.'; end if;
  insert into trust_private.organizations(name,created_by) values(label,uid) returning id into org;
  insert into trust_private.memberships(organization_id,user_id,role,display_name) values(org,uid,'owner',left(coalesce(nullif(trim(payload->>'display_name'),''),'Administrator'),100));
  return jsonb_build_object('id',org);
 end if;
 if operation='accept_invitation' then
  select * into inv from trust_private.invitations where id=(payload->>'id')::uuid for update;
  if inv.id is null or inv.email<>actor_email or inv.expires_at<=now() or inv.accepted_at is not null then raise exception 'Invitasjonen er ugyldig eller utløpt.'; end if;
  if trust_private.role_for(inv.organization_id)='owner' then raise exception 'Du er allerede eier.'; end if;
  insert into trust_private.memberships(organization_id,user_id,role,display_name,active) values(inv.organization_id,uid,inv.role,left(coalesce(nullif(trim(payload->>'display_name'),''),'Medarbeider'),100),true)
  on conflict(organization_id,user_id) do update set active=true,role=excluded.role,display_name=excluded.display_name;
  update trust_private.invitations set accepted_at=now() where id=inv.id;
  return jsonb_build_object('id',inv.organization_id);
 end if;
 org:=(payload->>'organization_id')::uuid;
 role_name:=trust_private.role_for(org);
 if role_name is null then raise exception 'Du har ikke tilgang til denne bedriften.' using errcode='42501'; end if;
 if operation='members' then
  return coalesce((select jsonb_agg(jsonb_build_object('user_id',user_id,'role',role,'display_name',display_name,'active',active)) from trust_private.memberships where organization_id=org and (active or role_name='owner')),'[]');
 end if;
 if operation='invite' then
  if role_name<>'owner' then raise exception 'Kun eier kan invitere.'; end if;
  label:=lower(trim(payload->>'email'));
  if label is null or label !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' or length(label)>254 then raise exception 'Oppgi gyldig e-post.'; end if;
  if coalesce(payload->>'role','') not in ('employee','manager','trustee','safety_rep') then raise exception 'Ugyldig rolle.'; end if;
  insert into trust_private.invitations(organization_id,email,role,created_by) values(org,label,payload->>'role',uid) returning id into target;
  return jsonb_build_object('id',target,'message','Invitasjonen vises når mottakeren logger inn med denne e-postadressen. Ingen e-post er sendt.');
 end if;
 if operation='set_member' then
  if role_name<>'owner' then raise exception 'Kun eier kan endre tilgang.'; end if;
  target:=(payload->>'user_id')::uuid;
  if target=uid or exists(select 1 from trust_private.memberships where organization_id=org and user_id=target and role='owner') then raise exception 'Eier kan ikke endres her.'; end if;
  if coalesce(payload->>'role','') not in ('employee','manager','trustee','safety_rep') then raise exception 'Ugyldig rolle.'; end if;
  update trust_private.memberships set active=(payload->>'active')::boolean,role=payload->>'role' where organization_id=org and user_id=target;
  insert into trust_private.events(organization_id,actor,action) values(org,uid,'membership_changed');
  return '{"ok":true}';
 end if;
 if operation='profile' then
  label:=trim(payload->>'display_name');if label is null or length(label) not between 1 and 100 then raise exception 'Oppgi navn.';end if;
  update trust_private.memberships set display_name=label where organization_id=org and user_id=uid;return '{"ok":true}';
 end if;
 if operation='list' or operation='export' then
  return coalesce((select jsonb_agg(to_jsonb(x)) from (select r.* from trust_private.records r where r.organization_id=org and trust_private.can_read(r.id) order by updated_at desc)x),'[]');
 end if;
 if operation='notifications' then
  return coalesce((select jsonb_agg(to_jsonb(x)) from (select n.* from trust_private.notifications n where n.organization_id=org and n.recipient=uid and (n.record_id is null or trust_private.can_read(n.record_id)) order by created_at desc limit 100)x),'[]');
 end if;
 if operation='read_notification' then
  update trust_private.notifications set read_at=now() where id=(payload->>'id')::uuid and organization_id=org and recipient=uid;return '{"ok":true}';
 end if;
 if operation='create' then
  kind_name:=payload->>'kind';label:=trim(payload->>'title');
  if kind_name is null or kind_name not in ('incident','report','conversation','handbook','improvement','risk','checklist','privacy') then raise exception 'Ugyldig innholdstype.';end if;
  if label is null or length(label) not between 1 and 200 or length(coalesce(payload->>'body',''))>20000 then raise exception 'Kontroller tittel og tekstlengde.';end if;
  if kind_name='handbook' and role_name not in ('owner','manager') then raise exception 'Kun ledelsen kan publisere håndbok.';end if;
  if kind_name in ('report','conversation') then
   target:=(payload->>'recipient')::uuid;
   if target is null or target=uid or not exists(select 1 from trust_private.memberships where organization_id=org and user_id=target and active and (kind_name='conversation' or role in ('trustee','safety_rep','manager','owner'))) then raise exception 'Velg en annen aktiv mottaker i bedriften.';end if;
   parts:=array[target];
  end if;
  if kind_name='incident' then
   if coalesce(d->>'kind','') not in ('Avvik','Nestenulykke') or coalesce(d->>'severity','') not in ('Lav','Middels','Høy','Kritisk') or length(trim(coalesce(d->>'place',''))) not between 1 and 150 or (d->>'date')::date is null or (d->>'date')::date>current_date then raise exception 'Kontroller type, alvorlighet, sted og dato.';end if;
   d:=jsonb_build_object('kind',d->>'kind','severity',d->>'severity','place',d->>'place','date',(d->>'date')::date,'actions','[]'::jsonb);
  elsif kind_name='risk' then
   if (d->>'probability')::integer not between 1 and 5 or (d->>'consequence')::integer not between 1 and 5 or d->>'probability' is null or d->>'consequence' is null or length(trim(coalesce(d->>'measure','')))=0 or (d->>'review')::date is null then raise exception 'Kontroller risikovurderingen.';end if;
   target:=(d->>'owner')::uuid;
   if not exists(select 1 from trust_private.memberships where organization_id=org and user_id=target and active) then raise exception 'Velg aktiv ansvarlig.';end if;
   d:=jsonb_build_object('probability',(d->>'probability')::int,'consequence',(d->>'consequence')::int,'measure',left(d->>'measure',2000),'owner',target,'review',(d->>'review')::date);
  elsif kind_name='checklist' then
   if jsonb_typeof(d->'answers') is distinct from 'array' or jsonb_array_length(d->'answers')<>4 then raise exception 'Besvar alle fire sjekkpunktene.';end if;
   if exists(select 1 from jsonb_array_elements_text(d->'answers') x where x not in ('ok','avvik','na')) then raise exception 'Ugyldig sjekkliste.';end if;
   if d->'answers' ? 'avvik' and length(trim(coalesce(payload->>'body','')))=0 then raise exception 'Beskriv oppfølging av avvik.';end if;
   d:=jsonb_build_object('answers',d->'answers');
  else d:='{}'; end if;
  insert into trust_private.records(organization_id,kind,creator,participants,title,body,status,data) values(org,kind_name,uid,parts,label,coalesce(payload->>'body',''),case when kind_name='handbook' then 'draft' else 'open' end,d) returning * into r;
  insert into trust_private.events(organization_id,record_id,actor,action) values(org,r.id,uid,'created');
  insert into trust_private.notifications(organization_id,recipient,record_id,message) select org,p,r.id,'Du har fått en ny henvendelse i Vedoy Trust.' from unnest(parts) p;
  return to_jsonb(r);
 end if;
 rid:=(payload->>'id')::uuid;
 select * into r from trust_private.records where id=rid and organization_id=org for update;
 if r.id is null or not trust_private.can_read(r.id) then raise exception 'Innholdet finnes ikke eller er utilgjengelig.' using errcode='42501';end if;
 if operation='detail' then
  return jsonb_build_object('record',to_jsonb(r),'messages',coalesce((select jsonb_agg(to_jsonb(m) order by created_at) from trust_private.messages m where record_id=rid),'[]'),'events',coalesce((select jsonb_agg(to_jsonb(h) order by id) from trust_private.events h where record_id=rid),'[]'),
  'receipts',coalesce((select jsonb_agg(to_jsonb(c)) from trust_private.receipts c where record_id=rid and (user_id=uid or role_name in ('owner','manager'))),'[]'),
  'versions',coalesce((select jsonb_agg(to_jsonb(v) order by version desc) from trust_private.versions v where record_id=rid and role_name in ('owner','manager')),'[]'));
 end if;
 if operation='message' then
  if r.kind not in ('report','conversation') or r.status='closed' then raise exception 'Samtalen er lukket.';end if;
  label:=trim(payload->>'body');if label is null or length(label) not between 1 and 5000 then raise exception 'Meldingen må være 1–5000 tegn.';end if;
  insert into trust_private.messages(record_id,author,body) values(rid,uid,label);
  insert into trust_private.notifications(organization_id,recipient,record_id,message) select org,p,rid,'Ny melding i Vedoy Trust.' from unnest(array_append(r.participants,r.creator)) p where p<>uid;
 elsif operation='acknowledge' then
  if r.kind<>'handbook' or r.status<>'published' or (payload->>'version')::int is distinct from r.version then raise exception 'Dokumentet er endret. Les gjeldende versjon først.';end if;
  insert into trust_private.receipts(record_id,user_id,version) values(rid,uid,r.version) on conflict do nothing;return '{"ok":true}';
 else
  if operation in ('action_add','action_toggle','close','reopen','update','publish','delete') then
   if r.kind in ('report','conversation') then
    if r.kind='report' and not uid=any(r.participants) then raise exception 'Kun valgt mottaker kan behandle varselet.';end if;
   elsif r.kind='handbook' then
    if role_name not in ('owner','manager') then raise exception 'Kun ledelsen kan redigere håndbok.';end if;
   elsif r.kind='privacy' then
    if role_name<>'owner' then raise exception 'Kun eier kan behandle personvernhenvendelsen.';end if;
   elsif not (r.creator=uid or role_name in ('owner','manager','safety_rep') or uid=any(r.participants)) then raise exception 'Du kan ikke endre denne saken.';end if;
  end if;
  if operation='action_add' then
   if r.kind<>'incident' or r.status='closed' then raise exception 'Saken må være åpen.';end if;
   target:=(payload->>'owner')::uuid;label:=trim(payload->>'text');
   if label is null or length(label) not between 1 and 500 or (payload->>'due')::date is null or not exists(select 1 from trust_private.memberships where organization_id=org and user_id=target and active) then raise exception 'Tiltak trenger tekst, ansvarlig og gyldig frist.';end if;
   a:=jsonb_build_object('id',gen_random_uuid(),'text',label,'owner',target,'due',(payload->>'due')::date,'done',false);
   update trust_private.records set data=jsonb_set(data,'{actions}',data->'actions'||jsonb_build_array(a)),participants=case when target=any(participants) then participants else array_append(participants,target) end,status='in_progress' where id=rid;
   insert into trust_private.notifications(organization_id,recipient,record_id,message) values(org,target,rid,'Du er ansvarlig for et nytt tiltak.');
  elsif operation='action_toggle' then
   if r.kind<>'incident' or r.status='closed' then raise exception 'Saken må være åpen.';end if;
   select value,ordinality::int-1 into a,idx from jsonb_array_elements(r.data->'actions') with ordinality where value->>'id'=payload->>'action_id';
   if a is null then raise exception 'Tiltaket finnes ikke.';end if;
   update trust_private.records set data=jsonb_set(data,array['actions',idx::text,'done'],to_jsonb(not (a->>'done')::boolean)) where id=rid;
  elsif operation='update' then
   expected:=(payload->>'version')::int;
   if expected is distinct from r.version then raise exception 'Noen har endret innholdet. Last inn på nytt før du lagrer.';end if;
   if r.kind not in ('handbook','improvement','risk') then raise exception 'Innholdet kan ikke redigeres her.';end if;
   label:=trim(payload->>'title');if label is null or length(label) not between 1 and 200 or length(coalesce(payload->>'body',''))>20000 then raise exception 'Kontroller tittel og tekst.';end if;
   if r.kind='handbook' then insert into trust_private.versions(record_id,version,title,body,editor) values(rid,r.version,r.title,r.body,uid);end if;
   update trust_private.records set title=label,body=coalesce(payload->>'body',''),version=version+1,status=case when kind='handbook' then 'draft' else status end where id=rid;
  elsif operation='publish' then
   if r.kind<>'handbook' then raise exception 'Bare håndbøker kan publiseres.';end if;
   update trust_private.records set status='published' where id=rid;
   insert into trust_private.notifications(organization_id,recipient,record_id,message) select org,user_id,rid,'En håndbok er publisert. Les gjeldende versjon.' from trust_private.memberships where organization_id=org and active and user_id<>uid;
  elsif operation='close' then
   label:=trim(payload->>'summary');if label is null or length(label) not between 1 and 2000 then raise exception 'Beskriv resultatet.';end if;
   if r.kind='incident' and (jsonb_array_length(r.data->'actions')=0 or exists(select 1 from jsonb_array_elements(r.data->'actions') x where x->>'done'<>'true')) then raise exception 'Alle tiltak må fullføres før lukking.';end if;
   if r.kind='handbook' then raise exception 'Håndbøker bruker publisering.';end if;
   update trust_private.records set status='closed',data=data||jsonb_build_object('summary',label) where id=rid;
  elsif operation='reopen' then
   if r.status<>'closed' then raise exception 'Saken er ikke lukket.';end if;
   update trust_private.records set status='in_progress' where id=rid;
  elsif operation='delete' then
   if r.status not in ('closed','draft') then raise exception 'Lukk saken eller bruk et utkast før sletting.';end if;
   if exists(select 1 from storage.objects where bucket_id='trust-files' and split_part(name,'/',2)=rid::text) then raise exception 'Slett vedleggene først.';end if;
   delete from trust_private.records where id=rid;
   insert into trust_private.events(organization_id,record_id,actor,action) values(org,rid,uid,'deleted');return '{"ok":true}';
  else raise exception 'Ukjent handling.';end if;
 end if;
 update trust_private.records set updated_at=now() where id=rid;
 insert into trust_private.events(organization_id,record_id,actor,action) values(org,rid,uid,operation);
 return '{"ok":true}';
end;
$$;
create function public.trust_workspace(operation text,payload jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$ select trust_private.dispatch(operation,payload); $$;
revoke all on all functions in schema trust_private from public,anon,authenticated;
grant execute on function trust_private.dispatch(text,jsonb),trust_private.storage_access(text),trust_private.has_session(),trust_private.can_read(uuid),trust_private.role_for(uuid) to authenticated;
revoke all on function public.trust_workspace(text,jsonb) from public,anon;
grant execute on function public.trust_workspace(text,jsonb) to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('trust-files','trust-files',false,10485760,array['image/jpeg','image/png','application/pdf','text/plain']) on conflict(id) do nothing;
create policy trust_file_read on storage.objects for select to authenticated using(bucket_id='trust-files' and trust_private.storage_access(name));
create policy trust_file_insert on storage.objects for insert to authenticated with check(bucket_id='trust-files' and trust_private.storage_access(name) and owner_id=auth.uid()::text);
create policy trust_file_delete on storage.objects for delete to authenticated using(bucket_id='trust-files' and trust_private.storage_access(name) and owner_id=auth.uid()::text);
