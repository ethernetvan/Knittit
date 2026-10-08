# TODOs for Sync

- [ ] Edit the Supabase schema and SwiftData models to track the `updated_at` (last edit) timestamp. This will handle proper conflict resolution so if a phone is out of sync and offline, when it comes back online it'll resolve correctly against the updated web version instead of blindly overwriting it via last-write-wins.
- [ ] On iPhone, convert the `.usdz` to `.glb` format and also upload that `.glb` file alongside the `.usdz` file to Supabase storage to ensure Android compatibility.
