## [1.2.1](https://github.com/slickage/dashboard-ssd/compare/v1.2.0...v1.2.1) (2025-10-10)


### Bug Fixes

* install nodejs npm in Docker build stage ([aef9d00](https://github.com/slickage/dashboard-ssd/commit/aef9d006845f3b7bd7200f8e4428143ef156ac95))

# [1.2.0](https://github.com/slickage/dashboard-ssd/compare/v1.1.1...v1.2.0) (2025-10-10)


### Features

* prepare repo for continuous deployment with Docker and GHCR ([ce8422b](https://github.com/slickage/dashboard-ssd/commit/ce8422b673031911842111b8b6b53fc2f4ea1842))

## [1.1.1](https://github.com/slickage/dashboard-ssd/compare/v1.1.0...v1.1.1) (2025-10-08)


### Bug Fixes

* **auth:** avoid dialyzer false boolean warning ([4ac31f4](https://github.com/slickage/dashboard-ssd/commit/4ac31f4863804e88fc6b20f538b138a193c5312b))
* **auth:** derive test redirect flag from config ([054dac3](https://github.com/slickage/dashboard-ssd/commit/054dac367b086a7eefbfc35ee3954c66fbdd4876))
* **css:** add standard mask fallback ([6bbf4d1](https://github.com/slickage/dashboard-ssd/commit/6bbf4d14cebc93e1a9eed89ad852d10c287d692c))

# [1.1.0](https://github.com/slickage/dashboard-ssd/compare/v1.0.0...v1.1.0) (2025-10-02)


### Bug Fixes

* **auth:** remove unused logger require ([251abb3](https://github.com/slickage/dashboard-ssd/commit/251abb3e2c6c42516e54bbbc1d0d2477c3eebc7a))
* **theme:** restore light shell gradient ([04289ce](https://github.com/slickage/dashboard-ssd/commit/04289ce9ed4731454ee60d2183441abdf13b9698))


### Features

* **theme:** enhance light shell gradient ([8e2b1a4](https://github.com/slickage/dashboard-ssd/commit/8e2b1a40777d161db92c590094a898ad272f05b7))
* **ui:** show runtime app version in sidebar ([aaad850](https://github.com/slickage/dashboard-ssd/commit/aaad850fac0b4dc60c45aed52e21690131f88963))

# 1.0.0 (2025-09-30)


### Bug Fixes

* add 5s timeout to health check HTTP requests ([4486222](https://github.com/slickage/dashboard-ssd/commit/448622258683a6d558c55e266ddcbdbd122f4642))
* **analytics:** allow scheduler name override ([96797f1](https://github.com/slickage/dashboard-ssd/commit/96797f17bae9f96893438239a4f79b607d27a96f))
* **analytics:** set Finch request timeout ([1bba4ab](https://github.com/slickage/dashboard-ssd/commit/1bba4ab99fa7840b0ae4425950aaab7a02a43bf2))
* **auth:** handle safe tuples in OAuth redirect to prevent Protocol.UndefinedError ([ea9ecb4](https://github.com/slickage/dashboard-ssd/commit/ea9ecb4b1657b0811d53f9475779a953406a4e84))
* **auth:** properly close OAuth popup after authentication ([955c04c](https://github.com/slickage/dashboard-ssd/commit/955c04c727963efb03563e7c4120a93540ea6e32))
* **auth:** properly handle OAuth popup closure in production ([3d00c5f](https://github.com/slickage/dashboard-ssd/commit/3d00c5f0f88e4ec1079844be18bcfa7da4a15aec))
* change navigation logo from pill to square shape ([631138e](https://github.com/slickage/dashboard-ssd/commit/631138e6449907cbc4e4fba2cdc3c2c6ce48aa8c))
* **ci:** align workflow with elixir 1.18 ([0778ac7](https://github.com/slickage/dashboard-ssd/commit/0778ac7bef97a3f194a8d3a7049503ecd477b1b8))
* **ci:** ensure update_version runs from repo root ([92facf0](https://github.com/slickage/dashboard-ssd/commit/92facf02b4bef5e7ba922e3668cf0a10af38deec))
* **ci:** invoke semantic-release via npx ([1798a3c](https://github.com/slickage/dashboard-ssd/commit/1798a3c33d5a842fcbf6e0ae2959e6d542d6b28f))
* **ci:** pin semantic-release install step ([bfff239](https://github.com/slickage/dashboard-ssd/commit/bfff23904965f1c53618ccc076f8c09389658346))
* **ci:** run semantic-release v22 for action ([31577c1](https://github.com/slickage/dashboard-ssd/commit/31577c1ca05ae8e52bf11688e7bbf8c0fb233ea3))
* **ci:** treat hex outdated as advisory ([d316785](https://github.com/slickage/dashboard-ssd/commit/d3167851103bd7d2d99053affbd618c05ee5fe30))
* **clients-live:** link View Projects to /projects (LiveView) instead of /protected/projects ([bcbb9c2](https://github.com/slickage/dashboard-ssd/commit/bcbb9c22d1a9b7236446c0fc24e454bc11e04d8e))
* **code-quality:** resolve mix check issues ([f49353b](https://github.com/slickage/dashboard-ssd/commit/f49353b0859ab892f72fabce97d7c88594ca5aeb))
* enhance flash messages and navigation ([b174969](https://github.com/slickage/dashboard-ssd/commit/b174969687cb809806f54c028a097e841b94717d))
* **githooks:** set up mix check on pre push in config ([32a1537](https://github.com/slickage/dashboard-ssd/commit/32a15375f2e775a791942f6e00c255866c6f80bf))
* **header:** restore sticky header behavior on LiveView navigation ([b10ca37](https://github.com/slickage/dashboard-ssd/commit/b10ca37f75a3fa0b80c2329ec1c6fb95a620aebb))
* **health-checks:** reduce complexity by splitting attr builders; ensure HTTP enabled requires URL; reflect form state live; filter Prod status by enabled ([2ab4dcb](https://github.com/slickage/dashboard-ssd/commit/2ab4dcb3ff07f8ef0fe4a04202821ebe310258af))
* **home-live:** stabilise workload summary loading ([c2fb693](https://github.com/slickage/dashboard-ssd/commit/c2fb693738836c69d99bed5027726307b210144a))
* **kb-live:** harden notion search handling ([c8e00f4](https://github.com/slickage/dashboard-ssd/commit/c8e00f4296c20635af2f48ec9a749cf26fd3eb29))
* **linear:** use raw token in Authorization header (no Bearer) and align tests ([a35b6c3](https://github.com/slickage/dashboard-ssd/commit/a35b6c348cd7839aacd250ef83544dd38859edbb))
* make collector tests more robust against database state ([3153cb2](https://github.com/slickage/dashboard-ssd/commit/3153cb20e247f08285d8bedb713a9b63f21c781f))
* make settings view table consistent with other views ([00bad10](https://github.com/slickage/dashboard-ssd/commit/00bad100a301753a841c1f154962be5fbc4d5e80))
* **policy:** limit employee read subjects to projects and kb; add nil-user deny test ([d92943b](https://github.com/slickage/dashboard-ssd/commit/d92943bb20f1ab16d52538b280b3736458612930))
* prevent Finch HTTP calls in test environment ([67ac564](https://github.com/slickage/dashboard-ssd/commit/67ac564692b6cf8ede5d9961a569b4eeadedc210))
* **projects-live:** check Linear enabled from app config only for consistent behavior ([817d81f](https://github.com/slickage/dashboard-ssd/commit/817d81f2327105901bc00859bc3d4ae822857b34))
* **projects-live:** remove compile-time env attribute; use runtime env to guard Linear summary in tests only ([266211f](https://github.com/slickage/dashboard-ssd/commit/266211f062d882d5c921a83625cda0e2ab080c5b))
* **projects:** preserve existing client on Linear sync; only fill when missing ([9cd2554](https://github.com/slickage/dashboard-ssd/commit/9cd255468df648cb1593b46abc81626aa2a806a4))
* resolve all Credo warnings ([b52d28e](https://github.com/slickage/dashboard-ssd/commit/b52d28e87f8f2d437a517cd08c27b6dac49f4e7a))
* resolve failing tests and improve coverage ([8841112](https://github.com/slickage/dashboard-ssd/commit/8841112ff20cc169440f191d7be839e254376d0a))
* resolve server startup warnings ([c7fb9b8](https://github.com/slickage/dashboard-ssd/commit/c7fb9b85a0cb1bc572c294c82c19474a135aad92))
* restore proper theme styling for cards and widgets ([bf636ab](https://github.com/slickage/dashboard-ssd/commit/bf636abaa36aec34d4ee6e0e9480cf3590f7b9c6))
* revert light theme primary color change ([e3b5f66](https://github.com/slickage/dashboard-ssd/commit/e3b5f669d3b62661ec6d0e30f62082bdc8f26431)), closes [#c2b7d7](https://github.com/slickage/dashboard-ssd/issues/c2b7d7) [#3b4977](https://github.com/slickage/dashboard-ssd/issues/3b4977)
* **security:** prevent XSS in OAuth callback redirect ([59d5685](https://github.com/slickage/dashboard-ssd/commit/59d5685f2abbd7104ff2e34756b0753d65681fea))
* **security:** remove unsafe svg chart output ([055ad4d](https://github.com/slickage/dashboard-ssd/commit/055ad4d2f0cafd5cf551592608d06be73c1a29a4))
* theme toggle background color in settings ([1271093](https://github.com/slickage/dashboard-ssd/commit/12710934cd51bb873e4ae08a4446cfe78bb869ae))
* **theme:** adjust toggle and delete button colors ([fd353cd](https://github.com/slickage/dashboard-ssd/commit/fd353cd1d2a3228f31bcb253f4e031923bf6ee6e))
* **theme:** eliminate theme flickering during view changes ([72db321](https://github.com/slickage/dashboard-ssd/commit/72db32130df5907d9b88abbc5c2f8d88eb89679f))
* **theme:** improve toggle and delete button appearance in light mode ([3f52b04](https://github.com/slickage/dashboard-ssd/commit/3f52b04344c3f3e9372148ef0e2d946406d4975b))
* **ui:** harden LiveView flash auto-dismiss hook ([5460d8e](https://github.com/slickage/dashboard-ssd/commit/5460d8ea08556ee90f3a4b4e49bec6e6a61a4039))
* update tests for async Linear and health loading ([bc0f4fb](https://github.com/slickage/dashboard-ssd/commit/bc0f4fbf3d590e3b6d061b697d2e9cd28e2e02e4))


### Features

* **accounts:** add basic user CRUD (list, change, update, delete); test coverage for CRUD (T010) ([09a3a71](https://github.com/slickage/dashboard-ssd/commit/09a3a711a554b5538bf971021bce968fcff9500c))
* add analytics components for chart visualization ([b38c613](https://github.com/slickage/dashboard-ssd/commit/b38c6137159f4d0e0daa8b1f979ad64a29cb8ce2))
* add Contex library for analytics chart visualization ([c26418b](https://github.com/slickage/dashboard-ssd/commit/c26418bca75fc3553bc2ddc17099362e87c93395))
* **auth:** add UserAuth on_mount hooks and LiveView session, fix Ueberauth callback plugs\n\n- Add DashboardSSDWeb.UserAuth with mount_current_user and generic :require gate (auth + RBAC)\n- Use live_session with session MFA to pass user_id/current_path to LiveViews\n- Guard /clients via router with {UserAuth, {:require, :read, :clients}}\n- AuthController: store redirect_to, use it after login; plug Ueberauth for callback_get/post ([0803f4c](https://github.com/slickage/dashboard-ssd/commit/0803f4cbe9aa580ee9d3ebae50e90a200bdae31b))
* **auth:** center OAuth popup on current monitor ([81987b3](https://github.com/slickage/dashboard-ssd/commit/81987b3ce0a7c2c01164483469099e55d128d1f0))
* **auth:** center OAuth popup window on screen ([5fc7b63](https://github.com/slickage/dashboard-ssd/commit/5fc7b630e3751d4d65115fc349a5408e47c952e7))
* **auth:** implement login page with Google OAuth button ([4f81363](https://github.com/slickage/dashboard-ssd/commit/4f81363f62a29d1955bb67cff18dff013c2eede0))
* **auth:** implement OAuth in popup window and clean up login UI ([609e237](https://github.com/slickage/dashboard-ssd/commit/609e2374f018cfd9bfd3ae9f982b15a826c43447))
* **auth:** integrate Ueberauth Google, add POST callback and logout routes, and normalize expires_at in controller ([274076b](https://github.com/slickage/dashboard-ssd/commit/274076ba165a4b4c1a597bba6571910bca34939e))
* **auth:** make first created user admin by default ([65ef4a1](https://github.com/slickage/dashboard-ssd/commit/65ef4a15607ce5b99ad08970d7ed35eea35f25f6))
* change dark theme primary color to [#024](https://github.com/slickage/dashboard-ssd/issues/024)caa ([81a67a9](https://github.com/slickage/dashboard-ssd/commit/81a67a9dbea0f65e742ee94d711288ed7c3d88f2)), closes [#3b4977](https://github.com/slickage/dashboard-ssd/issues/3b4977)
* change primary color to [#3](https://github.com/slickage/dashboard-ssd/issues/3)b4977 ([549b0d8](https://github.com/slickage/dashboard-ssd/commit/549b0d8745bfc9de83db0795983a47d1bf93c2df)), closes [#3b4977](https://github.com/slickage/dashboard-ssd/issues/3b4977) [#2c5](https://github.com/slickage/dashboard-ssd/issues/2c5) [#3b4977](https://github.com/slickage/dashboard-ssd/issues/3b4977)
* **ci:** add hex.outdated check to mix check and CI for dependency update monitoring ([8bcb90b](https://github.com/slickage/dashboard-ssd/commit/8bcb90b15b5c4475edfe3346b665dd70a9e15b36))
* **ci:** integrate semantic-release workflow ([5cb2688](https://github.com/slickage/dashboard-ssd/commit/5cb26884b0629bbb3f9a021e1528c782c2919234))
* **ci:** make ci and mix check use mix doctor minimum coverage ([f04e3c6](https://github.com/slickage/dashboard-ssd/commit/f04e3c6b5cc61c65988fe65678b5779975dbed06))
* **clients:** add Clients context and Client schema with full CRUD; tests (T011/T012) ([b09cb88](https://github.com/slickage/dashboard-ssd/commit/b09cb8838e620563b27c004c2742acf0ee08c7cf))
* **clients:** LiveView with search, create/edit modal, delete + PubSub refresh\n\n- Add Clients.search_clients/1 and PubSub broadcasts on create/update/delete\n- Subscribe in ClientsLive.Index and refresh list on events\n- Implement New/Edit modal via LiveComponent; admin-only mutations\n- Add live routes for /clients, /clients/new, /clients/:id/edit ([1396d37](https://github.com/slickage/dashboard-ssd/commit/1396d37214db6b075fca3532196d0086cb8b7dc8))
* **contracts:** add SOW and Change Request schemas/context with CRUD and by-project queries; tests (T015/T016) ([9caf09f](https://github.com/slickage/dashboard-ssd/commit/9caf09f3587a98960e4c61983ecd9e9ec067c1f3))
* **dashboard:** implement home dashboard with project/client overview and metrics ([ed14229](https://github.com/slickage/dashboard-ssd/commit/ed14229b3e2dee1fdfe77d05353b3689fe2c9b0f))
* **db:** add core schema migration for roles/users/clients/projects/etc. (T003) ([59f6c82](https://github.com/slickage/dashboard-ssd/commit/59f6c82dd6683d58033b0610d3309e05c708fead))
* enhance analytics dashboard and projects view ([1341b04](https://github.com/slickage/dashboard-ssd/commit/1341b04ec678171190e892d97f8bf1096b165fa6))
* **health-check:** add custom provider support and fix unknown provider logging ([4dda1e3](https://github.com/slickage/dashboard-ssd/commit/4dda1e3731b76023700c8d5ba9740f98b10369a5))
* implement advanced Tailwind CSS improvements ([870eb47](https://github.com/slickage/dashboard-ssd/commit/870eb471d7e1d8df46cf4b55aadbef17da28b75c))
* **integrations:** env-based token config + wrappers and docs; ignore .env; expand Google OAuth for Drive read-only\n\n- Add .env.example and load .env in dev/test\n- Configure :dashboard_ssd, :integrations to read LINEAR/SLACK/NOTION API keys\n- Add Integrations wrappers for Linear/Slack/Notion/Drive (IEx-friendly)\n- Ignore .env in VCS\n- Docs: integrations setup and manual IEx testing\n- Google OAuth: add Drive read-only scope, offline access, consent prompt ([b18e408](https://github.com/slickage/dashboard-ssd/commit/b18e4086f3548c50a97f53f0b6c6b970099657ee))
* **kb:** add knowledge base liveview with notion search ([4419447](https://github.com/slickage/dashboard-ssd/commit/4419447464042e81ba7ff3ba7340d792a8c2bed0))
* **mobile:** implement complete mobile responsiveness and UI improvements ([d851136](https://github.com/slickage/dashboard-ssd/commit/d851136293815cf75c9c9d2157115260599744a3))
* **navigation:** implement SPA navigation with authorization ([78f2834](https://github.com/slickage/dashboard-ssd/commit/78f28342850e580a54791494b563d5cc0bc69a41))
* **phase-3.3:** add Deployments and Notifications contexts with tests; reorganize tasks for new Phase 3.4 Integration APIs and renumber phases ([ae6a5d9](https://github.com/slickage/dashboard-ssd/commit/ae6a5d93d852445134453831f2be713effb61488))
* **phase-3.4:** add initial Integration API clients (Linear, Slack, Notion, Drive) with Tesla + tests via Tesla.Mock; configure tests to use mock adapter ([dd0c552](https://github.com/slickage/dashboard-ssd/commit/dd0c552e9b45ec5fbb62259b162d6985c8c02eb2))
* **projects-live:** add Production status column using latest HealthCheck per project (colored dot) ([255e51e](https://github.com/slickage/dashboard-ssd/commit/255e51e1a6599523ce719ec8ffd1b3ea55b18d24))
* **projects-live:** allow configuring Health Check providers in Edit modal; add health_check_settings schema + migration; guard Linear summary in tests unless Tesla.Mock adapter is set; env fallback handles empty config values ([53ab12f](https://github.com/slickage/dashboard-ssd/commit/53ab12f5ba581be63e637b007e2179e82bca7dce))
* **projects-live:** minimal dot-based task counts with aligned progress bar; robust Linear lookup and state mapping; load .env before reading integrations ([dbd9ef8](https://github.com/slickage/dashboard-ssd/commit/dbd9ef847df1e5a3c11b0ed5b2d73b5c3761d215))
* **projects:** add Project schema/context with CRUD + by-client query; tests (T013/T014); docs/specs aligned ([0529994](https://github.com/slickage/dashboard-ssd/commit/052999485fa1d13ffdfe1f276ea43bc5b037ed3f))
* **rbac:** add CurrentUser and Authorize plugs; protect routes; add authorization tests; mark T006-T008 complete ([a08fa34](https://github.com/slickage/dashboard-ssd/commit/a08fa3472a8d54a3a9a4032072ec2eb19abace81))
* scaffold Phoenix 1.7.14 app in root (T001) ([a8cd67e](https://github.com/slickage/dashboard-ssd/commit/a8cd67eca88abb6b16d7e6741a3c7b2d49744bc8))
* **security:** encrypt OAuth tokens with Cloak, add vault and migration; update Accounts upsert and runtime config ([5e37ef9](https://github.com/slickage/dashboard-ssd/commit/5e37ef9fdd7fea3cfb9eefe211b1d3b89ac8e019))
* **settings:** Add Settings/Integrations LiveView (T034) with basic connection states for Google, Linear, Slack, Notion, GitHub placeholder; tests for states (T033) ([0094635](https://github.com/slickage/dashboard-ssd/commit/00946351a912f3d9130100f23605ffe04ce59cd1))
* **tasks:** update task list ([c64bbca](https://github.com/slickage/dashboard-ssd/commit/c64bbca33c306acc4472b4721489cf11403a2bb3))
* **theme:** implement comprehensive light/dark theme system ([bed6308](https://github.com/slickage/dashboard-ssd/commit/bed6308390fa86a59790d04bfcb3d411dd5e9d83))
* **theme:** implement light/dark theme toggle with improved contrast ([48c16a3](https://github.com/slickage/dashboard-ssd/commit/48c16a33e66ac7b00e55c856baee501ab7c53d31))
* **theme:** introduce reusable layout and navigation ([0c21278](https://github.com/slickage/dashboard-ssd/commit/0c212784e31aa0d3d934720d7b60eddc4bdf04b9))


### BREAKING CHANGES

* **mobile:** Sidebar layout changes may affect custom CSS targeting sidebar elements
