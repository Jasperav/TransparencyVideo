import XCTest
@testable import TransparencyVideo

final class TransparencyVideoTests: XCTestCase {
    func testExample() async throws {
    let video = Bundle(for: TransparencyVideoTests.self).url(forResource: "transparency", withExtension: ".mov")!
    let fileManager = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    
    await VideoEditor().export(url: video, outputDir: fileManager.appending(path: "temp.mov"))
    }
}
