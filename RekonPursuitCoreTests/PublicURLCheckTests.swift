import XCTest
@testable import RekonPursuit

@MainActor
final class PublicURLCheckTests: XCTestCase {
    func testPreparationSeparatesMalformedURLsFromValidButIneligibleURLs() {
        let checker = PublicURLChecker(
            resolver: FixturePublicURLResolver(result: .success([])),
            transport: FixturePublicURLTransport(result: .failure(.transportFailed))
        )

        if case .malformed = checker.prepare("not a URL") {
            // Expected: malformed values must not create a durable operation.
        } else {
            XCTFail("Expected a malformed URL")
        }

        for value in [
            "http://jobs.example.com/role",
            "https://localhost/role",
            "https://jobs.example.com:8443/role",
            "https://jobs.example.com/role?token=secret",
            "https://www.linkedin.com/jobs/view/123",
            "https://10.0.0.1/role"
        ] {
            guard case let .ineligible(completion) = checker.prepare(value) else {
                XCTFail("Expected \(value) to be valid but ineligible")
                continue
            }
            XCTAssertEqual(completion.outcome, .needsManualReview)
            XCTAssertEqual(completion.classification, .failed)
            XCTAssertEqual(completion.reason, .sourceFailed)
        }
    }

    func testUnsafeDNSAnswerPreventsTransport() async {
        let resolver = FixturePublicURLResolver(
            result: .success([
                PublicIPAddress("93.184.216.34")!,
                PublicIPAddress("127.0.0.1")!
            ])
        )
        let transport = FixturePublicURLTransport(
            result: .success(.html(status: 200, body: "Platform Engineer Apply now"))
        )
        let checker = PublicURLChecker(resolver: resolver, transport: transport)
        let request = try! XCTUnwrap(checker.prepareEligible("https://jobs.example.com/role"))

        let completion = await checker.check(request, opportunityTitle: "Platform Engineer")

        XCTAssertEqual(completion.outcome, .needsManualReview)
        XCTAssertEqual(completion.classification, .failed)
        XCTAssertEqual(completion.redactedErrorCode, "unsafe_dns")
        XCTAssertEqual(transport.requestCount, 0)
    }

    func testActivePostingRecordsConfirmedStillOpenWithOneRequest() async {
        let resolver = FixturePublicURLResolver(result: .success([PublicIPAddress("93.184.216.34")!]))
        let transport = FixturePublicURLTransport(
            result: .success(.html(
                status: 200,
                headers: ["Date": "Sat, 25 Jul 2026 20:00:00 GMT", "Set-Cookie": "do-not-store=1"],
                body: "<html><body><h1>Platform Engineer</h1><button>Apply now</button></body></html>"
            ))
        )
        let checker = PublicURLChecker(resolver: resolver, transport: transport)
        let request = try! XCTUnwrap(checker.prepareEligible("https://jobs.example.com/role"))

        let completion = await checker.check(request, opportunityTitle: "Platform Engineer")

        XCTAssertEqual(completion.outcome, .stillOpen)
        XCTAssertEqual(completion.classification, .confirmed)
        XCTAssertEqual(completion.httpStatus, 200)
        XCTAssertEqual(completion.responseDate, "Sat, 25 Jul 2026 20:00:00 GMT")
        XCTAssertNil(completion.etag)
        XCTAssertEqual(transport.requestCount, 1)
        XCTAssertEqual(transport.lastRequest?.headerNames, ["Accept", "Connection", "Host", "User-Agent"])
    }

    func testClosureMarkerSuggestsClosureWithoutClosingAnything() async {
        let checker = PublicURLChecker(
            resolver: FixturePublicURLResolver(result: .success([PublicIPAddress("93.184.216.34")!])),
            transport: FixturePublicURLTransport(
                result: .success(.html(status: 200, body: "<h1>Platform Engineer</h1><p>This job is no longer available.</p>"))
            )
        )
        let request = try! XCTUnwrap(checker.prepareEligible("https://jobs.example.com/role"))

        let completion = await checker.check(request, opportunityTitle: "Platform Engineer")

        XCTAssertEqual(completion.outcome, .closedSuggested)
        XCTAssertEqual(completion.classification, .confirmed)
        XCTAssertNotNil(completion.evidenceExcerpt)
        XCTAssertNotNil(completion.contentSHA256)
    }

