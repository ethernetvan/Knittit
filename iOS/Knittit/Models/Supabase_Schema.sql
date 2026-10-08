-- =================================================================================
-- Task 1: Relational Schema Generation
-- =================================================================================

-- Create profiles table
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    bio TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create follows table
CREATE TABLE public.follows (
    follower_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    following_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (follower_id, following_id)
);

-- Create projects table
CREATE TABLE public.projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    yarn_brand TEXT,
    tool_size TEXT,
    pattern_source TEXT,
    color_palette TEXT[],
    thumbnail_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create project_versions table
CREATE TABLE public.project_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE NOT NULL,
    progress_percentage INTEGER CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
    usdz_file_path TEXT,
    thumbnail_url TEXT,
    spatial_notes JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create reports table (required for App Store compliance)
CREATE TABLE public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    reported_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    reason TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =================================================================================
-- Task 2: Row Level Security (RLS) Policies
-- =================================================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------------
-- Profiles Policies
-- ---------------------------------------------------------------------------------
CREATE POLICY "Profiles are viewable by any authenticated user" 
ON public.profiles FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can update their own profile" 
ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);

CREATE POLICY "Users can delete their own profile" 
ON public.profiles FOR DELETE TO authenticated USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

-- ---------------------------------------------------------------------------------
-- Projects Policies
-- ---------------------------------------------------------------------------------
CREATE POLICY "Projects are viewable by any authenticated user" 
ON public.projects FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can update their own projects" 
ON public.projects FOR UPDATE TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own projects" 
ON public.projects FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own projects"
ON public.projects FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

-- ---------------------------------------------------------------------------------
-- Project Versions Policies
-- ---------------------------------------------------------------------------------
CREATE POLICY "Project versions are viewable by any authenticated user" 
ON public.project_versions FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can insert versions for their own projects" 
ON public.project_versions FOR INSERT TO authenticated 
WITH CHECK (EXISTS (SELECT 1 FROM public.projects WHERE id = project_id AND user_id = auth.uid()));

CREATE POLICY "Users can update versions for their own projects" 
ON public.project_versions FOR UPDATE TO authenticated 
USING (EXISTS (SELECT 1 FROM public.projects WHERE id = project_id AND user_id = auth.uid()));

CREATE POLICY "Users can delete versions for their own projects" 
ON public.project_versions FOR DELETE TO authenticated 
USING (EXISTS (SELECT 1 FROM public.projects WHERE id = project_id AND user_id = auth.uid()));

-- ---------------------------------------------------------------------------------
-- Follows Policies
-- ---------------------------------------------------------------------------------
CREATE POLICY "Authenticated users can insert their own follows" 
ON public.follows FOR INSERT TO authenticated WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Follows are viewable by any authenticated user"
ON public.follows FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can unfollow (delete their own follows)"
ON public.follows FOR DELETE TO authenticated USING (auth.uid() = follower_id);

-- ---------------------------------------------------------------------------------
-- Reports Policies
-- ---------------------------------------------------------------------------------
CREATE POLICY "Authenticated users can insert their own reports" 
ON public.reports FOR INSERT TO authenticated WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Users can view reports they submitted"
ON public.reports FOR SELECT TO authenticated USING (auth.uid() = reporter_id);


-- =================================================================================
-- Task 3: Storage Configuration
-- =================================================================================

-- Provision a new Supabase Storage bucket named 'scans'
INSERT INTO storage.buckets (id, name, public) 
VALUES ('scans', 'scans', true)
ON CONFLICT (id) DO NOTHING;

-- Storage Policies for 'scans' bucket

-- 1. Scans are publicly readable
CREATE POLICY "Scan files are publicly accessible"
ON storage.objects FOR SELECT TO public USING (bucket_id = 'scans');

-- 2. Authenticated users can upload scan files
CREATE POLICY "Authenticated users can upload scans"
ON storage.objects FOR INSERT TO authenticated 
WITH CHECK (bucket_id = 'scans' AND auth.uid() = owner);

-- 3. Authenticated users can update/delete their own scans
CREATE POLICY "Authenticated users can update their own scans"
ON storage.objects FOR UPDATE TO authenticated 
USING (bucket_id = 'scans' AND auth.uid() = owner);

CREATE POLICY "Authenticated users can delete their own scans"
ON storage.objects FOR DELETE TO authenticated 
USING (bucket_id = 'scans' AND auth.uid() = owner);
