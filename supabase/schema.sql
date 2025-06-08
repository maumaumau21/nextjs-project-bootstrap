-- Create profiles table to store user details
create table public.profiles (
    id uuid references auth.users on delete cascade primary key,
    full_name text not null,
    village text not null,
    role text not null check (role in ('admin', 'fasilitator')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create reports table to store SLP activity reports
create table public.reports (
    id uuid default gen_random_uuid() primary key,
    facilitator_id uuid references auth.users on delete cascade not null,
    village text not null,
    activity_date date not null,
    materials text not null,
    results text not null,
    additional_notes text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create report_images table to store report documentation images
create table public.report_images (
    id uuid default gen_random_uuid() primary key,
    report_id uuid references public.reports on delete cascade not null,
    image_url text not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create storage bucket for report images
insert into storage.buckets (id, name, public) 
values ('report-images', 'report-images', true);

-- Create policies for profiles table
create policy "Profiles are viewable by authenticated users"
    on profiles for select
    to authenticated
    using (true);

create policy "Users can insert their own profile"
    on profiles for insert
    to authenticated
    with check (auth.uid() = id);

create policy "Users can update own profile"
    on profiles for update
    to authenticated
    using (auth.uid() = id);

-- Create policies for reports table
create policy "Reports are viewable by authenticated users"
    on reports for select
    to authenticated
    using (
        -- Admin can view all reports
        exists (
            select 1 from profiles
            where profiles.id = auth.uid()
            and profiles.role = 'admin'
        )
        -- Facilitators can only view their own reports
        or facilitator_id = auth.uid()
    );

create policy "Facilitators can create reports"
    on reports for insert
    to authenticated
    with check (
        exists (
            select 1 from profiles
            where profiles.id = auth.uid()
            and profiles.role = 'fasilitator'
        )
        and auth.uid() = facilitator_id
    );

create policy "Users can update their own reports"
    on reports for update
    to authenticated
    using (
        -- Admin can update all reports
        exists (
            select 1 from profiles
            where profiles.id = auth.uid()
            and profiles.role = 'admin'
        )
        -- Facilitators can only update their own reports
        or facilitator_id = auth.uid()
    );

-- Create policies for report_images table
create policy "Report images are viewable by authenticated users"
    on report_images for select
    to authenticated
    using (true);

create policy "Users can insert images to their reports"
    on report_images for insert
    to authenticated
    with check (
        exists (
            select 1 from reports
            where reports.id = report_id
            and reports.facilitator_id = auth.uid()
        )
    );

create policy "Users can delete their report images"
    on report_images for delete
    to authenticated
    using (
        exists (
            select 1 from reports
            where reports.id = report_id
            and reports.facilitator_id = auth.uid()
        )
    );

-- Create storage policies
create policy "Report images are viewable by everyone"
    on storage.objects for select
    using ( bucket_id = 'report-images' );

create policy "Authenticated users can upload images"
    on storage.objects for insert
    to authenticated
    with check (
        bucket_id = 'report-images'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

-- Enable Row Level Security
alter table profiles enable row level security;
alter table reports enable row level security;
alter table report_images enable row level security;

-- Create function to handle user creation
create or replace function public.handle_new_user()
returns trigger as $$
begin
    insert into public.profiles (id, full_name, village, role)
    values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'village', new.raw_user_meta_data->>'role');
    return new;
end;
$$ language plpgsql security definer;

-- Create trigger for new user creation
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user();