    func testRedirectIsTerminalAndStoresOnlyRedactedTarget() async {
        let transport = FixturePublicURLTransport(
            result: .success(PublicURLTransportResponse(
                status: 302,
                headers: ["Location": "/new-role?token=secret#application"],
                body: Data(),
                truncated: false
            ))
        )
        let checker = PublicURLChecker(
            resolver: FixturePublicURLResolver(result: .success([PublicIPAddress("93.184.216.34")!])),
            transport: transport
        )
        let request = try! XCTUnwrap(checker.prepareEligible("https://jobs.example.com/old-role"))

        let completion = await checker.check(request, opportunityTitle: "Platform Engineer")

        XCTAssertEqual(completion.outcome, .needsManualReview)
        XCTAssertEqual(completion.classification, .ambiguous)
        XCTAssertEqual(completion.reason, .changedURL)
        XCTAssertEqual(completion.redirectTargetRedacted, "https://jobs.example.com/new-role")
        XCTAssertEqual(transport.requestCount, 1)
    }

    func testStatusAndAccessFailuresUseConservativeMappings() async {
        for (status, outcome, reason) in [
            (404, ReconciliationOutcome.possiblyClosed, ReconciliationReason.manualReview),
            (410, ReconciliationOutcome.possiblyClosed, ReconciliationReason.manualReview),
            (403, ReconciliationOutcome.needsManualReview, ReconciliationReason.accessBlocked),
            (429, ReconciliationOutcome.needsManualReview, ReconciliationReason.accessBlocked),
            (503, ReconciliationOutcome.needsManualReview, ReconciliationReason.sourceFailed)
        ] {
            let checker = PublicURLChecker(
                resolver: FixturePublicURLResolver(result: .success([PublicIPAddress("93.184.216.34")!])),
                transport: FixturePublicURLTransport(result: .success(.html(status: status, body: "")))
            )
            let request = try! XCTUnwrap(checker.prepareEligible("https://jobs.example.com/role"))
            let completion = await checker.check(request, opportunityTitle: "Platform Engineer")
            XCTAssertEqual(completion.outcome, outcome)
            XCTAssertEqual(completion.reason, reason)
        }
    }

    func testTruncatedOrScriptOnlyEvidenceStaysAmbiguous() async {
        for response in [
            PublicURLTransportResponse.html(
                status: 200,
                body: "<script>Platform Engineer Apply now</script><p>Careers</p>"
            ),
            PublicURLTransportResponse.html(
                status: 200,
                body: "<h1>Platform Engineer</h1><p>Apply now</p>",
                truncated: true
            )
        ] {
            let checker = PublicURLChecker(
                resolver: FixturePublicURLResolver(result: .success([PublicIPAddress("93.184.216.34")!])),
                transport: FixturePublicURLTransport(result: .success(response))
            )
            let request = try! XCTUnwrap(checker.prepareEligible("https://jobs.example.com/role"))
            let completion = await checker.check(request, opportunityTitle: "Platform Engineer")
            XCTAssertEqual(completion.outcome, .needsManualReview)
            XCTAssertEqual(completion.classification, .ambiguous)
        }
    }

    func testMetaRefreshWithoutUsableTargetIsStillChangedURL() async {
        let checker = PublicURLChecker(
            resolver: FixturePublicURLResolver(result: .success([PublicIPAddress("93.184.216.34")!])),
            transport: FixturePublicURLTransport(result: .success(.html(
                status: 200,
                body: "<html><head><meta http-equiv=\"refresh\" content=\"0\"></head><body>Platform Engineer Apply now</body></html>"
            )))
        )
        let request = try! XCTUnwrap(checker.prepareEligible("https://jobs.example.com/role"))

        let completion = await checker.check(request, opportunityTitle: "Platform Engineer")

        XCTAssertEqual(completion.outcome, .needsManualReview)
        XCTAssertEqual(completion.reason, .changedURL)
        XCTAssertNil(completion.redirectTargetRedacted)
    }

    func testVisibleAccessChallengeInSuccessfulResponseMapsAccessBlocked() async {
        let checker = PublicURLChecker(
            resolver: FixturePublicURLResolver(result: .success([PublicIPAddress("93.184.216.34")!])),
            transport: FixturePublicURLTransport(result: .success(.html(
                status: 200,
                body: "<html><body><h1>Verify you are human</h1><p>Complete the CAPTCHA.</p></body></html>"
            )))
        )
        let request = try! XCTUnwrap(checker.prepareEligible("https://jobs.example.com/role"))

        let completion = await checker.check(request, opportunityTitle: "Platform Engineer")

        XCTAssertEqual(completion.outcome, .needsManualReview)
        XCTAssertEqual(completion.reason, .accessBlocked)
        XCTAssertEqual(completion.redactedErrorCode, "access_blocked")
    }

