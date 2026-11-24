-- BETMA LUCKY WHEEL – chạy toàn bộ file này trong Supabase > SQL Editor
create table if not exists prizes(
  id int primary key, name text not null, unlimited bool not null default false,
  initial_qty int, awarded int not null default 0, weight int not null default 0, active bool not null default true);
insert into prizes(id,name,unlimited,initial_qty,weight) values
 (1,'SỔ TAY',false,20,20),(2,'MÓC KHÓA',true,null,40),
 (3,'LY SỨ',false,10,20),(4,'KHÓA HỌC TIẾNG ANH CHUYÊN NGÀNH',true,null,20)
on conflict (id) do nothing;

create table if not exists participants(
  id uuid primary key default gen_random_uuid(),
  full_name text not null, faculty text not null, phone text not null unique,
  joined_at timestamptz not null default now(),
  spin_code text not null default upper(substr(md5(random()::text),1,8)),
  prize_id int references prizes(id), status text not null default 'registered');

alter table prizes enable row level security;
alter table participants enable row level security;
create policy "anon đọc tên quà" on prizes for select to anon using (true);
create policy "admin toàn quyền prizes" on prizes for all to authenticated using (true) with check (true);
create policy "admin toàn quyền participants" on participants for all to authenticated using (true) with check (true);

create or replace function register(p_name text,p_faculty text,p_phone text) returns jsonb
language plpgsql security definer set search_path=public as $$
declare ph text:=regexp_replace(coalesce(p_phone,''),'\D','','g'); r participants;
begin
  if coalesce(trim(p_name),'')='' or coalesce(trim(p_faculty),'')='' then return jsonb_build_object('error','missing'); end if;
  if ph !~ '^0\d{9,10}$' then return jsonb_build_object('error','bad_phone'); end if;
  select * into r from participants where phone=ph;
  if found then
    if r.status='registered' then return jsonb_build_object('id',r.id); end if;
    return jsonb_build_object('error','duplicate');
  end if;
  insert into participants(full_name,faculty,phone) values(trim(p_name),trim(p_faculty),ph) returning * into r;
  return jsonb_build_object('id',r.id);
end $$;

-- Quay: xác suất + trừ kho nằm trong 1 transaction, khóa dòng để không trao vượt số lượng
create or replace function spin(p_id uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare r participants; c prizes; x numeric; tot numeric;
begin
  select * into r from participants where id=p_id for update;
  if not found then return jsonb_build_object('error','not_found'); end if;
  if r.prize_id is not null then
    select * into c from prizes where id=r.prize_id;
    return jsonb_build_object('prize_id',c.id,'name',c.name,'again',true);
  end if;
  perform id from prizes order by id for update;
  select sum(weight) into tot from prizes where active and weight>0 and (unlimited or awarded<initial_qty);
  if tot is null then return jsonb_build_object('error','no_prize'); end if;
  x:=random()*tot;
  for c in select * from prizes where active and weight>0 and (unlimited or awarded<initial_qty) order by id loop
    x:=x-c.weight; exit when x<=0;
  end loop;
  update prizes set awarded=awarded+1 where id=c.id;
  update participants set prize_id=c.id,status='spun' where id=r.id;
  return jsonb_build_object('prize_id',c.id,'name',c.name);
end $$;

create or replace function confirm_prize(p_id uuid) returns void
language sql security definer set search_path=public as $$
  update participants set status='received' where id=p_id and status='spun' $$;

create or replace function reset_event() returns void
language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'Chỉ admin được reset'; end if;
  delete from participants where true;
  update prizes set awarded=0 where true;
end $$;

create or replace function remove_participant(p_id uuid) returns void
language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'Chỉ admin được xóa'; end if;
  delete from participants where id=p_id;
end $$;

revoke all on function reset_event(), remove_participant(uuid) from public, anon;
grant execute on function register(text,text,text), spin(uuid), confirm_prize(uuid) to anon, authenticated;
grant execute on function reset_event(), remove_participant(uuid) to authenticated;
