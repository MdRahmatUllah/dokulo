# Dokulo privacy policy

The text the website and the store listings publish (DK-0679). English first,
German below. Placeholders in `{{…}}` are filled in where the policy is
published, never in this public repository: the controller's name and postal
address, the contact email and the date it takes effect. A change to what
Dokulo does with data changes this file, `docs/compliance/store-privacy-labels.md`
and the in-app Privacy page in the same PR.

Sources of truth it must match: `docs/compliance/network-uses.md` (what uses
the internet), `docs/compliance/crash-reports.md` (crash reports),
`docs/compliance/ai-models.md` (on-device models), the owner's decisions in
`.team/MEMORY.md` (no ads, no analytics, no account).

---

## English

**Effective {{date}}**

Dokulo is a PDF toolkit and scanner that works on your phone. Your files stay
on your phone: we don't upload them, we can't see them, and we don't have an
account system or a server that could hold them.

### Who is responsible

{{controller name}}, {{postal address}}. Questions about privacy:
{{email}}.

### What Dokulo does on your phone only

- **Your files, scans and edits.** Opening, scanning, converting, compressing,
  signing, redacting, OCR and every other tool run on your phone. Results are
  saved where you choose. Nothing is sent anywhere.
- **AI features** (summaries, questions about a PDF, translation, Smart
  Split) run on your phone with models you download. Your documents are not
  sent to any AI service.
- **The locked folder** is encrypted on your phone; its key is kept in your
  phone's secure storage (Keychain / Keystore) and opened with Face ID, your
  fingerprint or your PIN. We never receive it.
- **Find documents in photos** looks through your photos on your phone, only
  after you turn it on. Nothing is uploaded.
- **Settings and the list of files you used recently** are kept on your
  phone.

### What uses the internet, and only when you start it

Dokulo works in airplane mode. Three things use the internet:

1. **Downloading an AI or language model** you choose (for example the
   summary model or a translation pack). Your phone requests the file from
   the server that hosts it (currently Hugging Face and Mozilla's model
   storage on Google Cloud). Like any download, that server sees your IP
   address and the file requested. No document content is sent.
2. **Web page to PDF.** When you enter a web address, Dokulo loads that page
   from the internet, as a browser would, and turns it into a PDF on your
   phone. The website you load sees the request like any visit.
3. **Buying or restoring Pro.** The purchase is handled by the App Store or
   Google Play under their privacy policies. We receive no payment details;
   your phone only learns that Pro is unlocked.

No tool sends your files anywhere while it works.

### What we don't do

- **No ads.** Dokulo shows no advertising and contains no ad SDK.
- **No analytics or tracking.** We don't measure how you use the app, build
  profiles, or use advertising identifiers.
- **No account.** You don't sign up, and we hold no data about you.
- **No selling or sharing** of data: we don't have it to share.

### Crash reports: off unless you turn them on

If you turn on "Keep crash reports" (Settings → Privacy), Dokulo keeps a
short log of crashes on your phone: the error code, the time, the kind of
error and the place in Dokulo's code. It never contains file names, folder
paths, text or images from your documents, or anything that identifies you.
It leaves your phone only if you choose "Send report by email": your mail app
opens with the report, and you decide whether to send it. If you do, we use
the email and the report only to fix the problem, and delete them when that
is done, at the latest after 12 months.

### Permissions

Dokulo asks for a permission only when you first use the feature that needs
it, and works without it otherwise:

- **Camera:** to scan. Images stay on your phone.
- **Photos:** to import photos you pick (no permission on recent systems) and,
  if you turn it on, to find documents in your photos.
- **Add to Photos:** to save images you export.
- **Notifications:** to tell you when a long job has finished.
- **Face ID / fingerprint:** to open the locked folder and the app lock.

### Children

Dokulo is a general-purpose tool and collects no data from anyone, children
included.

### Your rights

Because we don't collect personal data, there is nothing we hold about you to
access, correct or delete. If you emailed us a crash report, you can ask us
at {{email}} to delete it; you can also complain to a data protection
authority.

### Changes

If what Dokulo does with data changes, we update this policy and the date
above before the new version of the app is released.

---

## Deutsch

**Gültig ab {{date}}**

Dokulo ist ein PDF-Werkzeugkasten und Scanner, der auf deinem Handy arbeitet.
Deine Dateien bleiben auf deinem Handy: Wir laden sie nicht hoch, wir können
sie nicht sehen, und wir haben weder Konten noch einen Server, auf dem sie
liegen könnten.

### Verantwortlich

{{controller name}}, {{postal address}}. Fragen zum Datenschutz:
{{email}}.

### Was Dokulo nur auf deinem Handy macht

- **Deine Dateien, Scans und Bearbeitungen.** Öffnen, Scannen, Umwandeln,
  Verkleinern, Unterschreiben, Schwärzen, Texterkennung und alle anderen
  Werkzeuge laufen auf deinem Handy. Ergebnisse werden dort gespeichert, wo
  du es wählst. Nichts wird irgendwohin gesendet.
