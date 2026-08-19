# Start here

**This file is written for the AI, not the human.** If someone has just pointed you at
this repo and asked for help setting up a second brain, read this whole file before
doing anything else.

Your job is to get them a working brain with the least effort *on their part*. Many
people arriving here are not technical and will abandon this at the first command they
do not understand. Treat every step you can take yourself as a step they should not
have to.

---

## Step 1 - work out which path you are on

Be honest about your own capabilities. Do not assume.

- **Can you run shell commands and create files on this person's computer?**
  -> **Path A**
- **Can you only read and write text in this conversation?**
  -> **Path B**

If you genuinely cannot tell, ask them one question: *"Are you talking to me in a
terminal (Claude Code), or in the Claude app or website?"* Do not guess - getting this
wrong wastes their time on instructions that cannot work where they are.

---

## Path A - you can run commands (Claude Code)

1. **Check prerequisites first, and report missing ones before you start.**

   ```bash
   claude --version && git --version && uv --version
   ```

   `uv` is required - every script here declares its own dependencies inline (PEP 723)
   and `uv` is what resolves them. System `python3` will not work: it has no PyYAML and
   is usually externally managed, so `pip install` refuses. If `uv` is missing, tell
   them what it is and point them at the official installer at
   <https://docs.astral.sh/uv/> - do not pipe a script from the internet on their behalf,
   and do not silently continue without it.

2. **Install the plugin.**

   ```bash
   claude plugin marketplace add vikingsearth/brainalyser
   claude plugin install brainalyser@memorymarket
   ```

3. **Tell them to restart the session.** You cannot do this for them. Hooks load at
   session start, so recall stays off until they do.

4. **In the new session, run `/brain-init`.** It interviews them and builds the
   structure around their answers. Let it do that - do not pre-empt it with a layout
   you invented.

5. **Make sure the two routines got installed.** `brain-init` offers this, but do not
   assume it happened - check `~/.claude/scheduled-tasks/` for `daily-brain-sweep` and
   `weekly-brain-validity`, and install them if they are missing:

   ```bash
   ls ~/.claude/scheduled-tasks/
   ```

   This is the step that decides whether their brain is alive or a folder they forget.
   Without the routines it only grows when they remember to say "log this", and nothing
   ever audits it. They are unlikely to ask for this, because they do not yet know it is
   a thing - so it is on you to raise it. The install steps and the cron lines are in
   [`plugins/brainalyser/routines/README.md`](plugins/brainalyser/routines/README.md).
   Say what each one does in one sentence each and let them decline; do not lecture.

6. If they have existing Claude Code history worth importing, mention `brain-backfill`
   afterwards. Do not run it unprompted: it is a long job, and it is not what they asked
   for.

---

## Path B - you cannot run commands (Claude app, website, another assistant)

**There is no software to install on this path.** The whole thing is a set of
instructions plus a folder of markdown files. Say that plainly - it is reassuring, and
it is true.

1. **Read [`BRAIN-SEED.md`](BRAIN-SEED.md) in this repo now.** It contains the format,
   the interview, and the recall and capture rules. From here on it is your operating
   manual.

2. **Start being useful immediately, before any setup.** Run the interview from
   `BRAIN-SEED.md` in this conversation and write their first few notes out in the chat.
   People commit to a system after they see one working, not before. Do not make them do
   admin first.

3. **Then ask them for the one manual step you cannot do yourself.** Give them the exact
   clicks for wherever they are, for example on claude.ai:

   > Create a Project, open its instructions box, and paste in the contents of
   > `BRAIN-SEED.md`. That is the whole setup - after it, every chat in that Project
   > remembers.

   Explain what it buys them in one sentence: without it, everything you just wrote
   together disappears when the chat ends.

4. **Where the files live is their choice.** A synced folder they can see is usually
   right. If they have nowhere obvious, say so honestly rather than inventing a path -
   they can keep notes in the Project itself and move them later.

5. If they later start using Claude Code, tell them Path A does all of this
   automatically and nothing they wrote is wasted - the format is identical.

---

## Rules for you, on either path

- **Do not give them a tour.** They asked for a working brain, not to understand OKF.
  Explain a concept only when a step needs it.
- **Do not install or download anything without saying what it is and why.** If a step
  needs their permission or their password, hand it to them - do not work around it.
- **Aim for three to five top-level folders.** Push back once if they want more. Adding
  one later costs nothing; abandoning an over-designed brain costs everything.
- **Never invent their structure for them.** The interview exists because a brain shaped
  like someone else's gets abandoned. If they have no answers, scaffold small and say the
  shape will emerge from a week of use.
- **Write real notes, not placeholders.** A brain whose first session produces empty
  folders reads as homework.
- **Include a note about the person themselves.** Without it you cannot resolve "I" or
  "my" later, and the gap is invisible until it bites.
- **Do not mark anything as verified that you inferred.** An honest unverified note is
  fine; a confident wrong one poisons everything downstream.
- **A brain with no routines is a folder they will forget.** On Path A, do not call the
  setup finished until the daily sweep and the weekly audit are scheduled, or they have
  actively said no to them.
- **Finish by telling them the one next action**, which is usually: *"just talk to me
  normally - I will capture as we go."*
