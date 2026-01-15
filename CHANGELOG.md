# [1.10.0](https://github.com/slickage/dashboard-ssd/compare/v1.9.0...v1.10.0) (2026-01-15)


### Bug Fixes

* **ci:** bump version ([e3bf89e](https://github.com/slickage/dashboard-ssd/commit/e3bf89eef0d92a1528e06e930d66a87c687956f8))
* **ci:** bump version ([c6a71ec](https://github.com/slickage/dashboard-ssd/commit/c6a71ecb9231d6ef31f4b6ff4c4079ab40512da3))
* **ci:** bump version ([0a90f0b](https://github.com/slickage/dashboard-ssd/commit/0a90f0b732beffb6205c926bed7877c7227bf256))
* **ci:** bump version ([befcc22](https://github.com/slickage/dashboard-ssd/commit/befcc2299dfa8f63376534e35688e7b14d961ccd))
* **clients:** redirect (push_navigate) after delete modal confirm ([6081db5](https://github.com/slickage/dashboard-ssd/commit/6081db58262447430301402e6e7f92c9b85f78d5))
* **components:** parenthesize else expression to remove keyword ambiguity warning ([a60fd47](https://github.com/slickage/dashboard-ssd/commit/a60fd47cc11f392f0f9327412ff5556611e5b4df))
* **components:** remove Range step warning in CalendarComponents.leading_blanks/1 ([39aeaca](https://github.com/slickage/dashboard-ssd/commit/39aeaca9c311846b3fb9cfbcfe421d5c8fe772a1))
* **fireflies:** avoid exclusive argument conflicts in transcripts query ([f035de9](https://github.com/slickage/dashboard-ssd/commit/f035de9ad338124678c9551fe49cfe39a76ebb33))
* **fireflies:** coerce action_items list to map in changeset ([e266bdd](https://github.com/slickage/dashboard-ssd/commit/e266bdd7e5560402b2035136969d83539a0a76c2))
* **fireflies:** correct GraphQL variable types for transcripts query ([c17ba5a](https://github.com/slickage/dashboard-ssd/commit/c17ba5a92cb490f1c7d24fbde800ff415534421f))
* **fireflies:** ensure rate-limit errors propagate and fix UI test session ([e7abe12](https://github.com/slickage/dashboard-ssd/commit/e7abe121bc9e838e07fb26d1c90aa0838815f364))
* **fireflies:** use DateTime for transcripts fromDate/toDate variables ([a892c0e](https://github.com/slickage/dashboard-ssd/commit/a892c0e4d95c396ce5aefcf8bcbedde39fa2f021))
* **integrations/fireflies:** normalize action_items and add coverage ([8097763](https://github.com/slickage/dashboard-ssd/commit/80977636328782d30a64253702cd25f2ff851a56))
* **integrations/fireflies:** parse epoch timestamps for transcript dates ([4b2d98a](https://github.com/slickage/dashboard-ssd/commit/4b2d98aa9d023f13ee2b7d96b324d55f6e95e2a6))
* **integrations/google-calendar:** handle non-sample mock values gracefully ([3e7564d](https://github.com/slickage/dashboard-ssd/commit/3e7564d784b127de3c9b8a675c1724b097395aca))
* **live:** relax admin checks to accept role maps in tests ([6ca9856](https://github.com/slickage/dashboard-ssd/commit/6ca98564ecde30b0afc425963c9512ad70e6803d))
* **logging:** avoid JSON encoding error by converting opts keyword list to map ([3c3b41e](https://github.com/slickage/dashboard-ssd/commit/3c3b41e06e2870f2566a3464003e145063b7e52d))
* **meetings/agenda:** declare derive_items_for_event/3 default once and define clauses ([5c97ccd](https://github.com/slickage/dashboard-ssd/commit/5c97ccd8e472ee6328517fdd1910b1505de7c4d2))
* **meetings/cache_store:** ensure default TTL on fetch to avoid nil ([b173cb0](https://github.com/slickage/dashboard-ssd/commit/b173cb0134c7981b05fa746c98a3d3961bc0213f))
* **meetings/notes:** silence unused variable warning in fetch_remote_and_persist/2 ([37ffb6c](https://github.com/slickage/dashboard-ssd/commit/37ffb6cfc2ca5c3217fb3c0a35a43960c32f1011))
* **meetings/parsers/fireflies:** require Logger ([53ff5fb](https://github.com/slickage/dashboard-ssd/commit/53ff5fb852f0a4013de9a5c95063ccac20c02879))
* **meetings:** auto-select boolean handling and persist casting ([4b35eb9](https://github.com/slickage/dashboard-ssd/commit/4b35eb92163a0ca2f06982aa3347fc0aff0ee098))
* **meetings:** clicking a date selects it (center of 13-day window) ([239683a](https://github.com/slickage/dashboard-ssd/commit/239683ac506773c86b9395a6daf2cf6dc1dd750b))
* **meetings:** fix dialyzer issues ([315fc7a](https://github.com/slickage/dashboard-ssd/commit/315fc7a35e61419afa17f452cde85a3560d34402))
* **meetings:** fix HEEx component import and group handle_event clauses ([eea6fd0](https://github.com/slickage/dashboard-ssd/commit/eea6fd0a3932c19984c56d9cc67dade158b010bd))
* **meetings:** keep enlarged calendar within card ([86b2aaa](https://github.com/slickage/dashboard-ssd/commit/86b2aaad2016cf8acb13b291a19d609c9868ae59))
* **meetings:** normalize action items ([246287f](https://github.com/slickage/dashboard-ssd/commit/246287f988d127227813f42ba228063e8cb794a7))
* **meetings:** normalize Fireflies action_items when bitstring ([6fc68f2](https://github.com/slickage/dashboard-ssd/commit/6fc68f2597a4f46f5ad60e89fb9074faca5d8e76))
* **migrations:** rename agenda migration to resolve conflict ([990e2d8](https://github.com/slickage/dashboard-ssd/commit/990e2d846be47fab12c71ebeafef018c637caf3c))
* **tests:** skip Fireflies API when mock=1 in Meetings views ([0dee4ae](https://github.com/slickage/dashboard-ssd/commit/0dee4aefef1389bf0175ed30531464d24a937026))


### Features

* **auth,integrations:** persist Google login via refreshable access tokens ([0abb1dc](https://github.com/slickage/dashboard-ssd/commit/0abb1dc6a7962896fddbe1064324ea71c877c2c2))
* **calendar:** increase month/year heading size ([799f966](https://github.com/slickage/dashboard-ssd/commit/799f9663396c533f615db683ab7a64f13705bd97))
* **clients:** open modals via patch; preserve query params ([714230a](https://github.com/slickage/dashboard-ssd/commit/714230a50a114572b0734feb6b653e47e2e1e363))
* **date:** add local offset helpers (human_datetime_local, today?) ([ca9d532](https://github.com/slickage/dashboard-ssd/commit/ca9d532964d743e45c54cde53aa222fdcfa2af8e))
* **fireflies:** add DB persistence and cache-first retrieval ([3930e6f](https://github.com/slickage/dashboard-ssd/commit/3930e6ff9c765c001968589ab72a9a3f9b1679e2))
* **fireflies:** add default FIREFLIES_USER_ID config and prefer it for transcripts ([cdae977](https://github.com/slickage/dashboard-ssd/commit/cdae97772e5a73bf68ff9375a65f62cfbe9dc306))
* **fireflies:** add keyword-based transcript search ([94845de](https://github.com/slickage/dashboard-ssd/commit/94845de8f2cd7899cd83f42ff44cde4bb60d2b4a))
* **fireflies:** add runtime token wiring; remove parser; update plan/docs ([a668487](https://github.com/slickage/dashboard-ssd/commit/a668487e7a3c85694949eaa751b9c1e1dd1b0b5d))
* **fireflies:** add Tesla GraphQL client (bites + summary) ([8e0aab3](https://github.com/slickage/dashboard-ssd/commit/8e0aab311131af4449860e9484e89ef224b2d14e))
* **fireflies:** add transcripts queries to load summaries ([df7c006](https://github.com/slickage/dashboard-ssd/commit/df7c006a97a81bb40300cc808039b2afc6508b10))
* **fireflies:** add users query and user_id filtering for transcripts ([a186c96](https://github.com/slickage/dashboard-ssd/commit/a186c96577000aba3cd110388d41c47c0fab8eaa))
* **fireflies:** implement series-aware fetch with caching ([ee40092](https://github.com/slickage/dashboard-ssd/commit/ee4009247aad2d0921e5f6690c11d86b3a64af29))
* **fireflies:** include bullet_gist in transcript summary ([47d110d](https://github.com/slickage/dashboard-ssd/commit/47d110dd53e4eb69f089aae8e489939e87d17245))
* **fireflies:** rate-limit handling + inline UI messages ([516a56c](https://github.com/slickage/dashboard-ssd/commit/516a56c527f4d5f99ac147f766b01330163ac1ef))
* **google-calendar:** add list_upcoming_for_user/4 with token precedence ([7327087](https://github.com/slickage/dashboard-ssd/commit/7327087f117bda64dd6f1e5c4fd5a7e3087dc101))
* **google-calendar:** implement events.list via Tesla; map to meeting_event ([931e9b8](https://github.com/slickage/dashboard-ssd/commit/931e9b8452b327fe338dacd935980f259fbbf0b7))
* **integrations/fireflies:** add debug logging and parser observability ([b7fe7d3](https://github.com/slickage/dashboard-ssd/commit/b7fe7d3cad605f0e9bb036c32e79322c3a65ee73))
* **integrations/fireflies:** add per-event and batched meeting notes fetching ([61503b4](https://github.com/slickage/dashboard-ssd/commit/61503b48625f2bdada8e09b5f9be8e05f5b277ad))
* **integrations/fireflies:** add refresh_series to invalidate cache and refetch artifacts ([d84f1bb](https://github.com/slickage/dashboard-ssd/commit/d84f1bbd2750a506344cca7a964d83f9d45dcdb0))
* **integrations/google-calendar:** add list_upcoming mock + logging ([23d3ae6](https://github.com/slickage/dashboard-ssd/commit/23d3ae69b21daa85fdaacd6ea078966c1512f84a))
* **integrations:** add calendar_list_upcoming_for_user helper ([3742979](https://github.com/slickage/dashboard-ssd/commit/37429796bc4df0c1a25e92e251807b791661edf6))
* **integrations:** add Google Calendar + Fireflies skeletons and Fireflies summary parser ([3364b4a](https://github.com/slickage/dashboard-ssd/commit/3364b4aa99ff8bc23bb9e6a0c87f4ad4699333bc))
* **logging:** add debug logs for Fireflies GraphQL responses ([2f63f70](https://github.com/slickage/dashboard-ssd/commit/2f63f70ceddf39e9dbc4c1a7e4efb74547383834))
* **logging:** include response data or errors for Fireflies GraphQL ([e8a3ee3](https://github.com/slickage/dashboard-ssd/commit/e8a3ee32cfd9c539a44f5966a26a7becdb649fee))
* **meeting-notes:** add migration, schema and tests for schema ([1e74381](https://github.com/slickage/dashboard-ssd/commit/1e743810f13531b7754e7d2dcd478113d3eac28f))
* **meeting-notes:** implement notes store and test ([719f52f](https://github.com/slickage/dashboard-ssd/commit/719f52ff8c5e66361410430348e624d5cbc7a7c4))
* **meetings,integrations:** cache Google Calendar events and wire Meetings LV ([a3366e1](https://github.com/slickage/dashboard-ssd/commit/a3366e1ddae1753d15d99d1ca32f9000e5037661))
* **meetings/agenda:** derive + merge agenda items with de-dup ([49aa1f1](https://github.com/slickage/dashboard-ssd/commit/49aa1f14e9064fe256aeb791bf51654bc4e18eb9))
* **meetings/detail:** use per-occurrence notes when available ([aa37e04](https://github.com/slickage/dashboard-ssd/commit/aa37e04a6ec5ad3807a8c4fe87e32f6f1f016f86))
* **meetings/notes:** add orchestration for per‑occurrence notes ([d872100](https://github.com/slickage/dashboard-ssd/commit/d872100a5674175dc471dea2517af503d6f4313e))
* **meetings/notes:** implement future_event? ([7f089fb](https://github.com/slickage/dashboard-ssd/commit/7f089fb2cac821e966eb2789034e39759a7d847e))
* **meetings/notes:** skip remote fetch for future events; add tests ([64e1dc4](https://github.com/slickage/dashboard-ssd/commit/64e1dc44440f4fcbbbe094b515e648df5ccdd23c))
* **meetings/ui:** Step 5.1 occurrence-only display; avoid series fallback ([04e77c0](https://github.com/slickage/dashboard-ssd/commit/04e77c03df3a4ab1ebc9a5348b2dd62874030869))
* **meetings:** add agenda preview to meetings list ([a92ccf9](https://github.com/slickage/dashboard-ssd/commit/a92ccf9277f3484e033032706bbfb80291658002))
* **meetings:** add agenda/associations schemas, contexts, and migrations ([d2ea550](https://github.com/slickage/dashboard-ssd/commit/d2ea550a5eb2b072a35a46d77e600650f395ca78))
* **meetings:** add date picker and compact calendar to header ([b2184aa](https://github.com/slickage/dashboard-ssd/commit/b2184aa455d9f72593d22f5717f35fbb5e1be318))
* **meetings:** add left/right arrows to shift calendar months ([1dbf236](https://github.com/slickage/dashboard-ssd/commit/1dbf23689109e1581243a3a466187f1c5e4b360a))
* **meetings:** add manual association UI with persist-for-series; extend associations context ([0052a60](https://github.com/slickage/dashboard-ssd/commit/0052a60755870ece305dc785d41d5e968a64e497))
* **meetings:** add Meetings.CacheStore wrapper (namespace :meetings) ([1fc699d](https://github.com/slickage/dashboard-ssd/commit/1fc699d8b3a976bd13ebc72fcb79b553b5ca592c))
* **meetings:** add rounded box around center month ([258d129](https://github.com/slickage/dashboard-ssd/commit/258d129653d5317aaf774e65a9f30fefd9de07f0))
* **meetings:** annotate suggested option; remove suggestion row ([212a8de](https://github.com/slickage/dashboard-ssd/commit/212a8de04ff4ac2c20b08e3bbc69d70f52de71fa))
* **meetings:** association update/reset flows; default persist=true ([742bc78](https://github.com/slickage/dashboard-ssd/commit/742bc78c77c2574553557aec5af5a2e1a285f670))
* **meetings:** auto-select inferred association; dismissible notice ([d2c99cd](https://github.com/slickage/dashboard-ssd/commit/d2c99cdf532b5b0cf6f0c27d79b7beb1d6050570))
* **meetings:** bold calendar dates that have meetings ([ee9bc61](https://github.com/slickage/dashboard-ssd/commit/ee9bc61243bfa868d0c7db9dbed8f494b82d19ce))
* **meetings:** click day in calendar to jump range start ([f00a712](https://github.com/slickage/dashboard-ssd/commit/f00a712fb9b9feda242e2268317268478366cd2e))
* **meetings:** enlarge calendar strip by 50% ([593c829](https://github.com/slickage/dashboard-ssd/commit/593c8297e8843af64e423b9ec760e50f501a39b0))
* **meetings:** open client edit in modal; preserve query params ([7663154](https://github.com/slickage/dashboard-ssd/commit/76631543e786f290758bff094120db1ca1a0fbe0))
* **meetings:** open detail in modal via patch; preserve query params ([68c92e9](https://github.com/slickage/dashboard-ssd/commit/68c92e996cd4e53e7476973b80fdec69dabe4dcf))
* **meetings:** pass title hint to Fireflies fetch ([b4a203f](https://github.com/slickage/dashboard-ssd/commit/b4a203f40dcf78970ca09222933ae80b4015274b))
* **meetings:** per-occurrence only notes + rate-limit notice ([2befa2b](https://github.com/slickage/dashboard-ssd/commit/2befa2b5938f6e0357ec38f095e21639468c297b))
* **meetings:** render per-occurrence notes in meetings index ([dfb336a](https://github.com/slickage/dashboard-ssd/commit/dfb336af56f82ec94763701dc4d2eb303d3a84af))
* **meetings:** restore calendar prev/next buttons flanking strip ([00ce5e1](https://github.com/slickage/dashboard-ssd/commit/00ce5e1f582023b1bf88c1f099f34e37acf66ea2))
* **meetings:** series association fallback; honor 'persist for series' ([a45474c](https://github.com/slickage/dashboard-ssd/commit/a45474c5c366d52158fa4b4a3deff0b0f038c4fd))
* **meetings:** show client read-only modal in-place; preserve query params ([db5ae06](https://github.com/slickage/dashboard-ssd/commit/db5ae065205c34891a364f868e6a7e278bda4647))
* **meetings:** show previous/current/next months in calendar strip ([32d15ee](https://github.com/slickage/dashboard-ssd/commit/32d15ee704e16ff6d025d23b4f2646ed7976fb17))
* **meetings:** show project read-only modal in-place; preserve query params ([f0ab01a](https://github.com/slickage/dashboard-ssd/commit/f0ab01a5e4d6c47b6c80f4732454e2dc11a41016))
* **meetings:** show times in user-local offset; highlight 'Today' ([6571ea2](https://github.com/slickage/dashboard-ssd/commit/6571ea2dcdc3a4b4041f5f0e75c3f78c929f1dc1))
* **meetings:** single-day events show 'Date · HH:MM – HH:MM' (or 'Today · …') ([91992b3](https://github.com/slickage/dashboard-ssd/commit/91992b3cf1cd589efee59ded7f2ebf633f0d16cf))
* **meetings:** slightly darken past meetings in list ([d34e120](https://github.com/slickage/dashboard-ssd/commit/d34e120c4fc5f5ff2bc14e99cbc7d97d14cc1c0e))
* **meetings:** switch to selected-date +/- 6 days window ([d63b925](https://github.com/slickage/dashboard-ssd/commit/d63b92584167ed320b75a43e6a60ec68dd99627f))
* **meetings:** sync selection with calendar navigation ([d5454db](https://github.com/slickage/dashboard-ssd/commit/d5454db29dde1cb187e9662f04aa477b8a45ff1d))
* **nav:** add Meetings to sidebar with calendar icon and link to /meetings ([59e5f9e](https://github.com/slickage/dashboard-ssd/commit/59e5f9e5a18e17db9bdedd3539043c645d2f3133))
* **scripts:** add Fireflies docs scraper ([3e05c67](https://github.com/slickage/dashboard-ssd/commit/3e05c67dd4f38cdffc6e95feee7cbc7b742de51c))
* **timezone:** render meetings in browser local time ([6faa9e0](https://github.com/slickage/dashboard-ssd/commit/6faa9e01205396c91d350296689d1f82106590b9))
* **ui:** add compact month calendar with range + today highlight ([2997814](https://github.com/slickage/dashboard-ssd/commit/2997814ea9c063ffc635478269eeb25a6b4801a3))
* **web/meetings:** add agenda editing UI (add/edit/delete/reorder) with persistence ([5cbf71f](https://github.com/slickage/dashboard-ssd/commit/5cbf71f1daeda9538eaed01c268f22e7939e9df1))
* **web/meetings:** add agenda previews and merged agenda in LiveViews ([0e2ead1](https://github.com/slickage/dashboard-ssd/commit/0e2ead1a1e1b80e48b5673e69dae9fa359f9cc93))
* **web/meetings:** convert agenda to single text field with save; add replace_manual_text/2 ([3b1027f](https://github.com/slickage/dashboard-ssd/commit/3b1027f0107fad16bc2225c143979aa84024e09e))
* **web/meetings:** simplify agenda to single text field and remove 'What to bring' ([990cdad](https://github.com/slickage/dashboard-ssd/commit/990cdad9b24f2f998fa9c283ccacc5375bf8fd0b))
* **web:** add DateHelpers.human_datetime and use human-readable dates in Meetings index ([31ad343](https://github.com/slickage/dashboard-ssd/commit/31ad3436dea9da17603b6906ed3e04922baf3428))
* **web:** add Meetings index/detail LiveViews and routes ([f642953](https://github.com/slickage/dashboard-ssd/commit/f6429534392911a26186f7c8e94fc8f62780d0c2))

# [1.9.0](https://github.com/slickage/dashboard-ssd/compare/v1.8.0...v1.9.0) (2025-12-01)


### Features

* add client contracts capability and listings ([e0cab45](https://github.com/slickage/dashboard-ssd/commit/e0cab45b0bada75dc31a17bdecd16159a47cc6f9))
* add client contracts liveview and download proxy ([2cec23d](https://github.com/slickage/dashboard-ssd/commit/2cec23da09707a70fad855d47d0574a81774a166))
* add drive/notion sync modules with telemetry ([6c85049](https://github.com/slickage/dashboard-ssd/commit/6c85049e597a07f213934b39ad47fc083df5508d))
* add Notion renderer and client contracts tests ([80e7ea3](https://github.com/slickage/dashboard-ssd/commit/80e7ea35ac7cec95b1386b0f4d9ec9ce524ff997))
* add shared documents migrations and schemas ([792a40d](https://github.com/slickage/dashboard-ssd/commit/792a40d810eeb68c07fe5414b9cd1e92ee465c88))
* add staff contracts console and ACL toggles ([005d58a](https://github.com/slickage/dashboard-ssd/commit/005d58ab890eebe611546a76fbf03fdbc49accfe))
* add workspace bootstrap controls ([cd949d4](https://github.com/slickage/dashboard-ssd/commit/cd949d4a9ece327e61fb089cf40a00a7dc6d6874))
* add workspace bootstrap templates and helpers ([96ba158](https://github.com/slickage/dashboard-ssd/commit/96ba15890e7c889fd97f65336042c2b846f09efe))
* **contracts:** improve regeneration ux and templates ([429cc54](https://github.com/slickage/dashboard-ssd/commit/429cc543cc88f5af5a897c305d81d0831b9722a7))
* **drive:** improve bootstrap content and sync pruning ([30c2049](https://github.com/slickage/dashboard-ssd/commit/30c204998537ce1c98891b30aa2386062191d125))
* expand Drive helpers for shared documents ([8b069e7](https://github.com/slickage/dashboard-ssd/commit/8b069e779a34eb1865c08af1eb1130717634b301))
* handle oversized downloads and add tests ([67a583a](https://github.com/slickage/dashboard-ssd/commit/67a583aa47486b84bd634a0490eeae4d5bf61ae2))
* instrument contracts telemetry and docs ([a31fa5e](https://github.com/slickage/dashboard-ssd/commit/a31fa5e511a70cbcace9f5597b8da71af91e817a))
* introduce shared documents cache helper ([d8b9c79](https://github.com/slickage/dashboard-ssd/commit/d8b9c7900250b2bd972a68c6c74f55681a435114))
* store Drive folder metadata on projects ([81f81bd](https://github.com/slickage/dashboard-ssd/commit/81f81bd1aa7d5f923849a8aaa109b4c9d854d078))
* wire drive ACL automation to client assignments ([14dd839](https://github.com/slickage/dashboard-ssd/commit/14dd8392a684fa64a76eb4147cc0fa2df0919d69))

# [1.8.0](https://github.com/slickage/dashboard-ssd/compare/v1.7.1...v1.8.0) (2025-11-07)


### Bug Fixes

* satisfy invite docs requirements ([e42488e](https://github.com/slickage/dashboard-ssd/commit/e42488e21b562bff1f071cf7e4b93e0ec7c6e083))
* **tests:** stabilize health scheduler teardown ([54c9890](https://github.com/slickage/dashboard-ssd/commit/54c98900620bb21431e6986429c6f4feb5f438a2))


### Features

* **clients:** scope client list to assigned users ([c121dd1](https://github.com/slickage/dashboard-ssd/commit/c121dd1910aca6bf7c9760c7520b3eed599d2b3c))
* **rbac:** simplify roles and add invite management ([56116e3](https://github.com/slickage/dashboard-ssd/commit/56116e316f9a8506245783e0aa0fdd3940b1dfe7))
* **settings:** refine RBAC UI and enforce project edit gating ([a8fb862](https://github.com/slickage/dashboard-ssd/commit/a8fb8626a7256205402838f73becafa1aa504bbd))

## [1.7.1](https://github.com/slickage/dashboard-ssd/compare/v1.7.0...v1.7.1) (2025-11-01)


### Bug Fixes

* **cd:** bump version ([66b8285](https://github.com/slickage/dashboard-ssd/commit/66b8285fe71b7e9bc4c8c39cb5a510fa87769802))

# [1.7.0](https://github.com/slickage/dashboard-ssd/compare/v1.6.0...v1.7.0) (2025-11-01)


### Bug Fixes

* **projects:** guard sandbox access in health check scheduler ([2be0b05](https://github.com/slickage/dashboard-ssd/commit/2be0b059e3b692d19e1794a83dfd834d0abf4494))
* resolve database connection errors in health checks scheduler and improve cache warmer test coverage ([2d4652b](https://github.com/slickage/dashboard-ssd/commit/2d4652bac4197447d8fd401f669cb02d39668941))


### Features

* **cache:** introduce shared cache warmer ([515e7c4](https://github.com/slickage/dashboard-ssd/commit/515e7c4ff1507c48e6730c3e323111c33b8f88da))
* **kb:** reuse cached document detail on initial load ([73051ec](https://github.com/slickage/dashboard-ssd/commit/73051eca4d47bc84a6eb326258106908ac5f29f0))

# [1.6.0](https://github.com/slickage/dashboard-ssd/compare/v1.5.0...v1.6.0) (2025-11-01)


### Bug Fixes

* **kb:** cache link to page metadata ([af59c69](https://github.com/slickage/dashboard-ssd/commit/af59c69046ec6c120c82ff7e8e0823b7b7c33175))


### Features

* **kb:** render link-to-page blocks with metadata ([3d045f3](https://github.com/slickage/dashboard-ssd/commit/3d045f361a6789e33e7d1b450daf0994da750e25))


### Performance Improvements

* **kb:** streamline pagination accumulation ([f89cffd](https://github.com/slickage/dashboard-ssd/commit/f89cffdc0937342b6cff5b80475ab0b4c0c260aa))

# [1.5.0](https://github.com/slickage/dashboard-ssd/compare/v1.4.10...v1.5.0) (2025-11-01)


### Bug Fixes

* **projects:** improve team header contrast in light theme ([33cc4e9](https://github.com/slickage/dashboard-ssd/commit/33cc4e9f34ba97e53cdf99510df4694034335bf0))
* **ui:** darken total chip outline in light theme ([079136b](https://github.com/slickage/dashboard-ssd/commit/079136b8600bde4c585a9d8b82214394c0ebb208))


### Features

* **linear:** expose assigned issue counts ([6240614](https://github.com/slickage/dashboard-ssd/commit/6240614549901fda3908614376ff40c80085cba3))
* **linear:** sync all teams with workflow state metadata ([46f4765](https://github.com/slickage/dashboard-ssd/commit/46f476564ded0513b8fa245f42e741c70b77a64c))
* **projects:** cache Linear sync results and reuse summaries ([8cf4e11](https://github.com/slickage/dashboard-ssd/commit/8cf4e117aa48c3a18931a722f2ac2fbb2c6f2f0b))
* **projects:** display assigned task owners ([02d954e](https://github.com/slickage/dashboard-ssd/commit/02d954ee9df11ebd878a243f8fdb5417f179780a))
* **projects:** persist linear team members and live data ([22e565b](https://github.com/slickage/dashboard-ssd/commit/22e565b54a02efb216624aa77fe9576c33aa5c02))
* **ui:** surface todo totals in project summary pill ([b94677d](https://github.com/slickage/dashboard-ssd/commit/b94677d98b2d8c0210a0d186c9d8e82f55999dab))


### Performance Improvements

* **kb:** leverage cached documents and refresh async ([542106b](https://github.com/slickage/dashboard-ssd/commit/542106b2aa873a3e33b2f79e043c6973ef02ee74))

## [1.4.10](https://github.com/slickage/dashboard-ssd/compare/v1.4.9...v1.4.10) (2025-10-30)


### Bug Fixes

* **ci:** bump version ([e2ee4c5](https://github.com/slickage/dashboard-ssd/commit/e2ee4c5b4a524827988b209a305a582c2516157f))

## [1.4.9](https://github.com/slickage/dashboard-ssd/compare/v1.4.8...v1.4.9) (2025-10-30)


### Bug Fixes

* **github:** add release in needs, where needed ([43b64a4](https://github.com/slickage/dashboard-ssd/commit/43b64a4cc69336de06e91c4290b46710a953c823))

## [1.4.8](https://github.com/slickage/dashboard-ssd/compare/v1.4.7...v1.4.8) (2025-10-30)


### Bug Fixes

* **ci:** bump version ([2e3e5a6](https://github.com/slickage/dashboard-ssd/commit/2e3e5a623a615993e7a9e62437a41918d271fd5b))

## [1.4.7](https://github.com/slickage/dashboard-ssd/compare/v1.4.6...v1.4.7) (2025-10-30)


### Bug Fixes

* **ci:** bump version ([6272486](https://github.com/slickage/dashboard-ssd/commit/627248641c629194d4788ec7e3cb259a497c9572))

## [1.4.6](https://github.com/slickage/dashboard-ssd/compare/v1.4.5...v1.4.6) (2025-10-22)


### Bug Fixes

* **ci:** skip https check in sobelow ([ef89f40](https://github.com/slickage/dashboard-ssd/commit/ef89f40bcb3be6c30d2c13b8fa349e81a1a8cc41))
* **config/prod:** don't force ssl ([eb5c5ed](https://github.com/slickage/dashboard-ssd/commit/eb5c5ed7d98253a6e4340b3c2962b318c9559903))

## [1.4.5](https://github.com/slickage/dashboard-ssd/compare/v1.4.4...v1.4.5) (2025-10-22)


### Bug Fixes

* **config/runtime:** move ssl_opts (deprecated) -> ssl ([6225716](https://github.com/slickage/dashboard-ssd/commit/6225716cc6d93d16f8b1403302005980f3c9246c))

## [1.4.4](https://github.com/slickage/dashboard-ssd/compare/v1.4.3...v1.4.4) (2025-10-22)


### Bug Fixes

* **dockerfile:** add new dockerfile ([2e13f27](https://github.com/slickage/dashboard-ssd/commit/2e13f27dbe2ae13c3472f42711267454c17e8836))

## [1.4.3](https://github.com/slickage/dashboard-ssd/compare/v1.4.2...v1.4.3) (2025-10-22)


### Bug Fixes

* **ci:** add cacerts and convert from PEM to DER ([467cbb1](https://github.com/slickage/dashboard-ssd/commit/467cbb11fd32f79b2eeb12de858d0fad5e714fe4))
* **ci:** bump version ([65f1fca](https://github.com/slickage/dashboard-ssd/commit/65f1fca80fe9f718e8c651e72fa69b30e4b96a4c))

## [1.4.2](https://github.com/slickage/dashboard-ssd/compare/v1.4.1...v1.4.2) (2025-10-21)


### Bug Fixes

* **ci:** grant id-token for deploy-pages job ([859b5ec](https://github.com/slickage/dashboard-ssd/commit/859b5ec9bedf6ee8df86bcf39407bd4672129faa))

### Features

* persist Linear team & project identifiers during sync to include every team
* capture Linear workflow state metadata for richer project task summaries

## [1.4.1](https://github.com/slickage/dashboard-ssd/compare/v1.4.0...v1.4.1) (2025-10-21)


### Bug Fixes

* **docker:** align runtime base with otp 27 glibc requirements ([97b7de5](https://github.com/slickage/dashboard-ssd/commit/97b7de5354ae9459dcc7d1d672ca62bbb2262cd9))

# [1.4.0](https://github.com/slickage/dashboard-ssd/compare/v1.3.1...v1.4.0) (2025-10-20)


### Bug Fixes

* add conditional Phoenix.CodeReloader listener configuration ([e6f64a8](https://github.com/slickage/dashboard-ssd/commit/e6f64a8c8ef94aabae6e55946c028159fa3c6ea9))
* add NOTION_AUTO_DISCOVER env var parsing ([cb9c3c8](https://github.com/slickage/dashboard-ssd/commit/cb9c3c8a596519dfcf62ac9ac64faadad71a62c1))
* add Phoenix.CodeReloader listener programmatically after app start ([ccbb884](https://github.com/slickage/dashboard-ssd/commit/ccbb884c240da5a63dc0b39b09bd61d13439b670))
* add Phoenix.CodeReloader to mix listeners ([ecef434](https://github.com/slickage/dashboard-ssd/commit/ecef43409cb29dc2bda739ea18bc3932c3f6bd7f))
* add Phoenix.CodeReloader to Mix listeners for Phoenix 1.8 ([426bbd1](https://github.com/slickage/dashboard-ssd/commit/426bbd165fe1fa5646b07b7a4937ba40d677054a))
* add support for bookmark block type in knowledge base renderer ([8bf25c1](https://github.com/slickage/dashboard-ssd/commit/8bf25c1b9af4dc722e509eba78c575cddfad1177))
* allow external SVG icons in CSP by adding frame-src https: ([9ed7771](https://github.com/slickage/dashboard-ssd/commit/9ed77711513058acc51c12aa48cca7d376c18d85))
* allow localhost frames in CSP for live reload ([6bd9d41](https://github.com/slickage/dashboard-ssd/commit/6bd9d41e6d9aa6e6196e22d1c7615dfcf54c2fb2))
* **build:** guard mix listeners without code reloader ([e29f069](https://github.com/slickage/dashboard-ssd/commit/e29f069d7303fd1dab7abd6f18014b9e6274986c))
* include document icons in activity tracking ([a1c68c0](https://github.com/slickage/dashboard-ssd/commit/a1c68c06bde0ed3f12034fce4867979dc7eef511))
* **kb:** clear search on escape and cover cached loads ([8b41686](https://github.com/slickage/dashboard-ssd/commit/8b416867e43ce7780488d5cc79243f704bc9ed3a))
* **kb:** ensure consistent collection_id for auto-discovered pages ([82962de](https://github.com/slickage/dashboard-ssd/commit/82962de17c74b5dc74a3a9fe8ea360bfd23c874d))
* **kb:** fix link underline extending due to whitespace ([51ce7bb](https://github.com/slickage/dashboard-ssd/commit/51ce7bbec6da8191e133837d0a909d76cdea0019))
* **kb:** fix recently viewed list shrinking on item clicks ([a5b8d82](https://github.com/slickage/dashboard-ssd/commit/a5b8d828c92c71089e67971e750d9b402db76daa))
* **kb:** force fresh document loading to ensure updated icons persist ([9c8801f](https://github.com/slickage/dashboard-ssd/commit/9c8801f96a05c6b1f2e52e0a89bc8f78266006f2))
* **kb:** harden live search and document loading ([0baab29](https://github.com/slickage/dashboard-ssd/commit/0baab2943a5a8ffbb0b9a7d6d576d3c1bd218501))
* **kb:** invalidate collection cache when document updates ([2041900](https://github.com/slickage/dashboard-ssd/commit/204190055990f4ccc4c902fe25052809ce31cba0))
* **kb:** keep collections header minimal ([a68496c](https://github.com/slickage/dashboard-ssd/commit/a68496c52ba6673e9e0b9f137f3dd3efaf91b04a))
* **kb:** maintain recent documents list integrity ([6a66444](https://github.com/slickage/dashboard-ssd/commit/6a66444632b2cd60b0b5c9d2c469680a109f93d0))
* **kb:** resolve background document update issues in knowledge base ([24ede40](https://github.com/slickage/dashboard-ssd/commit/24ede408b6891e5a2519b7d46f55e1e84e9a8b6b))
* **kb:** resolve syntax error in background document update handling ([fef9ac8](https://github.com/slickage/dashboard-ssd/commit/fef9ac813337cdc8403b2d7b6e97cde7c0a5e1a2))
* **kb:** standardize missing-env warnings as theme badge and remove wrapper ([249c0fa](https://github.com/slickage/dashboard-ssd/commit/249c0fa3061abcc834167520f1cef39f1a46ed18)), closes [#92400](https://github.com/slickage/dashboard-ssd/issues/92400)
* **kb:** update collection documents cache with fresh icons ([8959c25](https://github.com/slickage/dashboard-ssd/commit/8959c25553d20662e22e94752e56559070c54be8))
* **kb:** update document icon in collection tree during background refresh ([60c01e5](https://github.com/slickage/dashboard-ssd/commit/60c01e5d17a8d3b4f3c11c3e7ad49bf7bf2c0d2b))
* **kb:** update document icons in recently viewed section ([8272e25](https://github.com/slickage/dashboard-ssd/commit/8272e254288447ed20cfe6b8bcbdf8ce5dfa1c0f))
* prevent sticky header from covering search on KB page ([9b7982b](https://github.com/slickage/dashboard-ssd/commit/9b7982b6604e819480f00786c75405b8e19eaf9b))
* remove duplicate X icon in knowledge base search input ([9682196](https://github.com/slickage/dashboard-ssd/commit/9682196ea9f66fb34c87be0263d907da0f45c35b))
* remove invalid Phoenix.CodeReloader from mix listeners ([0bb7279](https://github.com/slickage/dashboard-ssd/commit/0bb72794fcb355660fac3e819fbfbb7fb86e48f7))
* remove Phoenix.CodeReloader listener configuration ([2b5fcfd](https://github.com/slickage/dashboard-ssd/commit/2b5fcfd3cf5f721685537f7c2095e3497bd8e418))
* remove unused variable assignments in theme layout ([cd389b7](https://github.com/slickage/dashboard-ssd/commit/cd389b7cb0d0642ffad75b805eb66904134e695a))
* reorder aliases to satisfy credo readability checks ([64f2dee](https://github.com/slickage/dashboard-ssd/commit/64f2deed79e888d7f3a14a99095cd49bc8dc1836))
* **theme:** stabilize shell gradient scaling ([d75472e](https://github.com/slickage/dashboard-ssd/commit/d75472e57714afa671cdbd03c8709f76d116ad85))
* update CSP to allow external images and objects ([f0909f7](https://github.com/slickage/dashboard-ssd/commit/f0909f73a021e7d9c186c2d36bfb6dcbc642c9e0))
* update docs paths after moving integration files to root ([39ec1ae](https://github.com/slickage/dashboard-ssd/commit/39ec1ae75b8d0a3f7805e638b1eddf81958a94d4))
* update test assertion to check index page after health check disable ([30fe155](https://github.com/slickage/dashboard-ssd/commit/30fe155af3ea09da8473a0feebb440bed392461f))
* use function call for github releases url in navigation ([1b80466](https://github.com/slickage/dashboard-ssd/commit/1b8046665ce450e6a3325815441082588a6a48b3))
* use manual child spec for Phoenix.CodeReloader listener ([0b68981](https://github.com/slickage/dashboard-ssd/commit/0b689810954fed290c58aa0428bf684b9c36d68f))
* use object tag for SVG icons to handle CORS issues ([84359a9](https://github.com/slickage/dashboard-ssd/commit/84359a954ecdc2bdcc2aa4b556674287ec1fb425))


### Features

* add conditional Phoenix.CodeReloader listener configuration ([841ff34](https://github.com/slickage/dashboard-ssd/commit/841ff341148d5f02f6cd1ac71d719f8847eabe50))
* add Makeup syntax highlighting styles for code blocks ([673732c](https://github.com/slickage/dashboard-ssd/commit/673732cc80f9ecbba9a14b89b669fe63c9af8bd1))
* display Notion document icons in UI ([5d8d740](https://github.com/slickage/dashboard-ssd/commit/5d8d74052e84e0d3b1e5bca8afff74ab2c280b06))
* enable Makeup syntax highlighting for code blocks ([d64a9f5](https://github.com/slickage/dashboard-ssd/commit/d64a9f55f22af486ffd4c27adcc810a91dea7077))
* enhance knowledge base with URL sharing and improved UX ([8627df1](https://github.com/slickage/dashboard-ssd/commit/8627df1595ecab445605240c287b80db6a9a2d15))
* enhance notion search with options support ([940954b](https://github.com/slickage/dashboard-ssd/commit/940954b04defcefa266b9bdbdf084a63a28bb148))
* extract syntax highlighting CSS and adjust mobile layout ([0873bab](https://github.com/slickage/dashboard-ssd/commit/0873babe989294ea71a5ba2e1c240eaebc37dcb7))
* improve accessibility in kb_components ([488f7e8](https://github.com/slickage/dashboard-ssd/commit/488f7e835c5e4e032d9ecf05f9871bd71940406c))
* **kb:** add cached document loading and fix list indentation ([f264fb2](https://github.com/slickage/dashboard-ssd/commit/f264fb2ee19ab2a599afd4468aafb43771621be0))
* **kb:** add collection and document list components ([b95eca2](https://github.com/slickage/dashboard-ssd/commit/b95eca2f7fd40e2a7fec7aa1fd300e7b1237846c))
* **kb:** allow type filter exemptions for notion databases ([cc88d28](https://github.com/slickage/dashboard-ssd/commit/cc88d288ab4eed85711305b67286740d9ae76805))
* **kb:** hide empty collections on load ([bd200dd](https://github.com/slickage/dashboard-ssd/commit/bd200dd3a7a6a2f497d40f83abb6a012764331dd))
* **kb:** show reader loading indicator ([0e590d6](https://github.com/slickage/dashboard-ssd/commit/0e590d6e592296bcbb97f58adbc4514475cae6ec))
* **knowledge-base:** enhance notion page discovery ([d32aac5](https://github.com/slickage/dashboard-ssd/commit/d32aac56d11bb1c38ba28fcfcfcc94812e61db64))
* make desktop sidebar version badge clickable ([5a17cab](https://github.com/slickage/dashboard-ssd/commit/5a17cab831800f919645e1de6affbf890f5fb31d))
* make version badge in sidebar clickable ([71e1345](https://github.com/slickage/dashboard-ssd/commit/71e13455e7bc718631356e0ddcc71ee20fee1ae8))
* refresh documents list in collections tree when document is updated ([508da75](https://github.com/slickage/dashboard-ssd/commit/508da75c0951972fbaec410cbc8759b6eb72ffbe))
* scaffold knowledge base foundations ([36efb21](https://github.com/slickage/dashboard-ssd/commit/36efb215c4bd8eef7ae1657808040494aec9d917))
* update documents cache when fetching document details ([06b866f](https://github.com/slickage/dashboard-ssd/commit/06b866f8d896e6634eeaa270abe7dcf91ed0a734))
* upgrade gettext to 1.0.0 ([3d1c097](https://github.com/slickage/dashboard-ssd/commit/3d1c097d8ce51044fdb3aea01291797e602c7165))
* upgrade makeup_elixir to 1.0.1 ([a3adffb](https://github.com/slickage/dashboard-ssd/commit/a3adffbc02fd10e9298c48d9fef328b3b9e60843))
* upgrade makeup_erlang to 1.0.2 ([3faf051](https://github.com/slickage/dashboard-ssd/commit/3faf051bdb65c97e0f5e4a2c010ff528bea2b633))
* upgrade Phoenix LiveView to 1.1.14 ([56f3a89](https://github.com/slickage/dashboard-ssd/commit/56f3a8951ab509935691bd0e92bf8ff978594741))
* upgrade Phoenix to 1.8.1 ([69495ea](https://github.com/slickage/dashboard-ssd/commit/69495ea1e4edfded33c4621677bb7f99abed0789))
* **web:** add monokai syntax highlighting to kb ([63aecf2](https://github.com/slickage/dashboard-ssd/commit/63aecf2b72a85c8bb4f0c332da9bc2a82b6c9ce7))


### Reverts

* keep mix_audit dependency ([3f2d078](https://github.com/slickage/dashboard-ssd/commit/3f2d0786c9bb87b1a3a495a79b4049e83155dd7f))

## [1.3.1](https://github.com/slickage/dashboard-ssd/compare/v1.3.0...v1.3.1) (2025-10-10)


### Bug Fixes

* correct Docker image tag for Elixir 1.18.0 and Erlang 27.1 ([e97e14a](https://github.com/slickage/dashboard-ssd/commit/e97e14a0017851cdc906b77f8dee43a8d56953aa))

# [1.3.0](https://github.com/slickage/dashboard-ssd/compare/v1.2.1...v1.3.0) (2025-10-10)


### Features

* update Docker image to match .tool-versions ([c6cbf15](https://github.com/slickage/dashboard-ssd/commit/c6cbf15f0026db09586bebfd84f06ac7178b15cd))

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
## Unreleased

### Features

* Simplified RBAC capability management with admin UI, API, and persistent role-capability storage.
* Added Google domain allowlist enforcement and local role switch mix task for testing.
