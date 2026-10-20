# Known issues and limits

| ID | Issue | Impact | Plan |
|---|---|---|---|
| KI-1 | The 2018 MacBook Pro can only run Xcode 26 (Xcode 27 needs an Apple-silicon Mac with macOS Tahoe). If the iPhone is updated to an iOS version newer than Xcode 26 supports, installing from Xcode may fail. | Possible block on iPhone installs. | Test on the real devices first. Options if it fails: keep the iPhone on its current iOS, use a newer Mac for builds, or a cloud Mac build service. |
| KI-2 | Free Apple ID: the iPhone app expires after 7 days and must be reinstalled from Xcode. | Weekly reinstall. | Paid Apple Developer Program removes it; no code change needed. |
| KI-3 | Free Apple ID: no Sign in with Apple, no remote push notifications, no TestFlight. | Email sign-in; reminders will be local notifications (Step 4). | Revisit if the program is purchased. |
| KI-4 | Free Supabase projects pause after a week without activity. | Sync shows Offline until the project is restored in the dashboard. | Documented in the install guide. |
| KI-5 | The app compiles for iOS and macOS in CI, but has not yet been run on a real device or simulator. | Runtime problems would only show once installed. | First install on the owner's devices (TEST_PLAN.md manual tests). |
| KI-6 | Signing out and signing in with a different account on the same device is not supported yet; records from the first account would be sent to the second. | Only matters with two accounts. | Add "erase this device's data" on account switch in Step 2. |
| KI-7 | Region and app-lock settings are per device, not synced. | Set them on each device. | Move to a synced profile in Step 2. |
| KI-8 | Local lookups load a whole table into memory for sync. | Fine for thousands of records; slower beyond that. | Add indexed queries when data grows. |
| KI-9 | The AI mentor (Step 4) needs the Claude API, which is paid per use. | Cost decision needed before Step 4. | Owner to decide. |
