# Analytics events (Firebase Analytics / GA4 → BigQuery)

All product analytics go through **one service**:
[`lib/core/analytics/analytics_service.dart`](../lib/core/analytics/analytics_service.dart)
(`AnalyticsService.instance`, Riverpod: `analyticsProvider`). Screens never call
`FirebaseAnalytics` directly.

* Package: `firebase_analytics: ^11.6.0` (the last line compatible with
  `firebase_core` 3.x; 12.x requires `firebase_core` 4.x).
* No-op when Firebase is disabled (`--dart-define=USE_FIREBASE=false`) or failed
  to initialize, and in unit/widget tests (`init()` is only called from `main.dart`).
* Never throws; in debug builds every call is printed as `[analytics] <event> {params}`.
* Every custom event carries `game_version`. Set it per build with
  `--dart-define=APP_VERSION=<pubspec version>` (default `1.0.0+1`, keep in sync with `pubspec.yaml`).
* Booleans are sent as `1` / `0`; strings are cut to 100 chars; max 25 params.
* Privacy: no names, emails, free text, chat, or room codes. `user_id` = Firebase uid only.

## Automatic events (logged by the Firebase SDK)

`first_open` (`first_visit` on web), `session_start`, `user_engagement`, `app_remove`,
`in_app_purchase` (iOS/Android, with revenue), `ad_impression` (from the AdMob ↔ Firebase link).

`screen_view` is logged by the app (not the SDK) with clean names, see below. Automatic
screen reporting is turned off on Android (`google_analytics_automatic_screen_reporting_enabled`
in `AndroidManifest.xml`) and iOS (`FirebaseAutomaticScreenReportingEnabled` in `Info.plist`).

**ad_impression is intentionally not logged in code.** With AdMob linked to the
Firebase project, AdMob logs `ad_impression` (ad_platform, ad_source, ad_format,
ad_unit_name, value, currency) automatically; an `onPaidEvent` handler would
double-count revenue. See the note in `lib/core/ads/ads_mobile_gateway.dart`.

## User properties

| Property | Values | Set in |
|---|---|---|
| `game_version` | e.g. `1.0.0+1` | `AnalyticsService.init` |
| `app_language` | `he` | `AnalyticsService.init` |
| `auth_method` | `guest` / `google` / `apple` / `facebook` / `email` | `lib/app.dart` (auth listener) |
| `is_payer` | `true` after a successful purchase | `lib/core/purchases/iap_controller.dart` |
| `max_level` | highest unlocked level (1–100) | `lib/app.dart` (profile listener) |
| `current_world` | `seedling` / `sprout` / `bloom` / `forest` / `summit` | `lib/app.dart` (profile listener) |

`user_id` = Firebase uid, including anonymous guests. It is cleared on sign-out
(the auth stream emits `null`) and then set to the new guest uid.

## Screens (`screen_view`)

`lib/core/analytics/analytics_route_observer.dart` is attached to the GoRouter
(`lib/core/router/app_router.dart`). Only full pages are logged, never dialogs or sheets.

`splash, onboarding, how_to_play, rules, home, campaign_map, level_intro, level_play,
level_result` (+ `level_id` param), `race_setup, race_game, race_result, play_with_friends,
friends, room_create, room_join, room_lobby, online_race, online_race_result, daily,
daily_play, profile, settings, store, auth, other`.

## Shared events

