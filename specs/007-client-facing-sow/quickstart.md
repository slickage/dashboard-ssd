# Quickstart – Client-Facing SOW Storage & Access

1. **Sync branch & deps**  
   ```bash
   git checkout 007-client-facing-sow
   mix setup
   ```

2. **Configure integrations**  
   - Populate Drive service account creds + root folder ID in `config/*.exs`.  
   - Ensure Notion integration token + database IDs are set so tagged pages can sync.  
   - Confirm ETS cache sizing (`DashboardSSD.Cache`) allows new namespaces.

3. **Run migrations**  
   ```bash
   mix ecto.migrate
   ```  
   Creates `shared_documents` (+ `document_access_logs` if enabled) and any project folder columns.

4. **Seed/Backfill metadata**  
   - Execute Drive bootstrap task to record `drive_folder_id` per project.  
   - Optionally run a one-off script to tag existing Notion pages with Doc Type/Visibility properties.

5. **Start services**  
   ```bash
   iex -S mix phx.server
   ```  
   Drive + Notion sync jobs can be triggered manually via `DashboardSSD.Projects.SharedDocuments.sync_now/0`.

6. **Exercise UI**  
   - Visit Projects → Contracts tab as admin/employee (requires `projects.contracts.manage`).  
   - Log in as client to verify filtered view/downloads.  
   - Flip “Client can edit” toggle and ensure Drive ACL updates succeed.

7. **Run tests**  
   ```bash
   mix test
   mix coveralls.ci
   ```

8. **Final verification**  
   ```bash
   mix format
   mix credo
   mix dialyzer
   mix doctor
   mix check
   ```
