# Installing Voice Launcher

There are two ways. **Homebrew is the one to use** — it installs the app and
nothing stands in your way. The `.dmg` works too, but macOS will refuse to open
the app once, and you will have to tell it to allow it.

If you only want the short version, it is at the top of the
[README](../README.md). This page is for when something asks a question you
did not expect.

---

## Why there are two ways, and why one of them is awkward

Voice Launcher is signed with a certificate I made myself, not one issued by
Apple. Apple's is part of a paid developer membership, and this is a free
application, so it has not been bought.

macOS treats anything downloaded from the internet that Apple has not vouched
for as suspect: it attaches an invisible "quarantine" mark to the file, and
refuses to launch it. The mark is attached by whatever downloads the file.

**Homebrew removes that mark for you as part of installing.** A web browser does
not, and nothing inside the downloaded file can remove it either. That is the
whole of the difference between the two methods.

---

## Method 1 — Homebrew (recommended)

### What Homebrew is

A package manager for macOS: a program that installs other programs. One command
installs an application, another updates it, a third removes it cleanly. It is
free, widely used, and installs into its own folder without touching the system.

### If you do not have it yet

Open **Terminal** (⌘Space, type `Terminal`, Enter) and paste this single line,
which comes from [brew.sh](https://brew.sh):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

It will ask for your account password and may install Apple's Command Line
Tools first, which takes a few minutes. When it finishes it prints two or three
commands of its own to run; run them, or Homebrew will not be found afterwards.

### Install Voice Launcher

```bash
brew tap umkasanki/tap
brew trust umkasanki/tap
brew install --cask voice-launcher
```

The first line adds my collection of applications. The second says you trust it:
Homebrew asks this once for any collection that is not its own. The third
installs Voice Launcher into your Applications folder and clears the quarantine
mark on the way, so the app opens the first time without argument.

Then open it and allow what it asks for: **[Permissions](#permissions)**.

### Updating and removing

```bash
brew upgrade --cask voice-launcher          # update to the newest release
brew uninstall --cask voice-launcher        # remove the application
brew uninstall --zap --cask voice-launcher  # remove it, its commands and settings
```

---

## Method 2 — the `.dmg` file

### What a `.dmg` is

A disk image: a single file that behaves like a disc. You double-click it, a
window opens with the application inside, and you drag that application into
your Applications folder.

### Steps

**1. Download.** Open the [latest release](https://github.com/umkasanki/voice-launcher/releases/latest)
and download `VoiceLauncher-<version>.dmg`.

**2. Install.** Double-click the downloaded file. A window opens with the Voice
Launcher application and a shortcut to your Applications folder. Drag the
application onto the folder, then eject the disk image.

**3. Try to open it — and expect to be refused.** Double-click Voice Launcher in
Applications. macOS says it **cannot verify that the application is free of
malware**, with the buttons *Move to Bin* and *Done*. **Press Done.** Nothing is
wrong with the application; it simply has not been given Apple's blessing.

**4. Allow it.** Open **System Settings → Privacy & Security** and scroll the
right-hand pane down to the section headed **Security**. There is a line saying
that *"Voice Launcher" was blocked to protect your Mac*, and a button
**Open Anyway**. The line only appears for about an hour after the refusal; if
it is not there, double-click the application once more and come back.

Press **Open Anyway**, enter your password or use Touch ID, and confirm with
**Open**.

**5. Open the app again.** It starts normally from now on.

### If you are comfortable with Terminal

One command does what steps 3–5 do, before you ever launch the app:

```bash
xattr -dr com.apple.quarantine "/Applications/Voice Launcher.app"
```

### Updating and removing

To update, download the newer `.dmg` and drag the new app over the old one. The
permissions you granted are kept, because they are tied to the signing
certificate rather than to that particular copy of the file.

To remove, drag Voice Launcher from Applications to the Trash. Its commands live
in `~/Library/Application Support/VoiceLauncher/`, its settings in
`~/Library/Preferences/com.umkasanki.VoiceLauncher.plist`, and its log in
`~/Library/Logs/VoiceLauncher.log`, if you want those gone too.

---

## Permissions

On first launch macOS asks two questions. Answer **Allow** to both.

- **Microphone** — Voice Launcher listens for your phrases.
- **Speech Recognition** — it turns what it hears into text, to compare with
  your phrases. Recognition runs on this Mac; nothing is sent anywhere.

If you pressed *Don't Allow* by mistake: **System Settings → Privacy & Security
→ Microphone** (and then **Speech Recognition**), turn on **Voice Launcher**,
and start the app again.

---

## When something is still wrong

**"Voice Launcher is damaged and can't be opened."** The same quarantine mark,
phrased differently. Use the Terminal command above.

**The menu says "No microphone is connected."** The Mac has no input device —
a Mac mini has no built-in microphone. Connect one; Voice Launcher starts
listening as soon as macOS reports it.

**Nothing happens when you speak.** Open **Settings… → Commands**, choose the
command, press **Edit…** and use **Start Test**: it shows what was heard and how
well it matched. **Use Heard Text** copies what the recogniser heard into the
phrase.

**You cannot click well enough to do any of this.** macOS has its own dwell
clicking and Voice Control built in: **System Settings → Accessibility**.
