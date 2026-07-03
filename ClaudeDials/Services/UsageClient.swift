import Foundation

/// Calls the unofficial usage endpoint that powers Claude Code's `/usage` screen.
///
/// ⚠️ Unofficial surface. Endpoint, headers, response shape, and Keychain layout
/// are all reverse-engineered implementation details Anthropic can change without
/// notice. Every failure mode (401 / 403 / 429 / schema drift) is treated as an
/// expected degraded state, not a crash.
enum UsageClient {

    enum ClientError: Error {
        case tokenExpired
        case unauthorized          // 401/403
        case rateLimited           // 429
        case server(Int)
        case malformed
        case transport(Error)
    }

    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private static let betaHeader = "oauth-2025-04-20"

    /// Fetches usage for an account's credential. The `claude-code/<version>`
    /// User-Agent is REQUIRED — without it the endpoint routes to an aggressively
    /// rate-limited bucket (persistent 429s).
    static func fetchUsage(using credential: ClaudeCredential) async throws -> AccountUsage {
        if credential.isExpired { throw ClientError.tokenExpired }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue(ClaudeCodeVersion.userAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClientError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else { throw ClientError.malformed }
        switch http.statusCode {
        case 200:          break
        case 401, 403:     throw ClientError.unauthorized
        case 429:          throw ClientError.rateLimited
        case 500...599:    throw ClientError.server(http.statusCode)
        default:           throw ClientError.server(http.statusCode)
        }

        return try parse(data)
    }

    // MARK: - Parsing (tolerant of missing/unknown fields)

    private static func parse(_ data: Data) throws -> AccountUsage {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClientError.malformed
        }
        return AccountUsage(
            session: window(root["five_hour"]),
            week: window(root["seven_day"]),
            modelWeeklyLimits: modelWeeklyLimits(root)
        )
    }

    private static func window(_ value: Any?) -> UsageWindow? {
        guard let dict = value as? [String: Any] else { return nil }
        guard let util = (dict["utilization"] as? NSNumber)?.doubleValue else { return nil }
        return UsageWindow(utilization: util, resetsAt: parseDate(dict["resets_at"]))
    }

    /// Reads whichever per-model weekly caps the account currently has, from the
    /// `limits[]` array (`kind == "weekly_scoped"`). Anthropic decides server-side
    /// which model(s) get their own scoped limit — today that's Fable; historically
    /// it was Opus via a dedicated `seven_day_opus` field. Sorted worst-first so the
    /// tightest constraint is most visible. Falls back to the legacy top-level
    /// `seven_day_opus` / `seven_day_sonnet` fields if `limits[]` isn't present at
    /// all, in case an older account shape is still being served.
    private static func modelWeeklyLimits(_ root: [String: Any]) -> [ModelWeeklyLimit] {
        if let limits = root["limits"] as? [[String: Any]] {
            return limits
                .compactMap { entry -> ModelWeeklyLimit? in
                    guard
                        entry["kind"] as? String == "weekly_scoped",
                        let scope = entry["scope"] as? [String: Any],
                        let model = scope["model"] as? [String: Any],
                        let name = model["display_name"] as? String,
                        let percent = (entry["percent"] as? NSNumber)?.doubleValue
                    else { return nil }
                    let window = UsageWindow(utilization: percent, resetsAt: parseDate(entry["resets_at"]))
                    return ModelWeeklyLimit(modelName: name, window: window)
                }
                .sorted { $0.window.utilization > $1.window.utilization }
        }

        return [
            ("Opus", root["seven_day_opus"]),
            ("Sonnet", root["seven_day_sonnet"]),
        ].compactMap { name, value in
            window(value).map { ModelWeeklyLimit(modelName: name, window: $0) }
        }
    }

    private static func parseDate(_ value: Any?) -> Date? {
        guard let s = value as? String else { return nil }
        return ISO8601DateFormatter.shared.date(from: s)
            ?? ISO8601DateFormatter.sharedWithFractional.date(from: s)
    }
}

private extension ISO8601DateFormatter {
    // Parsing on ISO8601DateFormatter is thread-safe; the type just isn't Sendable-typed.
    nonisolated(unsafe) static let shared = ISO8601DateFormatter()
    nonisolated(unsafe) static let sharedWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

/// Resolves a plausible `claude-code/<version>` User-Agent. Reads the highest
/// installed Claude Code version directory so the UA tracks the user's real
/// install, with a verified fallback if discovery fails.
enum ClaudeCodeVersion {
    static let fallback = "2.1.147"

    static let userAgent: String = "claude-code/\(resolve())"

    private static func resolve() -> String {
        let dir = (NSHomeDirectory() as NSString)
            .appendingPathComponent(".local/share/claude/versions")
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dir),
              !entries.isEmpty else { return fallback }
        // Highest semantic version by component comparison.
        let highest = entries
            .filter { $0.first?.isNumber == true }
            .max { lhs, rhs in
                lhs.compare(rhs, options: .numeric) == .orderedAscending
            }
        return highest ?? fallback
    }
}