| Event | Params | Fires in |
|---|---|---|
| `tutorial_begin` | – | `features/onboarding/onboarding_screen.dart` (first-run onboarding opened; not the "how to play" replay) |
| `tutorial_complete` | `skipped` (1 = "skip" before the last page) | same, `_finish` |
| `sign_up` | `method` | `features/auth/auth_screen.dart` `_logAuth`: a guest upgraded in place (same uid), or a new guest |
| `login` | `method` | same: sign-in to an existing account |
| `earn_virtual_currency` | `virtual_currency_name` (`coins`/`hints`), `value`, `source` (`level`/`daily`/`ad`/`wheel`/`purchase`/`gift`/`other`), `item_name` | `game_screen.dart` (level coins, finale bonus hints, lucky box/star drop = gift, wheel), `daily_challenge_game_screen.dart` (daily coins), `home_screen.dart` (daily login hints), `rewarded_gift_button.dart` + `game_screen.dart` (ads), `iap_controller.dart` (purchase), `store_screen.dart` (hint pack = other), multiplayer refunds/pot (other) |
| `spend_virtual_currency` | `virtual_currency_name`, `value`, `item_name` (`word_hint`, `reveal_letter`, `shuffle`, `level_skip`, `hint_pack_N`, `skin_<slot>_<id>`, `room_entry_fee`) | `game_screen.dart`, `level_result_screen.dart`, `store_screen.dart`, `create_room_screen.dart`, `join_room_screen.dart` |
| `ad_offer_shown` | `placement`, `reward` | `features/ads/rewarded_gift_button.dart` (first time the button is tappable), `game_screen.dart` `_tryGrantHintFromAd` |
| `ad_reward_earned` | `placement`, `reward` | same places, after the reward callback |
| `ad_show_failed` | `placement`, `format` (`rewarded`/`interstitial`), `reason` | same places + `level_result_screen.dart` `_exit` (interstitial). Reasons come from `AdsGateway.lastShowFailureReason` (`not_loaded`, `show_error_<code>`, `no_consent`, `timeout`, `not_started`, Ad Placement API `breakStatus`, ...). A viewer closing a rewarded ad early is not a failure. |
| `store_open` | `source` (`home`, `home_coins`, `home_hints`, `profile`, `level_no_coins`, `result_no_coins`, `other`) | `features/store/store_screen.dart` `initState` (source from `/store?from=`) |
| `purchase_start` | `product_id` | `core/purchases/iap_controller.dart` `buy` |
| `purchase_failed` | `product_id`, `reason` (`store_unavailable`, `not_started`, `start_exception`, `user_canceled`, `error_<code>`, `stream_error`) | same, `buy` / `_onPurchases` |
| `share` | `method` (`whatsapp`/`facebook`/`system`/`copy_link`/`copy_code`), `content_type` (`level_result`, `world_unlocked`, `daily_result`, `race_win_bots`, `race_win_friends`, `room_invite`, `friend_code`, `app_invite`) | `features/share/share_achievement_sheet.dart`, `multiplayer/room_lobby_screen.dart`, `social/social_actions.dart`, `settings/settings_screen.dart` |
| `settings_change` | `setting` (`sound`, `haptics`, `notifications`, `ad_privacy_options`, `sign_out`, `reset_progress`), `value` | `features/settings/settings_screen.dart` |

Ad placements: `level_hint`, `level_double_coins`, `store_gift_hint`, `store_gift_coins`,
`store_web_ad_card`, `daily_bonus_extra_hint`, `level_next` (interstitial).

## Word game events

All in `lib/features/game/game_screen.dart` unless noted.

| Event | Params | When |
|---|---|---|
| `level_start` | `level_id`, `world`, `level_kind` (`normal`/`master`/`worldFinale`), `grid_size`, `attempt` | board built (`_initSession`) |
| `level_end` | the above + `success` (1 = ≥1 star), `score`, `stars`, `words_found`, `score_target`, `words_possible`, `time_sec`, `wall_sec`, `hints_used`, `shuffles_used`, `reason`, `coins_earned`, `first_clear` | `_finishLevel` |
| `level_quit` | `level_id`, `world`, `level_kind`, `grid_size`, `attempt`, `time_sec`, `words_found`, `score`, `quit_type` (`exit`/`restart`/`skip`/`abandon`) | pause menu exit/restart, paid skip, screen disposed mid-run |
| `hint_used` | `level_id`, `hint_type` (`word_hint`/`reveal_letter`/`shuffle`), `cost`, `cost_currency` (`hints`/`coins`) | `_useHint`, `_revealLetter`, `_shuffleBoard` |
| `world_unlocked` | `world` | finale passed (`_finishLevel`) or skipped (`_confirmSkip`, `level_result_screen.dart` `_skipFromResult`) |
| `chapter_gate_shown` | `chapter`, `missing_stars` | closed chapter gate shown (`features/home/widgets/chapter_gate.dart`) |
| `chapter_unlocked` | `chapter`, `method` (`coins`), `cost`, `missing_stars` | chapter gate opened with coins (same file) |
| `wheel_spin` | `reward_type` (`coins`/`hints`/`coins_and_hints`/`double_coins`), `reward_value` | `_finishLevel` (first world-finale clear) |
| `daily_start` | `daily_date`, `grid_size` | `features/daily/daily_challenge_game_screen.dart` after the countdown |
| `daily_end` | `daily_date`, `success` (score > 0), `score`, `time_sec`, `words_found`, `reason` (`time_up`/`quit`/`abandon`) | same, `_finish` / `dispose` |
| `mp_match_start` | `mode` (`bots`/`friends`), `players`, `grid_size` | `multiplayer/race_game_screen.dart` (after countdown), `multiplayer/online_race_screen.dart` (`_initGame`) |
| `mp_match_end` | `mode`, `players`, `result` (`win`/`lose`/`draw`/`abandon`), `score`, `duration_sec` | same screens, `_finishRace` / `_finish` / exit / `dispose` |

