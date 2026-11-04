import AppKit

/// A menu bar app has no menu bar of its own, so ⌘V, ⌘C, ⌘X, ⌘A and ⌘Z found no Edit menu to go through: a text field
/// took what was typed, never what was pasted (the session key in Settings). This Edit menu is never shown, the app
/// being an accessory, but its key equivalents reach the field being edited.
@MainActor
enum EditMenu {
    static func make() -> NSMenu {
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z").keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let item = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        item.submenu = edit
        let main = NSMenu(title: "Main")
        main.addItem(item)
        return main
    }

    /// The app's main menu, unless it already has an Edit menu with Paste.
    static func install(on app: NSApplication) {
        let hasPaste = app.mainMenu?.items.contains { item in
            item.submenu?.items.contains { $0.action == #selector(NSText.paste(_:)) } ?? false
        } ?? false
        guard !hasPaste else { return }
        app.mainMenu = make()
    }
}
