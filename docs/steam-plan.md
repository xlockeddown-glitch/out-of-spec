# Steam plan for co-op

Steps 1 to 3 are done (2026-11-24): `CoopSession` runs over any `MultiplayerPeer`, tests prove it with a fake one, and "steam" is refused as "Steam unavailable." There is no Steam code; step 4 on waits for Ryan. "Where the transport is made today", its line numbers and "Smallest seam" describe the code before step 1. Written 2026-11-24 for Godot 4.7.2. Ryan chose "Direct IP first" (friends join by IP, Steam later) (decisions.md, "Co-op, first slice"). This is the later.

## Where the transport is made today

All in `scripts/autoload/CoopSession.gd`; no other file creates a peer (tests make raw ENet strangers: `tests/coop_net.gd:55`).

- Host: `ENetMultiplayerPeer.new()` and `create_server()` at lines 113-115, `peer_connected` / `peer_disconnected` hooked at 117-118, then `_open(peer)`.
- Guest: `create_client(address, port)` at 138-139, then `_open(peer)`.
- `_peer` is typed `ENetMultiplayerPeer` (line 67) and `_open` takes one (line 469). `port()` (174) reads `_peer.host`, which is ENet only.
- Everything else already uses the `MultiplayerPeer` interface: `poll`, `get_packet`, `get_available_packet_count`, `get_packet_peer`, `get_packet_mode`, `put_packet`, `set_target_peer`, `transfer_mode`, `get_connection_status`, `disconnect_peer`, `close` (lines 237-267, 347, 367-372, 478, 496-500).
- UI: `title_menu.gd:158` calls `join(text)`; `coop_ui.gd:132` calls `host()`. `join` accepts only an IP (lines 134-135).

## Smallest seam

1. Retype `_peer` and `_open` to `MultiplayerPeer`.
2. Move the two creation blocks into small functions that return a configured peer or an error string (`_make_host_peer`, `_make_guest_peer`). The ENet versions are today's code, moved.
3. `port()` and the host text get what they need from the transport, not from `_peer.host`.
4. A `transport` argument ("enet" default; "steam" only if the extension is present) on host/join. No new autoload.

No high-level RPC: `tests/test_coop_session.gd:310` forbids it on purpose.

## What stays the same

- Host authority: the host runs the farm; guests send commands through `FarmCommands`.
- HELLO / `PROTOCOL` check (`PROTOCOL = 11`, line 28) and the REFUSED reasons.
- `is_plain` and `_end_of` checks on every packet (lines 209, 503-508, 514 on). They work on bytes, so transport does not matter.
- Rate limits, `MAX_GUEST_BYTES` (2048), `MAX_HOST_BYTES` (4 MiB), join timeout, `SPARE_CONNECTIONS`.
- Guests talk to peer id 1 (line 379). A Steam peer must keep host = 1.

## What the research found

Accessed 2026-11-24. Pages were read through a summarizing fetch tool, so exact wording is not verified.

- GodotSteam moved to Codeberg; its GitHub repo was reported archived (Nov 2026). https://github.com/GodotSteam/GodotSteam
- Codeberg page: MIT license; builds as a custom engine module or as a GDExtension; compatibility notes mention Godot 4.7; "Current Build" is 4.24. https://codeberg.org/godotsteam/godotsteam
- The separate MultiplayerPeer repo is retired and merged into the main 4.x branch (MIT; last build 4.16.2, "opt-in to server_relay"). The main repo contains `godotsteam_multiplayer_peer.cpp/.h`. https://codeberg.org/godotsteam/multiplayerpeer ; GitHub copy archived 2025-11-13: https://github.com/GodotSteam/MultiplayerPeer
- Community `expressobits/steam-multiplayer-peer`: reportedly no channels, development paused, author recommends GodotSteam. Not recommended. https://github.com/expressobits/steam-multiplayer-peer
- Steamworks.NET: not applicable (GDScript project).
- Steam Direct: $100 USD per new app, paid by an Admin of a Steamworks partner account, non-refundable but recoupable after $1,000 adjusted gross revenue; onboarding lists a 30-day wait between paying and release. https://partner.steamgames.com/doc/gettingstarted/appfee ; https://partner.steamgames.com/doc/gettingstarted/onboarding
- App ID 480 (Spacewar): the SDK example game; outside Steam it needs `steam_appid.txt` containing 480, and Steam must be running. https://partner.steamgames.com/doc/sdk/api/example
- Steam networking: newer APIs relay through Valve's network by default and also allow plain UDP; messages may exceed one packet. https://partner.steamgames.com/doc/features/multiplayer/networking

