import CryptoKit
import Darwin
import Foundation
import Network
import Security

nonisolated enum PublicURLCheckFailure: Error, Equatable, Sendable {
    case cancelled
    case dnsFailed
    case dnsTimedOut
    case trustFailed
    case transportFailed
    case timedOut
    case malformedResponse
    case oversizedResponse
}

nonisolated struct PublicIPAddress: Equatable, Hashable, Sendable {
    enum Family: Sendable {
        case ipv4
        case ipv6
    }

    let literal: String
    let family: Family

    init?(_ literal: String) {
        var ipv4 = in_addr()
        if inet_pton(AF_INET, literal, &ipv4) == 1 {
            self.literal = literal
            family = .ipv4
            return
        }
        var ipv6 = in6_addr()
        if inet_pton(AF_INET6, literal, &ipv6) == 1 {
            self.literal = literal
            family = .ipv6
            return
        }
        return nil
    }

    var isPublic: Bool {
        switch family {
        case .ipv4:
            var address = in_addr()
            guard inet_pton(AF_INET, literal, &address) == 1 else { return false }
            let bytes = withUnsafeBytes(of: &address) { Array($0) }
            guard bytes.count == 4 else { return false }
            let first = Int(bytes[0])
            let second = Int(bytes[1])
            if first == 0 || first == 10 || first == 127 || first >= 224 { return false }
            if first == 100 && (64...127).contains(second) { return false }
            if first == 169 && second == 254 { return false }
            if first == 172 && (16...31).contains(second) { return false }
            if first == 192 && second == 0 { return false }
            if first == 192 && second == 168 { return false }
            if first == 192 && second == 0 && bytes[2] == 2 { return false }
            if first == 198 && (second == 18 || second == 19 || second == 51 && bytes[2] == 100) { return false }
            if first == 203 && second == 0 && bytes[2] == 113 { return false }
            return true
        case .ipv6:
            var address = in6_addr()
            guard inet_pton(AF_INET6, literal, &address) == 1 else { return false }
            let bytes = withUnsafeBytes(of: &address) { Array($0) }
            guard bytes.count == 16 else { return false }
            if bytes.allSatisfy({ $0 == 0 }) { return false }
            if bytes.dropLast().allSatisfy({ $0 == 0 }) && bytes.last == 1 { return false }
            if bytes[0] == 0xff || (bytes[0] & 0xfe) == 0xfc { return false }
            if bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80 { return false }
            if bytes.prefix(8).elementsEqual([0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]) { return false }
            if bytes.prefix(4).elementsEqual([0x20, 0x01, 0x0d, 0xb8]) { return false }
            if bytes.prefix(6).elementsEqual([0x20, 0x01, 0x00, 0x02, 0x00, 0x00]) { return false }
            if bytes.prefix(10).allSatisfy({ $0 == 0 }) && bytes[10] == 0xff && bytes[11] == 0xff {
                let mapped = bytes.suffix(4).map(String.init).joined(separator: ".")
                return PublicIPAddress(mapped)?.isPublic == true
            }
            return true
        }
    }
}

nonisolated struct PublicURLRequest: Equatable, Sendable {
    let originalURL: String
    let hostname: String
    let requestTarget: String

    var headerNames: [String] {
        ["Accept", "Connection", "Host", "Range", "User-Agent"]
    }

    var httpBytes: Data {
        let lines = [
            "GET \(requestTarget) HTTP/1.1",
            "Host: \(hostname)",
            "User-Agent: Rekon-Pursuit/0.1",
            "Accept: text/html, application/xhtml+xml, text/plain",
            "Range: bytes=0-524287",
            "Connection: close",
            "",
            ""
        ]
        return Data(lines.joined(separator: "\r\n").utf8)
    }
}

nonisolated struct PublicURLTransportResponse: Equatable, Sendable {
    let status: Int
    let headers: [String: String]
    let body: Data
    let truncated: Bool
}

enum PublicURLPreparation: Equatable {
    case malformed
    case ineligible(PublicURLCheckCompletion)
    case eligible(PublicURLRequest)
}