Notes:

* **attempt** is 1-based per level and persisted in the Hive box `wordbox_analytics`
  (key `attempt_<level>`); it counts every start, including replays after a pass.
* **time_sec** = seconds on the game clock since `level_start` (pauses and ad breaks
  excluded); **wall_sec** = real seconds including pauses.
* **reason** comes from the game logic: `win` = score goal reached (the level ends
  immediately), `out_of_moves` = every word on the board found before the goal,
  `time_up` = the clock ran out. The campaign goal is a **score**, so `score_target`
  is sent instead of a `words_target`.
* No per-word events are logged.

## Consent (Google Consent Mode v2)

`lib/core/ads/ads_mobile_gateway.dart` `_syncAnalyticsConsent` passes the UMP status
to `AnalyticsService.applyAdsConsent` right after the consent form:

* `notRequired` (outside EEA/UK/CH): `analytics_storage`, `ad_storage`, `ad_user_data`,
  `ad_personalization` = granted.
* `required` (no decision could be collected): all denied.
* `obtained`: left to the UMP SDK, which writes the user's choices to Consent Mode.
  **Console step:** in AdMob → Privacy & messaging → GDPR message settings, enable
  "Consent mode" for Google Analytics for Firebase.
* Web: no UMP; GA4 defaults apply.

## Web

`web/index.html` sets `window.flutterfire_ignore_scripts = ['analytics']` and defines
`window.wordboxLoadAnalytics(version)`. `lib/core/analytics/analytics_web_loader_web.dart`
loads `firebase-analytics.js` (same CDN and version as `firebase-app.js`) after Firebase
is ready. If an ad blocker blocks it, analytics stays off; Auth, Firestore and multiplayer
are unaffected.

## Verify in Firebase DebugView

Firebase console → Analytics → **DebugView**. Events appear within seconds.

* **Android**
  ```bash
  adb shell setprop debug.firebase.analytics.app com.wordboxil.wordbox_hebrew
  # turn off again:
  adb shell setprop debug.firebase.analytics.app .none.
  ```
* **iOS**: Xcode → Product → Scheme → Edit Scheme → Run → Arguments Passed On Launch →
  add `-FIRDebugEnabled` (remove it, or add `-FIRDebugDisabled`, to turn it off).
  Bundle id: `com.wordboxil.wordboxHebrew`.
* **Web**: install the "Google Analytics Debugger" Chrome extension, or check the
  `collect?v=2` requests in DevTools → Network.
* **Logcat / console**: in debug builds, look for `[analytics]` lines.
* For BigQuery: Project settings → Integrations → BigQuery → link, with the daily
  (and optionally streaming) export.

## Identifiers

| | |
|---|---|
| Firebase project | `wordbox-64b19` |
| Android package | `com.wordboxil.wordbox_hebrew` (app id `1:856063251417:android:c7b6bc5afce965ce697fc8`) |
| iOS bundle id | `com.wordboxil.wordboxHebrew` (app id `1:856063251417:ios:76307dca59da7098697fc8`) |
| Web | app id `1:856063251417:web:8c744bd4324a4a68697fc8`, GA4 measurement id `G-8VZF3JSVD6` |
