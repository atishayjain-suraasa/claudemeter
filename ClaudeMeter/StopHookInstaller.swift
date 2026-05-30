import Foundation

enum StopHookInstaller {
    private static let settingsURL = URL.homeDirectory.appendingPathComponent(".claude/settings.json")
    private static let hookCommand = #"date +%s > "$HOME/Library/Application Support/ClaudeMeter/trigger" 2>/dev/null || true"#

    enum Status { case installed, notInstalled, readError }

    static func status() -> Status {
        guard
            let data = try? Data(contentsOf: settingsURL),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let hooks = root["hooks"] as? [String: Any],
            let stopGroups = hooks["Stop"] as? [[String: Any]]
        else { return .notInstalled }

        for group in stopGroups {
            guard let inner = group["hooks"] as? [[String: Any]] else { continue }
            for hook in inner {
                if let cmd = hook["command"] as? String, cmd.contains("ClaudeMeter") { return .installed }
            }
        }
        return .notInstalled
    }

    static func install() throws {
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = existing
        }

        let newGroup: [String: Any] = [
            "matcher": "",
            "hooks": [["type": "command", "command": hookCommand]]
        ]

        var hooks = root["hooks"] as? [String: Any] ?? [:]
        var stopGroups = hooks["Stop"] as? [[String: Any]] ?? []
        stopGroups.append(newGroup)
        hooks["Stop"] = stopGroups
        root["hooks"] = hooks

        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: settingsURL)
    }
}
