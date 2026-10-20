import XCTest
@testable import SensorKit

final class SMCDecoderTests: XCTestCase {
    func testSp78DecodesSignedFixedPointTemperature() {
        // 0x2D80 = 11648 / 256 = 45.5
        XCTAssertEqual(SMCDecoder.decode(type: "sp78", bytes: [0x2D, 0x80]), 45.5)
    }

    func testSp78DecodesNegativeValues() {
        // 0xFF00 = -256 / 256 = -1.0
        XCTAssertEqual(SMCDecoder.decode(type: "sp78", bytes: [0xFF, 0x00]), -1.0)
    }

    func testFpe2DecodesFanSpeed() {
        // 0x1F40 = 8000 / 4 = 2000 rpm
        XCTAssertEqual(SMCDecoder.decode(type: "fpe2", bytes: [0x1F, 0x40]), 2_000)
    }

    func testFltDecodesLittleEndianFloat() {
        let bytes = withUnsafeBytes(of: Float(1_234.5).bitPattern.littleEndian) { Array($0) }
        XCTAssertEqual(SMCDecoder.decode(type: "flt ", bytes: bytes), 1_234.5)
    }

    func testUnsignedIntegersDecodeBigEndian() {
        XCTAssertEqual(SMCDecoder.decode(type: "ui8 ", bytes: [0x07]), 7)
        XCTAssertEqual(SMCDecoder.decode(type: "ui16", bytes: [0x01, 0x00]), 256)
        XCTAssertEqual(SMCDecoder.decode(type: "ui32", bytes: [0x00, 0x01, 0x00, 0x00]), 65_536)
    }

    func testUnknownTypeReturnsNil() {
        XCTAssertNil(SMCDecoder.decode(type: "zzzz", bytes: [0x01, 0x02]))
    }

    func testTooFewBytesReturnsNil() {
        XCTAssertNil(SMCDecoder.decode(type: "sp78", bytes: [0x2D]))
    }

    func testPlausibleTemperatureRejectsSentinelValues() {
        XCTAssertTrue(SMCDecoder.isPlausibleTemperature(45.5))
        XCTAssertFalse(SMCDecoder.isPlausibleTemperature(0))
        XCTAssertFalse(SMCDecoder.isPlausibleTemperature(-12))
        XCTAssertFalse(SMCDecoder.isPlausibleTemperature(200))
    }

    func testTemperatureLabelUsesKnownNamesAndFallsBackToKey() {
        XCTAssertEqual(SMCDecoder.temperatureLabel(for: "TC0P"), "CPU proximity")
        XCTAssertEqual(SMCDecoder.temperatureLabel(for: "TXYZ"), "TXYZ")
    }
}
