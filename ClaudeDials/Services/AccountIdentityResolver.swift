import Foundation

/// Resolves the logged-in account's identity (email / org) by reading the
/// `oauthAccount` block from `~/.claude.json` — the file Claude Code writes for
/// the default login.
///
/// Reads the file directly rather than shelling out to `claude auth status`:
/// launching the full Claude CLI as a subprocess does heavy startup work and can
/// hang. A plain file read is instant, can't block, and is cheap enough to run
/// every poll so the name always reflects whoever is currently logged in.
enum AccountIdentityResolver {

    static func resolve() -> AccountIdentity? {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(".claude.json")

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
