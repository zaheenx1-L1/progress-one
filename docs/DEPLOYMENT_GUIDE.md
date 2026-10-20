# Install PROGRESS ONE on your MacBook and iPhone

This guide is for your setup: **15-inch 2018 MacBook Pro (Intel)**, **iPhone 13 Pro Max**, a **free Apple ID**, and a **free Supabase project** for sync.

You do these steps once. Allow about two hours, mostly waiting for downloads.

---

## Part 1. Get your Mac ready

### 1.1 Update macOS to Sequoia

1. Click the Apple menu  → **System Settings** → **General** → **Software Update**.
2. Install **macOS Sequoia 15** and every 15.x update offered. Sequoia is the newest macOS your 2018 MacBook Pro can run.
3. Check: Apple menu  → **About This Mac** should say **macOS Sequoia 15.6** or newer.

### 1.2 Install Xcode 26 (not Xcode 27)

Apple's newest Xcode 27 only runs on Apple-silicon Macs with macOS Tahoe, so it **will not install on your Mac**. You need the last Xcode that supports Intel Macs: **Xcode 26**.

1. Go to [developer.apple.com/download/all](https://developer.apple.com/download/all/) and sign in with your normal Apple ID (free).
2. In the search box type **Xcode 26**. Pick the newest **Xcode 26.x** whose notes say it runs on macOS Sequoia, and download the `.xip` file (about 3 GB).
3. Double-click the `.xip` file. It unpacks to **Xcode.app**. Drag it into your **Applications** folder.
4. Open Xcode. Accept the licence, and when it asks which platforms to install, tick **iOS** and click **Download & Install**. This also takes a while.
5. In Xcode open **Xcode → Settings → Accounts**, click **+**, choose **Apple ID**, and sign in. Xcode creates a free **Personal Team** for you.

> If the App Store shows Xcode, ignore it: it offers Xcode 27, which your Mac can't run.

### 1.3 Download the project

1. Go to [github.com/zaheenx1-L1/progress-one](https://github.com/zaheenx1-L1/progress-one) and sign in.
2. Click the green **Code** button → **Download ZIP**. (Once the first version is merged; until then, switch to the branch named in the pull request first.)
3. Unzip it and move the folder somewhere easy, such as **Documents**.

---

## Part 2. Create your free Supabase project (the sync server)

1. Go to [supabase.com](https://supabase.com) → **Start your project**, and sign up (free plan).
2. Click **New project**. Name it `progress-one`, choose a strong database password (save it in your password manager), and pick the region closest to you (for Dubai, choose a **Middle East** or **Europe** region). Click **Create new project** and wait a minute.
3. **Create the database tables:**
   1. In the left sidebar click **SQL Editor** → **New query**.
   2. Open the file `supabase/migrations/0001_foundation.sql` from the project folder in TextEdit, select everything, copy it, and paste it into the query box.
   3. Click **Run**. It should say **Success. No rows returned.**
4. **Make sign-up simple:** in the sidebar open **Authentication** → **Sign In / Providers** (or **Providers**) → **Email**, turn **Confirm email** off, and save. (You can leave it on; you'll just need to tap a link in an email once.)
5. **Copy your two connection values** from **Project Settings** → **API** (or **Data API**):
   - **Project URL**, like `https://abcd1234.supabase.co`
   - **anon public** key, a long text starting with `eyJ`

   These two values are designed to be used inside apps. Your data stays private because each table only lets a signed-in user see their own rows. Never share the **service_role** key.

> Free Supabase projects are paused after a week with no activity. If sync stops after a break, open the Supabase dashboard and click **Restore project**.

---

## Part 3. Run it on your MacBook

1. In the project folder, double-click **ProgressOne.xcodeproj**. Xcode opens it.
2. In the left panel click the blue **ProgressOne** project icon, then the **ProgressOne** target, then the **Signing & Capabilities** tab.
3. Under **Team**, choose **your name (Personal Team)**.
   - If Xcode says the bundle identifier is not available, change **Bundle Identifier** to something unique, like `com.yourname.progressone`.
4. At the top of the window, click the device menu next to the ▶ button and choose **My Mac**.
5. Click ▶ (**Run**). The first build takes a few minutes.
6. The app opens. Click **Sign in to sync**, paste your **Project URL** and **anon key**, choose **Create account**, enter your email and a password (8+ characters), and click **Create**.

To keep the Mac app without Xcode: in Xcode choose **Product → Show Build Folder in Finder**, open **Products → Debug**, and drag **ProgressOne.app** into **Applications**.

---

## Part 4. Run it on your iPhone 13 Pro Max

1. Plug your iPhone into the Mac with a cable. Unlock it and tap **Trust** if asked.
2. On the iPhone, turn on **Developer Mode**: **Settings → Privacy & Security → Developer Mode** → on, then restart the phone and confirm.
3. In Xcode, choose your **iPhone** in the device menu next to ▶, then click ▶.
4. The first time, the iPhone will refuse to open the app. On the iPhone go to **Settings → General → VPN & Device Management**, tap your Apple ID under **Developer App**, and tap **Trust**.
5. Open **Progress One** on the iPhone. Tap **Sign in to sync**, paste the same **Project URL** and **anon key**, choose **Sign in**, and use the same email and password you created on the Mac.

### The free Apple ID 7-day limit

With a free Apple ID, the app on your iPhone **stops opening after 7 days**. Your data is safe (it is on the phone and in Supabase). To renew it, plug the iPhone into the Mac, open the project in Xcode, choose your iPhone, and click ▶ again. The Mac app does not expire.

The paid Apple Developer Program ($99/year) removes this limit and allows TestFlight. You can switch later without losing data.

---

## Part 5. Check that sync works (spec acceptance tests A and B)

1. On the **Mac**, in **Today**, type a task in **Quick add** and press Return.
2. On the **iPhone**, open **Today** and pull down to refresh. The task appears within a few seconds.
3. On the **iPhone**, tap the circle to complete it.
4. On the **Mac**, the task shows as done within a minute (or press **⇧⌘R** to sync now).

The coloured badge at the top of **Today** shows the sync state: **Synced**, **Syncing**, **Offline**, **changes waiting**, **conflict needs you**, or **Sync problem**. Tap **Sync Status** (Mac sidebar, or iPhone **Settings**) for details.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Xcode won't install | Make sure it's **Xcode 26.x** from developer.apple.com, not the App Store, and that macOS is Sequoia 15.6+. |
| "Failed to register bundle identifier" | Change the Bundle Identifier (Part 3 step 3) to something unique. |
| Xcode says the iPhone's iOS is newer than it supports | Your iPhone may be on iOS 27 while your Mac can only run Xcode 26. Try **Window → Devices and Simulators** and let Xcode prepare the device. If it still fails, see `docs/KNOWN_ISSUES.md` (KI-1). |
| App stops opening on iPhone | 7-day free limit: reinstall from Xcode (Part 4 step 3). |
| "Sync problem: Please sign in again" | Open **Settings → Sign in to sync** and sign in again. |
| Sync says Offline but you are online | Your Supabase project may be paused. Open the Supabase dashboard and restore it. |
| Sign-up says to check your email | Tap the link in the email from Supabase, then choose **Sign in**. |

## Backup and recovery

- Every synced record lives in your Supabase database. In Supabase, **Database → Backups** shows the automatic daily backups (free plan keeps a limited history).
- Each device also keeps a full local copy, so if Supabase is unavailable the app keeps working and syncs later.
- Full data export (PDF/CSV) is planned for Step 4.