- **KI-Funktionen** (Zusammenfassungen, Fragen an eine PDF, Übersetzung,
  Smart teilen) laufen auf deinem Handy mit Modellen, die du herunterlädst.
  Deine Dokumente gehen an keinen KI-Dienst.
- **Der geschützte Ordner** ist auf deinem Handy verschlüsselt; der Schlüssel
  liegt im sicheren Speicher deines Handys (Schlüsselbund / Keystore) und
  wird mit Face ID, deinem Fingerabdruck oder deiner PIN geöffnet. Wir
  bekommen ihn nie.
- **Dokumente in Fotos finden** durchsucht deine Fotos auf deinem Handy, erst
  wenn du es einschaltest. Nichts wird hochgeladen.
- **Einstellungen und die Liste deiner zuletzt genutzten Dateien** bleiben
  auf deinem Handy.

### Was das Internet nutzt, und nur wenn du es startest

Dokulo funktioniert im Flugmodus. Drei Dinge nutzen das Internet:

1. **Ein KI- oder Sprachmodell herunterladen**, das du auswählst (zum
   Beispiel das Modell für Zusammenfassungen oder ein Übersetzungspaket).
   Dein Handy lädt die Datei vom Server, der sie bereitstellt (derzeit
   Hugging Face und Mozillas Modellspeicher bei Google Cloud). Wie bei jedem
   Download sieht dieser Server deine IP-Adresse und die angefragte Datei.
   Es werden keine Dokumentinhalte gesendet.
2. **Webseite zu PDF.** Wenn du eine Webadresse eingibst, lädt Dokulo diese
   Seite aus dem Internet, wie ein Browser, und macht auf deinem Handy eine
   PDF daraus. Die Website sieht den Aufruf wie jeden Besuch.
3. **Pro kaufen oder wiederherstellen.** Den Kauf wickeln der App Store bzw.
   Google Play nach ihren Datenschutzbestimmungen ab. Wir erhalten keine
   Zahlungsdaten; dein Handy erfährt nur, dass Pro freigeschaltet ist.

Kein Werkzeug sendet deine Dateien irgendwohin, während es arbeitet.

### Was wir nicht tun

- **Keine Werbung.** Dokulo zeigt keine Werbung und enthält kein Werbe-SDK.
- **Keine Analyse, kein Tracking.** Wir messen nicht, wie du die App nutzt,
  erstellen keine Profile und nutzen keine Werbe-IDs.
- **Kein Konto.** Du meldest dich nirgends an, und wir haben keine Daten über
  dich.
- **Kein Verkauf, keine Weitergabe** von Daten: Wir haben keine.

### Absturzberichte: aus, außer du schaltest sie ein

Wenn du „Absturzberichte behalten“ einschaltest (Einstellungen →
Datenschutz), speichert Dokulo auf deinem Handy ein kurzes Protokoll von
Abstürzen: den Fehlercode, die Uhrzeit, die Art des Fehlers und die Stelle im
Code von Dokulo. Es enthält nie Dateinamen, Ordnerpfade, Text oder Bilder aus
deinen Dokumenten oder etwas, das dich erkennbar macht. Es verlässt dein
Handy nur, wenn du „Bericht per E-Mail senden“ wählst: Deine Mail-App öffnet
sich mit dem Bericht, und du entscheidest, ob du ihn sendest. Wenn ja,
nutzen wir die E-Mail und den Bericht nur, um den Fehler zu beheben, und
löschen sie danach, spätestens nach 12 Monaten.

### Berechtigungen

Dokulo fragt eine Berechtigung erst, wenn du die Funktion zum ersten Mal
nutzt, und funktioniert sonst auch ohne sie:

- **Kamera:** zum Scannen. Die Bilder bleiben auf deinem Handy.
- **Fotos:** um Fotos zu importieren, die du auswählst (auf neuen Systemen
  ohne Berechtigung), und, wenn du es einschaltest, um Dokumente in deinen
  Fotos zu finden.
- **Zu Fotos hinzufügen:** um exportierte Bilder zu speichern.
- **Mitteilungen:** um dir zu sagen, dass eine lange Aufgabe fertig ist.
- **Face ID / Fingerabdruck:** um den geschützten Ordner und die App-Sperre
  zu öffnen.

### Kinder

Dokulo ist ein allgemeines Werkzeug und erhebt von niemandem Daten, auch
nicht von Kindern.

### Deine Rechte

Da wir keine personenbezogenen Daten erheben, gibt es nichts über dich, das
wir herausgeben, berichtigen oder löschen könnten. Wenn du uns einen
Absturzbericht gemailt hast, kannst du unter {{email}} verlangen, dass wir
ihn löschen; du kannst dich auch bei einer Datenschutzaufsichtsbehörde
beschweren.

### Änderungen

Wenn sich ändert, was Dokulo mit Daten macht, passen wir diese Erklärung und
das Datum oben an, bevor die neue App-Version erscheint.
