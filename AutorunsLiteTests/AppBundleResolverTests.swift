import XCTest
@testable import AutorunsLite

final class AppBundleResolverTests: XCTestCase {
    func testFindsAppBundleFromHelperPath() {
        let resolver = AppBundleResolver()
        let url = resolver.bundleURL(
            containingExecutable: "/Applications/Example.app/Contents/MacOS/helper"
        )
        XCTAssertEqual(url?.path, "/Applications/Example.app")
    }

    func testReturnsNilWhenNoAppBundle() {
        let resolver = AppBundleResolver()
        XCTAssertNil(resolver.bundleURL(containingExecutable: "/bin/sh"))
    }

    func testOriginClassification() {
        XCTAssertEqual(
            ItemOrigin.classify(
                label: "com.apple.coreservicesd",
                plistPath: "/System/Library/LaunchDaemons/com.apple.coreservicesd.plist",
                executablePath: nil
            ),
            .appleSystem
        )
        XCTAssertEqual(
            ItemOrigin.classify(
                label: "com.docker.helper",
                plistPath: "/Users/demo/Library/LaunchAgents/com.docker.helper.plist",
                executablePath: "/Applications/Docker.app/Contents/MacOS/com.docker.helper"
            ),
            .thirdParty
        )
    }
}

final class LaunchctlServiceTests: XCTestCase {
    func testParsesLoadedLabelsFromDomainPrint() {
        let stdout = """
        gui/501 = {
            type = gui
            services = {
                "com.docker.helper" => enabled
                "com.example.agent" => disabled
            }
            endpoints = {
                "com.apple.something" => {
                    port = 0x123
                }
            }
        }
        """
        let labels = LaunchctlService().parseLoadedLabels(from: stdout)
        XCTAssertTrue(labels.contains("com.docker.helper"))
        XCTAssertTrue(labels.contains("com.example.agent"))
        XCTAssertFalse(labels.contains("com.apple.something"))
    }

    func testLaunchctlPrintDisabledCompletesQuickly() async {
        let started = Date()
        let result = await LaunchctlService().printDisabled(domain: "gui/\(getuid())")
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertLessThan(elapsed, 5, "launchctl hung: \(result.combinedOutput)")
    }

    func testParsesDisabledLabels() {
        let stdout = """
        disabled services = {
            "com.example.enabled" => enabled
            "com.example.disabled" => disabled
            "com.example.true" => true
            "com.example.false" => false
        }
        """
        let labels = LaunchctlService().parseDisabledLabels(from: stdout)
        XCTAssertTrue(labels.contains("com.example.disabled"))
        XCTAssertTrue(labels.contains("com.example.true"))
        XCTAssertFalse(labels.contains("com.example.enabled"))
        XCTAssertFalse(labels.contains("com.example.false"))
    }

    func testInterpretPrintResultDistinguishesMissingAndError() {
        let loaded = LaunchctlService.interpretPrintResult(
            LaunchctlResult(exitCode: 0, stdout: "state = running", stderr: "")
        )
        XCTAssertEqual(loaded, .loaded)

        let missing = LaunchctlService.interpretPrintResult(
            LaunchctlResult(exitCode: 113, stdout: "", stderr: "Could not find service \"com.example\" in domain")
        )
        XCTAssertEqual(missing, .notFound)

        let denied = LaunchctlService.interpretPrintResult(
            LaunchctlResult(exitCode: 1, stdout: "", stderr: "Permission denied")
        )
        if case .error(let message) = denied {
            XCTAssertTrue(message.lowercased().contains("permission"))
        } else {
            XCTFail("expected error, got \(denied)")
        }
    }
}
