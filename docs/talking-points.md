# Shared Brain - talking points

Speaker notes for `second-brain-deck.html`. The slides carry the visuals and the
headline; this file carries what you say over them.

---

## Slide 1 - Shared Brain

Opening. The slide is title, subtitle and the illustration only, so this is all spoken.

- Everyone here already has an agent. The gap is that it starts every session knowing nothing about you.
- "Shared" is the point, not "second" - the file is yours, and the agent reads and writes the same one.
- Set the frame for the talk: this is a folder of markdown files, not a product you buy or a service you sign up for.
- Say up front that both technical and non-technical people can run this - the non-technical path is one file you paste in.

## Slide 2 - The Problem

The illustration carries the joke (agent delighted, human worn out, meeting "for the first time" again). These are the three points:

- **Agent memory resets every session.** Every new chat is a first introduction, no matter how much you covered yesterday.
- **Context lives in your head, restated daily.** Who your team is, which repo matters, how you like things written - you retype it or you get generic output.
- **Corrections don't stick.** You correct the same thing next week. The fix never becomes a rule, so it never compounds.

Worth landing here: the cost isn't the retyping, it's that nothing accumulates.

## Slide 3 - Shared Brain

Two illustrations: the agent reading an index off a clipboard (left), and the brain's
content itself - markdown spilling out of an oversized head (right).

- **A folder of markdown files, kept in git.** Nothing exotic. You can read every file yourself, and git gives you the history for free.
- **The agent reads it before answering, writes to it after learning.** Both directions matter. Read-only is a document; read-write is a memory.
- **The files are the memory - no database, no sync layer.** Nothing to derive, nothing to keep in step, nothing to run. That is the whole reason it survives.
- **Mine: ~300 curated files, built up over 5 months.** Curated is the operative word - they were written and corrected one at a time as things came up, not bulk-generated.

## Slide 4 - The Format (Part One)

Section divider. The quadrant box names the four conventions that make up the whole format -
that is the promise for the next four slides, so keep it short.

- Four conventions and nothing else: **OKF**, **frontmatter**, **index**, **log**.
- Worth saying: this is the entire specification you need to hold in your head. There is no fifth thing, no config, no schema to register.
- Each quadrant gets its own slide next.

## Slide 5 - OKF

The code sample covers the first two points; the tree covers the third. Click the
folders live - `brain`, then `performance`, then `goals`.

- **Open Knowledge Format: markdown + YAML frontmatter.** The block between the `---` lines is machine-readable; everything under it is for humans. One file, both audiences.
- **One fact per file; the file path is its ID.** The path at the top of the card *is* the identifier - no database keys, no ids to maintain. Move the file and you have renamed the fact.
- **Directories are domains; markdown links are relationships.** The tree is the whole schema. Nesting carries the grouping, and a plain markdown link from one file to another is the edge.
- **Any agent that reads files can use it.** No SDK, no API, no server. This is why it survived swapping harnesses - the format outlived the tooling I first built around it.

## Slide 6 - Frontmatter

Same bee file as the previous slide, with the frontmatter filled all the way out. The
field names are colour-grouped on the slide: required, indexed, provenance, trust, sources.

- **`type`: the one required field.** person, project, preference, learning. Everything else is optional - that is deliberate, so a half-written note is still a valid note.
- **`title`, `description`, `tags`: what indexes and search read.** These are the fields that make a file findable without opening it. A note with a vague description is a note the agent will skip.
- **`generated: {by, at}`: who wrote it, and when.** An agent-written note says so. Mine records `claude-code/opus-5` - and that honesty is what lets the trust tier below it mean anything.
- **`verified`, `stale_after`: trust and expiry, checked by script.** `verified` with a `human:` actor is the only thing that marks a note as human-reviewed. `stale_after` is a date, so a script flags decay instead of me hunting for it.
- Worth saying out loud: `verified` is **earned, never routine**. An unverified note is honest; a falsely verified one poisons the whole signal.

## Slide 7 - Root Dirs

Seven scattered boxes, one per root directory of my own brain. The scatter is the point -
they are not a ranked list, and they were not designed up front.

- **Your top level states what matters to you.** Someone reading only your directory names should be able to tell what you do all day. That is the test.
- **Mine: preferences, performance, people, projects, quests, concepts, tribal knowledge.** Two worth explaining: `quests` is workstreams, borrowed from game framing because it is how I actually think about my work. `tribal knowledge` is company-bound - it is the split that decides what stays behind if I leave, and everything else is portable.
- **There is no fixed list - name your own.** These seven were not planned. They accumulated, and I renamed and moved things as they stopped fitting - `orrery` graduated out of a container directory into its own project once it outgrew it.
- If someone wants a starting point rather than a blank page: pick three, not seven.

## Slide 8 - index.md

