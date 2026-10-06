create table if not exists public.property_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  original_name text not null,
  content_type text not null check (
    content_type in (
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'image/jpeg',
      'image/png'
    )
  ),
  file_size bigint not null check (file_size > 0 and file_size <= 20971520),
  storage_path text unique,
  created_at timestamptz not null default now()
);

create index if not exists property_documents_owner_property_created_idx
  on public.property_documents (user_id, property_id, created_at desc);

alter table public.property_documents enable row level security;

drop policy if exists property_documents_owner_access
  on public.property_documents;

create policy property_documents_owner_access
  on public.property_documents
  for all
  to authenticated
  using (
    user_id = auth.uid()
    and exists (
      select 1
      from public.properties as property
      where property.id = property_documents.property_id
        and property.user_id = auth.uid()
    )
  )
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.properties as property
      where property.id = property_documents.property_id
        and property.user_id = auth.uid()
    )
  );

grant select, insert, update, delete
  on public.property_documents to authenticated;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'property-documents',
  'property-documents',
  false,
  20971520,
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/jpeg',
    'image/png'
  ]
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists property_documents_storage_select
  on storage.objects;
create policy property_documents_storage_select
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'property-documents'
    and cardinality(storage.foldername(name)) = 2
    and exists (
      select 1
      from public.properties as property
      where property.id::text = (storage.foldername(name))[1]
        and property.user_id = auth.uid()
    )
  );

drop policy if exists property_documents_storage_insert
  on storage.objects;
create policy property_documents_storage_insert
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'property-documents'
    and cardinality(storage.foldername(name)) = 2
    and exists (
      select 1
      from public.properties as property
      where property.id::text = (storage.foldername(name))[1]
        and property.user_id = auth.uid()
    )
  );

drop policy if exists property_documents_storage_delete
  on storage.objects;
create policy property_documents_storage_delete
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'property-documents'
    and cardinality(storage.foldername(name)) = 2
    and exists (
      select 1
      from public.properties as property
      where property.id::text = (storage.foldername(name))[1]
        and property.user_id = auth.uid()
    )
  );
