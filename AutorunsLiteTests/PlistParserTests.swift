import XCTest
@testable import AutorunsLite

final class PlistParserTests: XCTestCase {
    private let parser = PlistParser()

    func testParsesProgramArgumentsAsExecutable() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.example.helper</string>
            <key>ProgramArguments</key>
            <array>
                <string>/Applications/Example.app/Contents/MacOS/helper</string>
                <string>--background</string>
                <string>--silent</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """
        let parsed = try parser.parse(data: Data(xml.utf8), fallbackLabel: "fallback")
        XCTAssertEqual(parsed.label, "com.example.helper")
        XCTAssertEqual(parsed.executablePath, "/Applications/Example.app/Contents/MacOS/helper")
        XCTAssertEqual(parsed.arguments, [
            "/Applications/Example.app/Contents/MacOS/helper",
            "--background",
            "--silent"
        ])
        XCTAssertTrue(parsed.runAtLoad)
        XCTAssertEqual(parsed.keepAliveDescription, "No")
    }

    func testProgramTakesPriorityOverProgramArguments() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.example.program</string>
            <key>Program</key>
            <string>/usr/local/bin/tool</string>
            <key>ProgramArguments</key>
            <array>
                <string>/ignored/bin/tool</string>
                <string>--flag</string>
            </array>
            <key>WorkingDirectory</key>
            <string>/tmp</string>
            <key>StandardOutPath</key>
            <string>/tmp/out.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/err.log</string>
            <key>EnvironmentVariables</key>
            <dict>
                <key>FOO</key>
                <string>bar</string>
            </dict>
        </dict>
        </plist>
        """
        let parsed = try parser.parse(data: Data(xml.utf8), fallbackLabel: "fallback")
        XCTAssertEqual(parsed.executablePath, "/usr/local/bin/tool")
        XCTAssertEqual(parsed.workingDirectory, "/tmp")
        XCTAssertEqual(parsed.standardOutPath, "/tmp/out.log")
        XCTAssertEqual(parsed.standardErrorPath, "/tmp/err.log")
        XCTAssertEqual(parsed.environmentVariables["FOO"], "bar")
    }

    func testKeepAliveDictionaryDescription() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.example.keepalive</string>
            <key>Program</key>
            <string>/bin/sleep</string>
            <key>KeepAlive</key>
            <dict>
                <key>SuccessfulExit</key>
                <false/>
            </dict>
        </dict>
        </plist>
        """
        let parsed = try parser.parse(data: Data(xml.utf8), fallbackLabel: "fallback")
        XCTAssertEqual(parsed.keepAliveDescription, "SuccessfulExit: false")
    }
}
