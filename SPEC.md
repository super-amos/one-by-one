# One by One: v1 spec

One by One is a Mac app that shows your to-do list one task at a time. You finish the task in front of you or put it off, and the next one takes its place. Each finished task earns a small pretend reward you're allowed to spend on yourself.

Updated 2026-10-23. Everything below is built. The `.round-table/` folder holds an older generated plan whose questions were never answered. Where it disagrees with this file, this file wins.

## Settled decisions

- Native Mac app (SwiftUI, macOS 14 or later). Fully offline: no account, no server, no sync. Everything is saved in one JSON file in `~/Library/Application Support/One by One/`.
- Home shows the current task and nothing else. No count, no stack, no glimpse of what's next. The number of tasks left appears only on the Edit page.
- Swipe right is done. Swipe left is later, which sends the task to the bottom.
- The money is symbolic, and it looks like a reward, not a wallet: a gift icon, warm amber and coral, and the words "rewards", "earned" and "treat yourself". The app never says "balance" or "wallet". You log what you spent and it comes off your rewards. Nothing connects to a bank or a card.
- Rewards can go below zero. While they do, mock credit-card interest of 10% a year makes the debt grow every day.
- Amounts show in one currency you pick: US dollar, Israeli shekel, euro, Japanese yen, British pound, Chinese yuan, Australian dollar, Canadian dollar, Swiss franc, Hong Kong dollar or Singapore dollar. Switching currency changes the symbol only. The amounts stay the same.
- If you switch it on, Claude can add tasks, put them in order and set their rewards, one sentence per task. See "Letting Claude into your deck".

## A task

A task has a title, an optional note and an optional reward. A task without its own reward is worth the default from Settings (2 to start). The reward is locked in when you finish the task, so changing the default later doesn't touch what you've already earned.

The app also keeps, out of sight: when the task was made, how many times it's been put off, whether Claude added it, and when it was finished or deleted.

## Pages

Home fills the window. Icons in the top bar open Edit, History and Trash, and the reward badge in the top right opens Rewards. ⌘1 to ⌘5 switch between all five. Settings is the usual Mac settings window (⌘,).

### Home

The headline reads "This is what we need to get done now." with "Forget everything else." under it. Below that is the card: a NOW label, the reward as a small gift tag, the title in large type and the note underneath. Done and Later buttons sit under the card for when you'd rather click than drag.

Drag the card right and it tilts while a green DONE stamp fades in. Drag left for a LATER stamp. Let go before the threshold and it springs back. Keys: → or Return for done, ← for later, ⌘Z to undo, ⌘N for a new task.

When you finish a task, the card flies off and a few sparkles arc from it into the reward badge. The badge pulses, its gift wiggles, the number rolls up, and the amount you just earned floats under it for a moment. The next card fades in on its own, as if it were the only one.

Undo stays on screen until your next done, later or delete, even across quitting the app. It reverses whichever of those you did, reward included. There's one level of undo. History and Trash handle anything older.

New task (⌘N) asks for a title, note and reward, and whether it goes next or last. Last is the default.

From the third time you put off the same task, Home asks first: "You keep putting this one off. Make it smaller, or let it go." Split it turns it into up to three smaller tasks in its place. They share the original reward, so splitting never creates money. Let it go moves the task to the trash. Later anyway sends it to the bottom as usual.

Right-clicking the card gives Edit, Split and Delete.

When nothing is left: "That's everything. Nothing left to do." If you have rewards to spend, it adds "You have $42 in rewards. Go enjoy some of it."

### Edit

Every task as a block in a list, in deck order, with the top one marked NOW. The header shows how many there are ("23 tasks"). This is the only place that number appears.

Drag blocks to reorder, or right-click one for Edit, Split, Move to Top, Move to Bottom, Set Reward and Delete. Double-click a block to edit it. Click to select, ⌘-click to add to the selection, ⇧-click for a range; a bar then appears to move, reward or delete them all at once. Paste a list with ⌘V, or use Add a list, and each line becomes a task at the bottom, with bullets and checkboxes stripped. That's the quick way to bring tasks over from your notes.

Blocks show a "Put off 3×" marker once a task has been put off twice or more, and a small "Claude" mark if Claude added it.

### History

Finished tasks grouped by day, each day with its total ("Today · 3 done · $12 earned"). The top shows this week's count and earnings, and there's a search box. Restoring a task puts it back on top of the deck and takes its reward back off.

### Trash

Deleted tasks, newest first, each showing how long ago it was deleted. Restore puts a task back on top of the deck. Delete Forever and Empty Trash ask before acting. Tasks left in the trash for 30 days are deleted for good.

### Rewards

A large gift, your rewards in large type with "yours to spend on yourself" under it, and a Spend rewards button. Below are three tiles: total earned, total spent and total interest.