@MainActor
protocol PublicURLResolving {
    func resolve(hostname: String) async throws -> [PublicIPAddress]
}

@MainActor
protocol PublicURLTransporting {
    func perform(_ request: PublicURLRequest, peer: PublicIPAddress) async throws -> PublicURLTransportResponse
}

@MainActor
protocol PublicURLChecking {
    func prepare(_ savedURL: String) -> PublicURLPreparation
    func check(_ request: PublicURLRequest, opportunityTitle: String) async -> PublicURLCheckCompletion
}

@MainActor
final class PublicURLChecker: PublicURLChecking {
    fileprivate static let maximumBodyBytes = 524_288
    private let resolver: PublicURLResolving
    private let transport: PublicURLTransporting
    private let permits: PublicURLCheckPermitPool

    init(
        resolver: PublicURLResolving = SystemPublicURLResolver(),
        transport: PublicURLTransporting = NWPublicURLTransport(),
        permits: PublicURLCheckPermitPool = .shared
    ) {
        self.resolver = resolver
        self.transport = transport
        self.permits = permits
    }

    func prepare(_ savedURL: String) -> PublicURLPreparation {
        guard !savedURL.isEmpty,
              !savedURL.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              !savedURL.contains("\\"),
              let components = URLComponents(string: savedURL),
              components.scheme != nil,
              components.host != nil else {
            return .malformed
        }

        guard let scheme = components.scheme?.lowercased(),
              let rawHost = components.host?.lowercased(),
              !rawHost.isEmpty else {
            return .malformed
        }
        let host = rawHost.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let queryKeys = (components.queryItems ?? []).map { $0.name.lowercased() }
        let credentialKeys = ["password", "token", "auth", "session", "signature", "key", "code", "credential"]
        let prohibitedSource = host == "linkedin.com" || host.hasSuffix(".linkedin.com") ||
            host == "glassdoor.com" || host.hasSuffix(".glassdoor.com")
        let isLiteral = PublicIPAddress(host) != nil
        let ineligible = scheme != "https" ||
            components.user != nil ||
            components.password != nil ||
            (components.port != nil && components.port != 443) ||
            host == "localhost" ||
            host.hasSuffix(".local") ||
            !host.contains(".") ||
            isLiteral ||
            prohibitedSource ||
            queryKeys.contains(where: credentialKeys.contains)

        if ineligible {
            return .ineligible(Self.failed(
                evidence: "The saved posting URL is not eligible for a bounded public HTTPS check.",
                code: "url_ineligible"
            ))
        }

        let path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        let target = components.percentEncodedQuery.map { "\(path)?\($0)" } ?? path
        return .eligible(PublicURLRequest(originalURL: savedURL, hostname: host, requestTarget: target))
    }

    func check(_ request: PublicURLRequest, opportunityTitle: String) async -> PublicURLCheckCompletion {
        await permits.acquire()
        defer { permits.release() }
        do {
            try Task.checkCancellation()
            let addresses = try await resolver.resolve(hostname: request.hostname)
            guard !addresses.isEmpty, addresses.allSatisfy(\.isPublic) else {
                return Self.failed(
                    evidence: "The hostname did not resolve exclusively to public network addresses.",
                    code: addresses.isEmpty ? "dns_empty" : "unsafe_dns"
                )
            }
            try Task.checkCancellation()
            let response = try await transport.perform(
                request,
                peer: addresses.sorted { $0.literal < $1.literal }[0]
            )
            try Task.checkCancellation()
            return classify(response, request: request, opportunityTitle: opportunityTitle)
        } catch is CancellationError {
            return Self.cancelled()
        } catch let failure as PublicURLCheckFailure {
            if failure == .cancelled { return Self.cancelled() }
            return Self.failed(
                evidence: "The public posting check could not be completed safely.",
                code: failure.redactedCode
            )
        } catch {
            return Self.failed(
                evidence: "The public posting check could not be completed safely.",
                code: "source_failed"
            )
        }
    }

