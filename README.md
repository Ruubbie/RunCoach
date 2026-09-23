# RunCoach

Native iPhone running coach: GPS tracking with the screen locked, spoken interval
cues, an 8-week run/walk plan, strict local reminders, and a one-tap export to talk
it through with Claude. Built entirely from Windows: GitHub compiles it, SideStore
signs and refreshes it.

## 1. Put the code on GitHub
1. Create a new GitHub repo. A **public** repo gets free unlimited build minutes.
   Private repos have a small free allowance, and Mac build minutes count extra.
2. Push this folder to the `main` branch.
3. Open the **Actions** tab. "Build IPA" runs automatically (about 5–10 min).
   When it's done, there's a release called **latest** containing `RunCoach.ipa`.
   Every push to `main` builds a fresh version.

## 2. Install SideStore on your iPhone (one-time, uses your Windows PC)
Follow the official guide at https://docs.sidestore.io. It walks you through:
- enabling Developer Mode on the iPhone,
- creating a pairing file on your PC,
- installing SideStore with your (free) Apple ID.
Then set up automatic refresh as the guide describes, so apps never expire.

## 3. Install RunCoach
1. On your iPhone, open the GitHub release page in Safari and download `RunCoach.ipa`.
2. In SideStore, go to My Apps → **+** and pick the file from Downloads.
3. Open RunCoach. Allow **notifications** and **location** ("While Using" is enough;
   tracking keeps running when you lock the screen, with a blue location pill).

To update: push code, wait for the build, then install the new IPA the same way.
Your run history stays on the phone.

## How it works
- `PlanEngine.swift`: the training plan. Weeks 1–4: 3 runs, 3 walks, 1 rest.
  Weeks 5–8: 4 runs, 2 walks, 1 rest. Target: 30 min nonstop by week 8.
- `RunSession.swift`: GPS, pace, splits, interval timing, voice cues.
- `Notifier.swift`: reminders at your chosen hour, a follow-up 2 hours later
  and a "last call" at 21:00 on active days, cancelled once you've done the workout.
- `CoachView.swift`: settings, plus "Copy my training summary" for Claude.

## Limits of a free Apple ID
- No server push notifications (these reminders are local, so that's fine).
- Max 3 sideloaded apps at a time.
- Apple sometimes changes things that briefly break SideStore; they usually
  patch it quickly. Keep SideStore updated.