    func testMultipleMarkersFromOneActiveClassRemainConfirmed() async {
        let checker = PublicURLChecker(
            resolver: FixturePublicURLResolver(result: .success([PublicIPAddress("93.184.216.34")!])),
            transport: FixturePublicURLTransport(result: .success(.html(
                status: 200,
                body: "<h1>Platform Engineer</h1><p>Apply now</p><button>Submit your application</button>"
            )))
        )
        let request = try! XCTUnwrap(checker.prepareEligible("https://jobs.example.com/role"))

        let completion = await checker.check(request, opportunityTitle: "Platform Engineer")

        XCTAssertEqual(completion.outcome, .stillOpen)
        XCTAssertEqual(completion.classification, .confirmed)
    }

    func testComplete206ResponseIsNotTreatedAsTruncated() async throws {
        let body = "<h1>Platform Engineer</h1><p>Apply now</p>"
        let fixture = Data((
            "HTTP/1.1 206 Partial Content\r\n" +
            "Content-Type: text/html; charset=utf-8\r\n" +
            "Content-Length: \(body.utf8.count)\r\n" +
            "Content-Range: bytes 0-\(body.utf8.count - 1)/\(body.utf8.count)\r\n\r\n" + body
        ).utf8)
        let response = try PublicURLTransportResponse.parseHTTPFixture(fixture)
        XCTAssertFalse(response.truncated)

        let checker = PublicURLChecker(
            resolver: FixturePublicURLResolver(result: .success([PublicIPAddress("93.184.216.34")!])),
            transport: FixturePublicURLTransport(result: .success(response))
        )
        let request = try XCTUnwrap(checker.prepareEligible("https://jobs.example.com/role"))
        let completion = await checker.check(request, opportunityTitle: "Platform Engineer")
        XCTAssertEqual(completion.outcome, .stillOpen)
    }

    func testTitleAndMarkerInSeparateJobContextsStayAmbiguous() async throws {
        let filler = String(repeating: " unrelated listing detail", count: 40)
        let body = "<h1>Platform Engineer</h1>\(filler)<h1>Sales Manager</h1><p>Apply now</p>"
        let checker = PublicURLChecker(
            resolver: FixturePublicURLResolver(result: .success([PublicIPAddress("93.184.216.34")!])),
            transport: FixturePublicURLTransport(result: .success(.html(status: 200, body: body)))
        )
        let request = try XCTUnwrap(checker.prepareEligible("https://jobs.example.com/role"))
        let completion = await checker.check(request, opportunityTitle: "Platform Engineer")
        XCTAssertEqual(completion.outcome, .needsManualReview)
        XCTAssertEqual(completion.classification, .ambiguous)
    }

    func testIPv4CompatibleIPv6LoopbackIsNotPublic() {
        XCTAssertFalse(PublicIPAddress("::127.0.0.1")!.isPublic)
        XCTAssertFalse(PublicIPAddress("::ffff:127.0.0.1")!.isPublic)
    }
}

@MainActor
private final class FixturePublicURLResolver: PublicURLResolving {
    let result: Result<[PublicIPAddress], PublicURLCheckFailure>

    init(result: Result<[PublicIPAddress], PublicURLCheckFailure>) {
        self.result = result
    }

    func resolve(hostname: String) async throws -> [PublicIPAddress] {
        try result.get()
    }
}

@MainActor
private final class FixturePublicURLTransport: PublicURLTransporting {
    private(set) var requests: [PublicURLRequest] = []
    let result: Result<PublicURLTransportResponse, PublicURLCheckFailure>

    init(result: Result<PublicURLTransportResponse, PublicURLCheckFailure>) {
        self.result = result
    }

    var requestCount: Int { requests.count }
    var lastRequest: PublicURLRequest? { requests.last }

    func perform(_ request: PublicURLRequest, peer: PublicIPAddress) async throws -> PublicURLTransportResponse {
        requests.append(request)
        return try result.get()
    }
}

private extension PublicURLChecker {
    func prepareEligible(_ value: String) -> PublicURLRequest? {
        guard case let .eligible(request) = prepare(value) else { return nil }
        return request
    }
}

private extension PublicURLTransportResponse {
    static func html(
        status: Int,
        headers: [String: String] = [:],
        body: String,
        truncated: Bool = false
    ) -> PublicURLTransportResponse {
        var headers = headers
        headers["Content-Type"] = "text/html; charset=utf-8"
        return PublicURLTransportResponse(
            status: status,
            headers: headers,
            body: Data(body.utf8),
            truncated: truncated
        )
    }
}
