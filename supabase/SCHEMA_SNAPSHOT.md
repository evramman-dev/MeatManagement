# Live schema reference snapshot

Snapshot date: 2026-11-21  
Supabase project: `mklbemoisdkoyrwcrmoj`  
Source: Supabase-generated TypeScript database types  
Branch: `main` at commit `bc5d0788e9a81c2346cbe06ce92b31626a0dc8e7`

## Purpose
`database.types.ts` records the public Data API schema as seen by Supabase on the snapshot date. It provides a durable reference for public tables, functions, relationships, and exposed types represented by the generator. This snapshot includes the `record_current_user_login()` RPC added in migration `20261121105602`.

## Important limits
- This is a reference snapshot, not an executable SQL migration.
- It does not recreate table constraints, indexes, triggers, RLS policies, grants, storage configuration, Auth configuration, or private-schema objects.
- It does not include historical SQL migration source.
- It cannot replace the missing migration SQL files documented in `MIGRATION_HISTORY.md`.
- It must not be used as proof that a fresh database can be rebuilt from the current repository.
- Regenerate it after approved schema changes, and review the diff before committing.

## Safety
This snapshot was generated using schema metadata only. No business rows were exported and no business records were changed by type generation.