    private func classify(
        _ response: PublicURLTransportResponse,
        request: PublicURLRequest,
        opportunityTitle: String
    ) -> PublicURLCheckCompletion {
        let header = { (name: String) in
            response.headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
        }
        let mimeType = header("Content-Type")?
            .split(separator: ";", maxSplits: 1)
            .first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let declaredBytes = header("Content-Length").flatMap(Int.init)
        let technical = TechnicalEvidence(
            status: response.status,
            mimeType: mimeType,
            declaredBytes: declaredBytes,
            receivedBytes: response.body.count,
            contentSHA256: SHA256.hash(data: response.body).map { String(format: "%02x", $0) }.joined(),
            responseDate: boundedHeader(header("Date")),
            lastModified: boundedHeader(header("Last-Modified")),
            etag: boundedHeader(header("ETag")),
            retryAfter: boundedHeader(header("Retry-After"))
        )

        if (300...399).contains(response.status) {
            return completion(
                outcome: .needsManualReview,
                classification: .ambiguous,
                reason: .changedURL,
                confidence: nil,
                evidence: "The posting returned a redirect. Rekon Pursuit did not follow it.",
                technical: technical,
                redirectTarget: redactedRedirect(header("Location"), relativeTo: request.originalURL)
            )
        }
        if [401, 403, 407, 429, 451].contains(response.status) {
            return completion(
                outcome: .needsManualReview,
                classification: .failed,
                reason: .accessBlocked,
                confidence: nil,
                evidence: "The posting response blocked or limited public access.",
                technical: technical,
                errorCode: "access_blocked"
            )
        }
        if response.status == 404 || response.status == 410 {
            return completion(
                outcome: .possiblyClosed,
                classification: .ambiguous,
                reason: .manualReview,
                confidence: .low,
                evidence: "The posting returned HTTP \(response.status); status alone is not closure proof.",
                technical: technical
            )
        }
        guard (200...299).contains(response.status) else {
            return Self.failed(
                evidence: "The posting returned HTTP \(response.status), which is not usable closure evidence.",
                code: "http_failure",
                technical: technical
            )
        }
        guard response.body.count <= Self.maximumBodyBytes else {
            return Self.failed(evidence: "The posting response exceeded the bounded evidence limit.", code: "oversized_response", technical: technical)
        }
        guard let mimeType,
              ["text/html", "application/xhtml+xml", "text/plain"].contains(mimeType),
              contentTypeIsUTF8(header("Content-Type")),
              let body = String(data: response.body, encoding: .utf8) else {
            return Self.failed(evidence: "The posting response format is not supported for local review.", code: "unsupported_response", technical: technical)
        }

        let metaRefresh = metaRefreshEvidence(in: body, relativeTo: request.originalURL)
        if metaRefresh.found {
            return completion(
                outcome: .needsManualReview,
                classification: .ambiguous,
                reason: .changedURL,
                confidence: nil,
                evidence: "The posting contained a meta refresh. Rekon Pursuit did not follow it.",
                technical: technical,
                redirectTarget: metaRefresh.target
            )
        }

        let visible = normalizedVisibleText(body)
        let visibleLower = visible.lowercased()
        let accessMarkers = ["access denied", "captcha", "verify you are human", "robot check", "sign in to continue", "log in to continue"]
        if accessMarkers.contains(where: visibleLower.contains) {
            return completion(
                outcome: .needsManualReview,
                classification: .failed,
                reason: .accessBlocked,
                confidence: nil,
                evidence: "The visible response presented an access challenge instead of public posting evidence.",
                technical: technical,
                errorCode: "access_blocked"
            )
        }
        let normalizedTitle = normalize(opportunityTitle)
        let activeMarkers = ["apply now", "apply for this job", "submit application", "submit your application"]
        let closureMarkers = ["this job is no longer available", "position has been filled", "job has expired", "applications are no longer being accepted"]
        let matchingActive = activeMarkers.filter(visibleLower.contains)
        let matchingClosure = closureMarkers.filter(visibleLower.contains)
        let titleMatches = !normalizedTitle.isEmpty && visibleLower.contains(normalizedTitle)
        let ambiguous = response.truncated ||
            !titleMatches ||
            (matchingActive.isEmpty == matchingClosure.isEmpty)

        guard !ambiguous else {
            return completion(
                outcome: .needsManualReview,
                classification: .ambiguous,
                reason: .manualReview,
                confidence: nil,
                evidence: response.truncated
                    ? "The bounded response was truncated, so no opening status was inferred."
                    : "The visible posting evidence did not satisfy one unambiguous title-and-marker match.",
                technical: technical,
                excerpt: evidenceExcerpt(visible, marker: matchingActive.first ?? matchingClosure.first)
            )
        }
        if let marker = matchingActive.first {
            return completion(
                outcome: .stillOpen,
                classification: .confirmed,
                reason: .manualReview,
                confidence: .high,
                evidence: "The visible posting title and active application marker matched.",
                technical: technical,
                excerpt: evidenceExcerpt(visible, marker: marker)
            )
        }
        let marker = matchingClosure[0]
        return completion(
            outcome: .closedSuggested,
            classification: .confirmed,
            reason: .manualReview,
            confidence: .high,
            evidence: "The visible posting title and closure marker matched. Closure still requires confirmation.",
            technical: technical,
            excerpt: evidenceExcerpt(visible, marker: marker)
        )
    }

