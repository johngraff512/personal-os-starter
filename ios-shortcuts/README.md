# iOS Shortcuts

The reference setup uses three Apple Shortcuts for frictionless capture. Export your own from the Shortcuts app (Share → Export) and drop the `.shortcut` files here so adopters can import and re-point the file paths.

| Shortcut | Trigger | What it does | Writes to |
|---|---|---|---|
| **Add to [KB]** | Share Sheet (any app) | Prompts "Personal or Work?", appends the shared URL | `<vault>/aa-inbox/urls.txt` |
| **[KB] Idea (Personal)** | Siri voice | Prepends `- HH:MM`, appends the dictated thought | `personal/ideas.md` |
| **[KB] Idea (Work)** | Siri voice | Same, work vault | `work/ideas.md` |

See [`../docs/BUILD-GUIDE.md`](../docs/BUILD-GUIDE.md) §2.1 for how to build these and §2.2 for why they must target the iCloud "transit vault," not the repo directly.

> **Note:** the shortcut's *name* is the Siri phrase (iOS no longer records custom phrases separately), so name each shortcut what you'll say. The most common breakage is the "Append to Text File" picker dropping the wrong path — see §2.1 "Caveats."

*(Placeholder — add your exported `.shortcut` files and a screenshot or two.)*
