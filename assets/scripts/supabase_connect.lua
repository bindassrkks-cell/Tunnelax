-- Supabase & Storage Bucket "Raaz" Connector
SupabaseConfig = {
    project_url = "https://your-project.supabase.co",
    bucket_name = "Raaz",
    auth_mode = "Bearer_Token",
    api_version = "v1"
}

function ConnectSupabaseDatabase()
    print("[Lua Engine] Connecting to Supabase PostgREST API...")
    return {
        status = "CONNECTED",
        bucket = SupabaseConfig.bucket_name,
        endpoint = SupabaseConfig.project_url .. "/storage/v1/object/public/" .. SupabaseConfig.bucket_name
    }
end

function FetchMediaSignUrl(movieId)
    return SupabaseConfig.project_url .. "/storage/v1/object/authenticated/" .. SupabaseConfig.bucket_name .. "/" .. movieId .. ".mp4"
end

ConnectSupabaseDatabase()