The GPS is the metaphor: five routes branch off and dead-end, one route through the middle
reaches the pin. The index is what stops the agent walking every path.

- **One per directory: what is in here.** Every directory carries its own `index.md`. It is a plain list of what lives there and a line on each.
- **Read order: root index -> domain index -> one file.** Three reads to reach any fact, out of ~300 files. That is the whole payoff.
- **Cheap navigation instead of reading everything.** Without indexes the agent greps blind or reads the world. Progressive disclosure is what keeps recall affordable.
- **Keep it in step with the directory contents.** This is the one maintenance cost of the whole system, and it is the thing that rots first. My weekly audit checks indexes against the actual files, because a stale index sends you confidently down a dead end - worse than having none.

## Slide 9 - log.md

The agent is nearly off the right edge - the present moment. Every step behind it raised a
beam ending in a cube: the step happened, and the step got recorded.

- **History: dated entries, append-only, newest first.** Nothing gets edited out. Newest at the top so the first thing you read is the current state of play.
- **Notes hold current state; logs hold what changed.** This split is the one that makes the whole thing work. The note always reads as true today; the log carries how it got there.
- **Decisions are log entries, not separate notes.** A decision is an event with a date, so it belongs in history. Making it a note would leave you asking whether it is still in force.
- **Correct the note in place, record the change in the log.** You never end up with two versions of a fact competing. The old wording lives in the log if anyone needs it.

## Slide 10 - Choose an Approach

Two illustrations, deliberately parallel: same agent, same incoming note, different filing.
The point of the slide is that **you** pick - these are two worked examples, not a
recommendation and an alternative.

- **Mine is categorical.** Daily content gets routed into topic domains - people, projects, preferences. Notice the left picture fans out into three differently-coloured folders: the sorting question is *what is this about*.
- **A colleague of mine sorts by timeline.** Daily, weekly and monthly directories. The right picture is one colour in three granularities, entering at the top and rolling forward: the sorting question is *when did this happen*.
- **Same files, same format, different primary axis.** Nothing about OKF prefers either. Both are conformant bundles.
- **Pick the way you already sort things in your head.** If you find things by remembering the topic, go categorical. If you find things by remembering roughly when, go timeline. Guessing wrong is cheap - directories rename.
- Honest note if asked: mine was not designed, it accumulated. theirs is tidier at the point of capture because there is only ever one place today's note can go.

## Slide 11 - How?

The whole close. The agent is confused on purpose - "where do I even start" - and the
answer on the right is that they do not have to start. They hand the problem to their
own Claude.

### Read the box out loud

> Look at this repo: https://github.com/vikingsearth/brainalyser
> Read START-HERE.md and follow it to set me up with a second brain.

That is the entire onboarding. Two lines, no prerequisites to explain, nothing to
decide up front.

### Why it works without them knowing anything

- **`START-HERE.md` is written for the agent, not for them.** It is the first thing their
  Claude reads, and it settles one question before anything else: can I run commands on
  this person's machine or not?
- **If yes** (Claude Code) it checks prerequisites, installs the plugin, tells them to
  restart, then runs the interview. They type nothing but answers.
- **If no** (Claude app, web, anything else) there is **nothing to install** - say that
  plainly, it is the reassuring part. Their Claude runs the interview right there in the
  chat, writes their first few notes so they see it working, and only then asks for the
  single thing it cannot do itself: paste one file into a Project's instructions.
- Either way **the interview is what personalises it.** Nobody adopts my seven folders.
  Their Claude asks what they care about and builds around the answers - including the
  topic-versus-date question from the previous slide.

### Say this out loud - the disclaimer

Be straight with them, it buys credibility and it saves you support:

- **This is freshly built for sharing and it will have rough edges.** It has been tested
  end to end, but not by many people, and not on their setup.
- **When something breaks, they should not wait for me.** Tell their Claude to fix it
  with OKF and the spirit of the repo in mind - the format is documented in the repo and
  their agent can read all of it.
- **But do report the failure back to me** so the fix lands for everyone instead of
  living in one person's copy.
- **One real prerequisite on the Claude Code path: `uv`.** Every script declares its own
  dependencies inline and `uv` is what resolves them. System Python will not do it. If
  they are missing it, that is the one thing that stops `/brain-init` finishing, and
  `START-HERE.md` tells their agent to flag it rather than fail quietly.

### Where this is going

This is an early version, shared now because it is useful now - not its final home.
Anything built in it carries over regardless: the format is plain markdown in your own
git repo, and it does not depend on where the tooling ends up living.

### If asked "what does it cost to run"

The backfill is the only expensive part and it is optional and one-time - roughly
6 cents per source at the default `sonnet`/`low`, so a few hundred sessions is real money.
`BACKFILL_LIMIT` caps a trial run. Day-to-day capture costs nothing extra; it happens
inside conversations they were having anyway.