    private static func failed(
        evidence: String,
        code: String,
        technical: TechnicalEvidence? = nil
    ) -> PublicURLCheckCompletion {
        PublicURLCheckCompletion(
            terminalState: .failed,
            outcome: .needsManualReview,
            classification: .failed,
            reason: .sourceFailed,
            evidence: evidence,
            httpStatus: technical?.status,
            mimeType: technical?.mimeType,
            declaredBytes: technical?.declaredBytes,
            receivedBytes: technical?.receivedBytes,
            contentSHA256: technical?.contentSHA256,
            responseDate: technical?.responseDate,
            lastModified: technical?.lastModified,
            etag: technical?.etag,
            retryAfter: technical?.retryAfter,
            redactedErrorCode: code
        )
    }

    private static func cancelled() -> PublicURLCheckCompletion {
        PublicURLCheckCompletion(
            terminalState: .cancelled,
            outcome: .needsManualReview,
            classification: .failed,
            reason: .sourceFailed,
            evidence: "The public posting check was cancelled before completion.",
            redactedErrorCode: "cancelled"
        )
    }

    private func completion(
        outcome: ReconciliationOutcome,
        classification: ReconciliationClassification,
        reason: ReconciliationReason,
        confidence: ReconciliationConfidence?,
        evidence: String,
        technical: TechnicalEvidence,
        redirectTarget: String? = nil,
        excerpt: String? = nil,
        errorCode: String? = nil
    ) -> PublicURLCheckCompletion {
        PublicURLCheckCompletion(
            terminalState: .completed,
            outcome: outcome,
            classification: classification,
            reason: reason,
            confidence: confidence,
            evidence: evidence,
            httpStatus: technical.status,
            mimeType: technical.mimeType,
            declaredBytes: technical.declaredBytes,
            receivedBytes: technical.receivedBytes,
            contentSHA256: technical.contentSHA256,
            responseDate: technical.responseDate,
            lastModified: technical.lastModified,
            etag: technical.etag,
            retryAfter: technical.retryAfter,
            redirectTargetRedacted: redirectTarget,
            evidenceExcerpt: excerpt,
            redactedErrorCode: errorCode
        )
    }

    private func boundedHeader(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : String(cleaned.prefix(256))
    }

    private func contentTypeIsUTF8(_ value: String?) -> Bool {
        guard let value else { return false }
        let lower = value.lowercased()
        return !lower.contains("charset=") || lower.contains("charset=utf-8") || lower.contains("charset=\"utf-8\"")
    }

    private func normalizedVisibleText(_ html: String) -> String {
        var visible = replacingRegex("(?is)<(script|style)\\b[^>]*>.*?</\\1>", in: html, with: " ")
        visible = replacingRegex("(?is)<!--.*?-->", in: visible, with: " ")
        visible = replacingRegex("(?is)<[^>]+>", in: visible, with: " ")
        for (entity, replacement) in [
            ("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'")
        ] {
            visible = visible.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }
        return normalize(visible)
    }

