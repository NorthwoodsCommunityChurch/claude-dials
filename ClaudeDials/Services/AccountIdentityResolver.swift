import Foundation

/// Resolves an account's identity (email / org) by reading the `oauthAccount`
/// block from the profile's `.claude.json` — the default profile uses
/// `~/.claude.json`, a `CLAUDE_CONFIG_DIR` profile uses `<configDir>/.claude.json`.
///
/// Reads the file directly rather than shelling out to `claude auth status`:
/// launching the full Claude CLI as a subprocess does heavy startup work and can
/// hang a refresh. A plain file read is instant and can't block.
enum AccountIdentityResolver {

    static func resolve(configDir: String?) -> AccountIdentity? {
        let base: String
        if let configDir, !configDir.isEmpty {
            base = (configDir as NSString).expandingTildeInPath
        } else {
            base = NSHomeDirectory()
        }
        let path = (base as NSString).appendingPathComponent(".claude.json")

        guard let data = FileManager.default.contents(atPath: path),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = root["oauthAccount"] as? [String: Any] else {
            return nil
        }
        return AccountIdentity(
            email: oauth["emailAddress"] as? String,
            orgName: oauth["organizationName"] as? String,
            subscriptionType: oauth["organizationType"] as? String
        )
    }
}
