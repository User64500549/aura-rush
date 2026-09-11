# Economy, LiveOps and Social hardening

This document records the production contracts introduced by the P0/P1 hardening pass. They are deliberately server-authoritative and keep paid commerce disabled until real catalog IDs are configured.

## Qualified participation

- A normal runner qualifies after at least one server-validated action: a collected thread, rhythm hit, prism step/attempt/completion, or explicit Style Ready action.
- A Backstage Apprentice always qualifies. This preserves late-join and accessibility support even when too little playable time remains to perform an action.
- The reward transaction writes `qualified_round:<roundId>` into the system grant ledger. Round rewards, quest progress, Community Bloom, and Atelier contribution use that same marker, so an idle player cannot progress one subsystem through another.
- An unqualified round remains idempotently recorded with a zero reward. It does not increment completion stats, progression, quests, Community Bloom, or Atelier totals.

## Quests and retention

- Current and banked daily quests share one action budget. Current dailies consume it first; only unused actions flow into banked days. Weekly quests may still progress in parallel.
- `streak.count` represents the current momentum segment. Missing too many days resets that segment, but never removes rewards or `streak.lifetimeDays`.
- A grace credit can bridge one missed day. Multiple daily sets completed on one calendar day cannot multiply the streak.

## LiveOps

- Every milestone declares `scope = "personal"` or `scope = "global"`. Personal claims use the player's stored contribution; only global claims receive the community aggregate override.
- The manifest validates its version against `Config.LiveOps.ManifestVersion`, validates the minimum client version, and checks event IDs, time windows, contribution limits, milestone scopes, targets, and rewards.
- A rejected manifest fails Community Bloom closed and exposes `manifestReason` in its server view for diagnostics.

## Atelier and postcard privacy

- Atelier weekly totals are shared through `AuraRush_AtelierWeeks_v1`, keyed by week and founder. Per-player contribution and aggregate total are stored separately.
- A qualified round has an idempotency receipt. A bounded receipt map prevents immediate replay while keeping the record below DataStore size limits.
- Only Founders and Moderators may invite. Invitations expire, have a per-pair cooldown, and cannot replace an existing pending invitation. The server accepts `decline` and `block_inviter`; blocking is session-scoped.
- Accepting an invitation revalidates the inviter's current Atelier and role. A stale or forged invite cannot join a player.
- A postcard stores only its creator's user ID plus an aggregate participant count. Public recent-postcard views omit participant IDs and the internal round ID.

## Paid receipt durability

Production receipt processing uses the following order:

1. Check the profile ledger and the durable `AuraRush_PaidReceipts_v1` archive.
2. Apply the deterministic product grant in one profile mutation.
3. Save the profile before acknowledging the purchase.
4. Archive the receipt by purchase ID.
5. Remove the profile copy only after the archive is durable.

Archive outages fail safely or retain the profile receipt; they never silently trim an unarchived receipt. Receipt/user conflicts fail closed for investigation. Studio and unpublished places retain the legacy profile-only path.

`ProductCatalog.RetiredDeveloperProducts` is the tombstone registry. A sold product ID must never become unknown: move its exact deterministic grant from the active catalog into this registry. Active and retired IDs are checked for duplicates. All configured product IDs remain zero, so commerce stays safely off.

## Launch gates and remaining work

- Configure real developer-product/subscription IDs only after receipt replay, DataStore outage, refund/support, and analytics QA in a published test universe.
- Add visible Decline and Block Inviter controls to the client Atelier panel; the server actions already exist, but the client panel is outside this hardening patch's ownership boundary.
- Glowstorm reduced-motion/reduced-flash presentation belongs to client VFX and World/Celebration code outside this patch. Keep any affected rollout flag off until that path is independently accessibility-tested.
- Monitor `round_unqualified`, receipt archive warnings/conflicts, invite declines/blocks, and shared Atelier write failures during staged rollout.
