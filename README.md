# HSK 2 Quiz – iOS port (UIKit, iOS 12+)

Port of the Android app (Kotlin/Compose) to Swift/UIKit so it runs on an iPad Air 1 (iOS 12.5).
No Mac needed: GitHub Actions builds the IPA.

## Build the IPA
1. Create a new **private** GitHub repo and upload everything in this folder (keep the `.github` folder).
2. Open the repo → **Actions** → **Build IPA** → it runs on every push (or press *Run workflow*).
3. When it is green, open the run → **Artifacts** → download `HSK2Quiz-ipa` → unzip → `HSK2Quiz.ipa`.

## Install on the iPad
Use **Sideloadly** (Windows/Mac) with your Apple ID: connect the iPad by USB, drag in `HSK2Quiz.ipa`, press Start.
On the iPad: Settings → General → Profiles/Device Management → trust your Apple ID.
A free Apple ID needs re-signing every 7 days.

## Porting stages
1. **Stage 1 (this drop):** project + GitHub build, data/progress/speech, Home, 3 quiz modes, results,
   word list + bookmarks + PDF export, Pick words (range tools), word detail sheet.
2. Stage 2: Watch & learn (stroke order), historical animation (WKWebView).
3. Stage 3: Four lenses, Story time (offline + online AI story).
4. Stage 4: Bubble Quiz, Match & Recognize.
5. Stage 5: PDF Reader mode (PDFKit), polish.

Home buttons for later stages show a "coming in Stage N" message for now.
