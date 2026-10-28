# Keyboard and Unsaved Changes

Status: agreed; pending implementation.

## Keyboard Shortcuts

Use standard macOS application menus and the responder chain. Shortcuts apply while DayCue owns keyboard focus or its menu is open; they do not intercept shortcuts in other apps.

| Shortcut | Behavior |
| --- | --- |
| Command-Q | Quit DayCue and remove its menu bar item. |
| Command-W | Close the active sheet or window; keep DayCue running in the menu bar. |
| Escape | Cancel the active editor or dismiss a dialog according to its Cancel action. |
| Command-S | Save the active time-block editor. |
| Command-N | Add a time block while Schedule is active and no editor or dialog is open. |
| Command-C / X / V / A | Use standard copy, cut, paste, and select-all behavior in editable text controls. |

Enable commands only where their actions apply. Opening a dialog must not trigger commands in its underlying window.

## Unsaved Changes

- Before closing or quitting with a modified editor, ask whether to save the changes. An unchanged editor closes without a prompt.
- Apply this protection to Command-W, Command-Q, the window close button, and the Quit menu action.
- Use the title **Save Changes?** and the message **Your changes will be lost if you don’t save them.**

| Action | Result |
| --- | --- |
| Save | Validate and persist the draft, then complete the requested close or quit. Validation or save failure keeps the editor open and prevents closing or quitting. |
| Discard | Drop the draft and complete the requested close or quit. Leave the saved schedule unchanged. |
| Cancel | Stop closing or quitting and retain the draft. |

Escape in this confirmation means **Cancel** and retains the draft. The editor's own **Cancel** button or Escape outside this confirmation explicitly discards the draft and dismisses the editor without another prompt.