## Could not verify

- Which GodotSteam release supports Godot 4.7.2, and whether a prebuilt 4.7 GDExtension exists. Notes only mention 4.7; search results gave conflicting version numbers. Read Codeberg releases and godotsteam.com when starting.
- Whether the bundled MultiplayerPeer supports channels, transfer modes, `disconnect_peer` and `get_packet_mode` as ENet does.
- That relay needs no port forwarding. The Valve page says relay is the default but I did not see it say this.
- Numeric message size limits; how reliable/unreliable behave on the Steam peer.
- Any rules or limits for sharing App ID 480 (no source found), or whether friends can join a 480 test lobby.
- Lobby details (invites, size limit).
- Steamworks SDK redistribution terms (the SDK is not MIT).

## Risks

- Peer ids: ENet gives the host id 1 and guests random positive ids. The Steam peer must match, or line 379 and the `_links` keys break. Check how Steam IDs map to ints and whether ids can collide.
- Disconnect detection: today `peer_disconnected` plus `_links[id].gone` (244-247) and the status check (372). The Steam peer must raise the same on friend quit, crash or relay loss. Test each.
- Message size and channels: `STATE` can reach 4 MiB; Steam may cap or fragment, and may not offer our unreliable-ordered `DRIVE` poses (`_put`, line 499). Fallback: send poses reliable on Steam.
- `get_packet_mode` (line 266) is used to refuse an unreliable HELLO; the Steam peer must report the true mode.
- Version pin: Godot, GodotSteam build and Steamworks SDK must match; an update can break compatibility. Pin all three.
- The overlay may fail from the editor; test exports. Steam must be running. A missing extension must leave ENet working.
- Binaries in the repo (the extension and Steam DLL) change today's habits; needs Ryan's yes.
- A Steam host and an ENet guest cannot meet; if both stay, each game uses one transport.
- `PROTOCOL` stays the same unless messages change.

## Testing without a store page

- Existing tests keep covering ENet; PR 1 must pass them unchanged.
- A small scripted fake `MultiplayerPeer` in `tests/` proves `CoopSession` works with any peer: join, refusal, drop, size limit.
- Real Steam: App ID 480 with `steam_appid.txt` beside the exported exe, on two PCs with two Steam accounts (one account cannot run two clients). No store page, no fee.
- Real runs are manual and need Ryan or a friend; CI cannot run Steam.

## Ordered PRs, one job each

1. (Done) Seam: retype `_peer`/`_open` to `MultiplayerPeer`, move creation into two functions, `port()` off `_peer.host`. No behavior change.
2. (Done) Fake-peer test: run session tests through an in-memory peer.
3. (Done) Transport argument and a "Steam unavailable" refusal; ENet stays default. No Steam code.
4. Spike (after Ryan approves the add-on): vendor the pinned GodotSteam GDExtension, init with App ID 480, a scene where two PCs exchange a packet. Not wired to co-op.
5. Steam peer in `CoopSession`: host makes a lobby, guest joins by lobby id; same session code.
6. Lobby UI in `title_menu.gd` and `coop_ui.gd`: "Host on Steam" / "Join friend"; the IP box stays if Ryan wants Steam beside direct IP.
7. Hardening from the manual run: disconnects, sizes, reliable-only poses.
8. Packaging: export presets, `steam_appid.txt` handling, tester notes.
9. Real App ID and store page (after Ryan has the account).

## Needs Ryan

- Yes/no to adding GodotSteam (MIT) and the Steamworks SDK, and where binaries live.
- A Steam account to test with, and a second PC or friend for the two-machine test.
- A Steamworks partner account (identity and tax details), the $100 fee paid by him, and the 30-day wait.
- Whether Steam replaces or sits beside direct IP, and whether to add achievements or cloud saves later.
- Whether the game name and store page plan are settled.
- OK to test on App ID 480.
