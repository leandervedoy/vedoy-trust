-- Rollback-only synthetic fixtures. Run as database administrator in staging first.
begin;
do $$
declare
 u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); w uuid:=gen_random_uuid(); s uuid:=gen_random_uuid(); t uuid:=gen_random_uuid(); z uuid:=gen_random_uuid();
 org uuid; other_org uuid; rid uuid; book uuid; invitation uuid; x jsonb; blocked boolean;
begin
 insert into auth.users(id,email,email_confirmed_at) values(u,u||'@example.invalid',now()),(v,v||'@example.invalid',now()),(w,w||'@example.invalid',now());
 insert into auth.sessions(id,user_id) values(s,u),(t,v),(z,w);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'session_id',s,'role','authenticated')::text,true);
 org:=(public.trust_workspace('create_org','{"name":"Rollback test A"}') ->>'id')::uuid;
 other_org:=(public.trust_workspace('create_org','{"name":"Rollback test B"}')->>'id')::uuid;
 insert into trust_private.memberships(organization_id,user_id,role) values(org,v,'employee'),(org,w,'trustee');
 invitation:=(public.trust_workspace('invite',jsonb_build_object('organization_id',other_org,'email',v||'@example.invalid','role','employee'))->>'id')::uuid;
 book:=(public.trust_workspace('create',jsonb_build_object('organization_id',org,'kind','handbook','title','Version one'))->>'id')::uuid;
 perform public.trust_workspace('publish',jsonb_build_object('organization_id',org,'id',book));
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v,'session_id',t,'role','authenticated')::text,true);
 rid:=(public.trust_workspace('create',jsonb_build_object('organization_id',org,'kind','report','title','Confidential','recipient',w))->>'id')::uuid;
 perform public.trust_workspace('message',jsonb_build_object('organization_id',org,'id',rid,'body','Private message'));
 perform public.trust_workspace('acknowledge',jsonb_build_object('organization_id',org,'id',book,'version',1));
 blocked:=false;begin perform public.trust_workspace('list',jsonb_build_object('organization_id',other_org)); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'Cross-tenant list allowed'; end if;
 if trust_private.storage_access(other_org||'/'||rid||'/file.pdf') then raise exception 'Wrong storage prefix allowed';end if;
 if not trust_private.storage_access(org||'/'||rid||'/file.pdf') then raise exception 'Authorized attachment denied';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'session_id',s,'role','authenticated')::text,true);
 blocked:=false;begin perform public.trust_workspace('detail',jsonb_build_object('organization_id',org,'id',rid));exception when insufficient_privilege then blocked:=true;end;
 if not blocked then raise exception 'Owner could read private report';end if;
 if trust_private.storage_access(org||'/'||rid||'/file.pdf') then raise exception 'Owner could read private attachment';end if;
 perform public.trust_workspace('update',jsonb_build_object('organization_id',org,'id',book,'version',1,'title','Version two'));
 blocked:=false;begin perform public.trust_workspace('update',jsonb_build_object('organization_id',org,'id',book,'version',1,'title','Stale'));exception when raise_exception then blocked:=true;end;
 if not blocked then raise exception 'Stale update allowed';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',w,'session_id',z,'role','authenticated')::text,true);
 blocked:=false;begin perform public.trust_workspace('accept_invitation',jsonb_build_object('id',invitation));exception when raise_exception then blocked:=true;end;
 if not blocked then raise exception 'Wrong email accepted invitation';end if;
 perform public.trust_workspace('close',jsonb_build_object('organization_id',org,'id',rid,'summary','Handled'));
 blocked:=false;begin perform public.trust_workspace('message',jsonb_build_object('organization_id',org,'id',rid,'body','After close'));exception when raise_exception then blocked:=true;end;
 if not blocked then raise exception 'Message after closure allowed';end if;
 update trust_private.memberships set active=false where organization_id=org and user_id=w;
 if trust_private.can_read(rid) then raise exception 'Revoked member still reads';end if;
 if has_table_privilege('authenticated','trust_private.records','SELECT') then raise exception 'Direct table access granted';end if;
 if has_function_privilege('anon','public.trust_workspace(text,jsonb)','EXECUTE') then raise exception 'Anonymous RPC granted';end if;
 delete from auth.sessions where id=z;
 if trust_private.has_session() then raise exception 'Revoked session accepted';end if;
end $$;
select 'PASS: tenant isolation, confidential owner exclusion, attachments, versions, invitation email, closure, membership/session revocation, grants' as result;
rollback;