    private func normalize(_ value: String) -> String {
        value
            .precomposedStringWithCanonicalMapping
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func replacingRegex(_ pattern: String, in value: String, with replacement: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return value }
        let range = NSRange(value.startIndex..., in: value)
        return expression.stringByReplacingMatches(in: value, range: range, withTemplate: replacement)
    }

    private func evidenceExcerpt(_ visible: String, marker: String?) -> String? {
        guard let marker, let range = visible.range(of: marker, options: .caseInsensitive) else { return nil }
        let markerOffset = visible.distance(from: visible.startIndex, to: range.lowerBound)
        let startOffset = max(0, markerOffset - 220)
        let endOffset = min(visible.count, markerOffset + marker.count + 220)
        let start = visible.index(visible.startIndex, offsetBy: startOffset)
        let end = visible.index(visible.startIndex, offsetBy: endOffset)
        return String(visible[start..<end].prefix(512))
    }

    private func metaRefreshEvidence(in html: String, relativeTo base: String) -> (found: Bool, target: String?) {
        guard let expression = try? NSRegularExpression(pattern: "(?is)<meta\\b[^>]*>") else { return (false, nil) }
        let nsRange = NSRange(html.startIndex..., in: html)
        for match in expression.matches(in: html, range: nsRange) {
            guard let range = Range(match.range, in: html) else { continue }
            let tag = String(html[range])
            let lower = tag.lowercased()
            guard lower.contains("http-equiv"), lower.contains("refresh") else { continue }
            guard let urlExpression = try? NSRegularExpression(pattern: "(?i)url\\s*=\\s*['\\\"]?([^'\\\";>\\s]+)"),
                  let urlMatch = urlExpression.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
                  let targetRange = Range(urlMatch.range(at: 1), in: tag) else {
                return (true, nil)
            }
            return (true, redactedRedirect(String(tag[targetRange]), relativeTo: base))
        }
        return (false, nil)
    }

    private func redactedRedirect(_ target: String?, relativeTo base: String) -> String? {
        guard let target,
              let baseURL = URL(string: base),
              let resolved = URL(string: target, relativeTo: baseURL)?.absoluteURL,
              var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              !host.isEmpty else {
            return nil
        }
        components.scheme = "https"
        components.host = host
        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        components.percentEncodedPath = String(components.percentEncodedPath.prefix(256))
        return components.string
    }
}

private struct TechnicalEvidence {
    let status: Int
    let mimeType: String?
    let declaredBytes: Int?
    let receivedBytes: Int
    let contentSHA256: String
    let responseDate: String?
    let lastModified: String?
    let etag: String?
    let retryAfter: String?
}

@MainActor
final class PublicURLCheckPermitPool {
    static let shared = PublicURLCheckPermitPool(limit: 2)