Spend rewards asks what you treated yourself to, how much, and the date (today unless you change it). If it would take you below zero, the sheet says by how much and reminds you of the interest rate before you confirm. Entries can be edited or deleted to fix mistakes. Spending history lists them newest first, with interest shown as one line per month ("Interest, October 2026") so you can see what being in the red cost you.

When you have rewards the page says "You earned this. Spend it without guilt." Below zero, the amount turns red, "owed" replaces "yours to spend", and the page says "You're $12.40 in the red, and interest is adding up. A few tasks will clear it. Interest is 10% a year, added daily." The badge in the top bar says "rewards" or "owed" to match.

### Settings

Default reward, currency, interest rate, the reward chime on or off, the Claude switch and its setup buttons, export and import of a backup file, and a button that shows the data file in Finder.

## Letting Claude into your deck

You can let Claude (Claude Code or the Claude desktop app) put tasks in your deck, arrange them and decide what they're worth. It's off until you turn on "Let Claude add tasks, order them and set rewards" in Settings.

Two setup buttons sit under the switch. "Add to Claude Code" copies a one-line command to paste into a terminal. "Add to Claude Desktop" adds One by One to the desktop app's config file. Both register the app as an MCP server, the standard way to give Claude tools. The app is its own server when started with a `--mcp` flag, so there's nothing else to install. Move the app into Applications before setting this up, because Claude remembers where the app was.

Claude gets four tools:

- `list_tasks` returns the deck in order, with each task's id, title, note and reward, plus your currency and default reward. The first task is marked as the one on screen.
- `add_tasks` adds one or more tasks, either right after the card on screen or at the bottom, each with an optional reward.
- `reorder_tasks` takes every task except the one on screen, in the new order.
- `set_values` sets the reward for one or more tasks, from 0 to 10,000.

Claude can't finish, delete or rename tasks, and it can't touch your spending or settings. When the switch is off, every tool refuses and tells Claude it can be turned on in Settings.

Each task Claude writes is one sentence of at most 120 characters, with no note. The app checks this itself and sends back anything longer with a message asking Claude to shorten it, so the rule holds no matter what Claude was asked to do. If any task in a batch breaks the rule, none of them are added.

The card on screen never changes under you. Claude's changes only affect the cards below it, and you meet them after you finish or put off the current one.

The app and the server share the one data file. Each side takes a lock, rereads the file, makes its change and writes the whole file at once. The app reloads when the file changes on disk.

## How the interest works

While your rewards are below zero, interest compounds once a day. Each day's charge is the debt × the yearly rate ÷ 365. The default rate is 10% a year. Setting it to 0% turns interest off. If the app was closed for a while, it charges the missed days on the next launch.

At 10%, a $100 debt costs about 3 cents a day, or roughly 83 cents a month. It's a nudge, not a punishment. If debt should sting more, raise the rate.

## Wording

The voice is calm and direct, like a friend who's good at getting things done. No exclamation marks, no emoji.

| When | Line |
|---|---|
| Home, always | This is what we need to get done now. Forget everything else. |
| After done (rotates) | Done. $5 added to your rewards. / That one's gone. You earned $5. / $5 earned. Now just this one. |
| After the last done | Done. $5 earned. That was the last one. |
| After later | Okay, later. Right now, this one. |
| After undo | Brought it back. |
| After delete | Moved to Trash. |
| After split | Smaller now. Start with this one. |
| Third put-off | You keep putting this one off. Make it smaller, or let it go. |
| Deck empty | That's everything. Nothing left to do. |
| First launch | Start with one thing. What needs doing? |
| Rewards, none yet | Finish a task to earn your first reward. |
| Rewards, positive | You earned this. Spend it without guilt. |
| Rewards, negative | You're $12.40 in the red, and interest is adding up. A few tasks will clear it. |

## Look and motion

The theme is called Paper: one window that follows the system's light or dark mode, with a warm off-white background in light mode. Cards have rounded corners and a soft shadow. Done is green. Rewards are always marigold running into coral, so they never read as a bank balance.

The app icon is the same idea in miniature: one white card with a green check, in front of two faint outlines of the rest of the deck.

Animation goes where it gives feedback: the card follows the pointer and tilts, the stamps fade in as you drag, the trackpad ticks when you pass the threshold, sparkles fly into the reward badge, the number rolls, and an undone card flies back in from the side it left by. With the Mac's Reduce Motion setting on, cards fade instead of flying and the sparkles are skipped.

A quiet chime (the Mac's Glass sound, at a quarter volume) plays when a reward lands. It can be turned off in Settings.

## Not in v1

- Snooze until a date, and repeating tasks. Snooze is the planned answer to tasks with deadlines and comes in v1.1.
- Savings goals on Rewards ("Saving for: headphones, $120"), also v1.1.
- Left out on purpose: sync, iPhone, accounts, notifications, tags, projects, due-date sorting and priority levels. Each one works against seeing one task at a time.