    private let limit: Int
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = limit
    }

    func acquire() async {
        if active < limit {
            active += 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if waiters.isEmpty {
            active -= 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}

@MainActor
final class SystemPublicURLResolver: PublicURLResolving {
    func resolve(hostname: String) async throws -> [PublicIPAddress] {
        try await PublicURLResolverRace.resolve(hostname: hostname, timeout: 5)
    }
}

nonisolated private final class PublicURLResolverRace: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false
    private var continuation: CheckedContinuation<[PublicIPAddress], Error>?

    static func resolve(hostname: String, timeout: TimeInterval) async throws -> [PublicIPAddress] {
        let race = PublicURLResolverRace()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                race.continuation = continuation
                DispatchQueue.global(qos: .userInitiated).async {
                    race.finish(with: Result { try resolveSynchronously(hostname: hostname) })
                }
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) {
                    race.finish(with: .failure(PublicURLCheckFailure.dnsTimedOut))
                }
            }
        } onCancel: {
            race.finish(with: .failure(PublicURLCheckFailure.cancelled))
        }
    }

    private static func resolveSynchronously(hostname: String) throws -> [PublicIPAddress] {
        var hints = addrinfo(
            ai_flags: AI_ADDRCONFIG,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(hostname, "443", &hints, &result) == 0, let first = result else {
            throw PublicURLCheckFailure.dnsFailed
        }
        defer { freeaddrinfo(first) }
        var addresses: Set<PublicIPAddress> = []
        var cursor: UnsafeMutablePointer<addrinfo>? = first
        while let current = cursor {
            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                current.pointee.ai_addr,
                current.pointee.ai_addrlen,
                &hostBuffer,
                socklen_t(hostBuffer.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0,
               let terminator = hostBuffer.firstIndex(of: 0),
               let address = PublicIPAddress(String(decoding: hostBuffer[..<terminator].map(UInt8.init(bitPattern:)), as: UTF8.self)) {
                addresses.insert(address)
            }
            cursor = current.pointee.ai_next
        }
        return Array(addresses)
    }

    private func finish(with result: Result<[PublicIPAddress], Error>) {
        lock.lock()
        guard !resumed, let continuation else {
            lock.unlock()
            return
        }
        resumed = true
        self.continuation = nil
        lock.unlock()
        continuation.resume(with: result)
    }
}

@MainActor
final class NWPublicURLTransport: PublicURLTransporting {
    func perform(_ request: PublicURLRequest, peer: PublicIPAddress) async throws -> PublicURLTransportResponse {
        try await BoundHTTPConnection(request: request, peer: peer).run()
    }
}

nonisolated private final class BoundHTTPConnection: @unchecked Sendable {
    private static let maximumHeaderBytes = 65_536
    private static let maximumWireBytes = 590_000
    private static let maximumBodyBytes = 524_288
    private let request: PublicURLRequest
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.rekonlabs.RekonPursuit.public-url-check")
    private let lock = NSLock()
    private var continuation: CheckedContinuation<PublicURLTransportResponse, Error>?
    private var completed = false
    private var buffer = Data()

    init(request: PublicURLRequest, peer: PublicIPAddress) {
        self.request = request
        let tls = NWProtocolTLS.Options()
        sec_protocol_options_set_tls_server_name(tls.securityProtocolOptions, request.hostname)
        sec_protocol_options_add_tls_application_protocol(tls.securityProtocolOptions, "http/1.1")
        sec_protocol_options_set_verify_block(
            tls.securityProtocolOptions,
            { _, trust, complete in
                let secTrust = sec_trust_copy_ref(trust).takeRetainedValue()
                SecTrustSetPolicies(secTrust, SecPolicyCreateSSL(true, request.hostname as CFString))
                complete(SecTrustEvaluateWithError(secTrust, nil))
            },
            queue
        )
        let parameters = NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
        connection = NWConnection(
            host: NWEndpoint.Host(peer.literal),
            port: NWEndpoint.Port(integerLiteral: 443),
            using: parameters
        )
    }

    func run() async throws -> PublicURLTransportResponse {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                self.continuation = continuation
                lock.unlock()
                connection.stateUpdateHandler = { [weak self] state in
                    self?.handle(state)
                }
                connection.start(queue: queue)
                queue.asyncAfter(deadline: .now() + 10) { [weak self] in
                    self?.finish(.failure(PublicURLCheckFailure.timedOut))
                }
            }
        } onCancel: {
            finish(.failure(PublicURLCheckFailure.cancelled))
        }
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            connection.send(content: request.httpBytes, completion: .contentProcessed { [weak self] error in
                guard let self else { return }
                if error == nil {
                    receive()
                } else {
                    finish(.failure(PublicURLCheckFailure.transportFailed))
                }
            })
        case .failed:
            finish(.failure(PublicURLCheckFailure.trustFailed))
        case .cancelled:
            finish(.failure(PublicURLCheckFailure.cancelled))
        default:
            break
        }
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data { buffer.append(data) }
            if buffer.count > Self.maximumWireBytes {
                finish(.failure(PublicURLCheckFailure.oversizedResponse))
                return
            }
            if let error {
                _ = error
                finish(.failure(PublicURLCheckFailure.transportFailed))
            } else if isComplete {
                finish(Result { try Self.parse(buffer) })
            } else {
                receive()
            }
        }
    }

    private func finish(_ result: Result<PublicURLTransportResponse, Error>) {
        lock.lock()
        guard !completed, let continuation else {
            lock.unlock()
            return
        }
        completed = true
        self.continuation = nil
        lock.unlock()
        connection.stateUpdateHandler = nil
        connection.cancel()
        continuation.resume(with: result)
    }

    private static func parse(_ data: Data) throws -> PublicURLTransportResponse {
        let delimiter = Data("\r\n\r\n".utf8)
        guard let headerRange = data.range(of: delimiter),
              headerRange.lowerBound <= maximumHeaderBytes,
              let headerText = String(data: data[..<headerRange.lowerBound], encoding: .utf8) else {
            throw PublicURLCheckFailure.malformedResponse
        }
        let lines = headerText.components(separatedBy: "\r\n")
        guard let statusLine = lines.first,
              statusLine.hasPrefix("HTTP/1."),
              let status = Int(statusLine.split(separator: " ").dropFirst().first ?? "") else {
            throw PublicURLCheckFailure.malformedResponse
        }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else {
                throw PublicURLCheckFailure.malformedResponse
            }
            let name = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !value.contains("\r"), !value.contains("\n") else {
                throw PublicURLCheckFailure.malformedResponse
            }
            headers[name] = value
        }
        let encodedBody = Data(data[headerRange.upperBound...])
        let transferEncoding = headers.first { $0.key.caseInsensitiveCompare("Transfer-Encoding") == .orderedSame }?.value.lowercased()
        let decoded = transferEncoding?.contains("chunked") == true ? try decodeChunked(encodedBody) : encodedBody
        guard decoded.count <= maximumBodyBytes else {
            throw PublicURLCheckFailure.oversizedResponse
        }
        let contentRange = headers.first { $0.key.caseInsensitiveCompare("Content-Range") == .orderedSame }?.value
        let declaredBytes = headers.first { $0.key.caseInsensitiveCompare("Content-Length") == .orderedSame }.flatMap { Int($0.value) }
        let truncated = contentRange != nil || (declaredBytes ?? 0) > decoded.count
        return PublicURLTransportResponse(
            status: status,
            headers: headers,
            body: decoded,
            truncated: truncated
        )
    }

    private static func decodeChunked(_ data: Data) throws -> Data {
        var cursor = data.startIndex
        var output = Data()
        let lineBreak = Data("\r\n".utf8)
        while cursor < data.endIndex {
            guard let sizeRange = data[cursor...].range(of: lineBreak),
                  let sizeText = String(data: data[cursor..<sizeRange.lowerBound], encoding: .utf8),
                  let size = Int(sizeText.split(separator: ";", maxSplits: 1)[0], radix: 16) else {
                throw PublicURLCheckFailure.malformedResponse
            }
            cursor = sizeRange.upperBound
            if size == 0 { return output }
            guard size >= 0, data.distance(from: cursor, to: data.endIndex) >= size + 2 else {
                throw PublicURLCheckFailure.malformedResponse
            }
            let end = data.index(cursor, offsetBy: size)
            output.append(data[cursor..<end])
            guard data[end..<data.index(end, offsetBy: 2)] == lineBreak else {
                throw PublicURLCheckFailure.malformedResponse
            }
            cursor = data.index(end, offsetBy: 2)
            if output.count > maximumBodyBytes {
                return output
            }
        }
        throw PublicURLCheckFailure.malformedResponse
    }
}

private extension PublicURLCheckFailure {
    var redactedCode: String {
        switch self {
        case .cancelled: "cancelled"
        case .dnsFailed: "dns_failed"
        case .dnsTimedOut: "dns_timeout"
        case .trustFailed: "trust_failed"
        case .transportFailed: "transport_failed"
        case .timedOut: "request_timeout"
        case .malformedResponse: "malformed_response"
        case .oversizedResponse: "oversized_response"
        }
    }
}
