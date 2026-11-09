import Foundation
import IOKit
import IOKit.hid

/// Reads the Rock Band 3 keyboard (PS3 variant) directly over USB-HID.
///
/// The device enumerates as a Sony-licensed HID gamepad (VID 0x12ba /
/// PID 0x2330), NOT as a MIDI device, so CoreMIDI never sees it. We open it
/// with IOHIDManager on a dedicated background run-loop thread (the keyboard
/// streams reports continuously at ~100+ Hz, so this must never touch the main
/// thread per-report), send the 40-byte feature-report handshake, then parse
/// the raw input reports.
///
/// Key byte layout is resolved empirically — set KEYTAR_DEBUG=1 to dump raw
/// reports. `keyByteOffset` is where the three key-bitmask bytes begin.
final class KeytarHID {

    static let vendorID = 0x12ba
    static let productID = 0x2330

    /// Offset of the first of three key-bitmask bytes within the raw report.
    /// (+ a 4th byte whose top bit is the very top C.) Tunable via KEYTAR_KEYOFF.
    let keyByteOffset: Int

    /// Handshake that makes the keyboard start streaming key data.
    private static let handshake: [UInt8] = [
        0xE9, 0x00, 0x89, 0x1B, 0x00, 0x00, 0x00, 0x02,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00,
        0x00, 0x00, 0x89, 0x00, 0x00, 0x00, 0x00, 0x00,
        0xE9, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    ]

    private static let reportBufferSize = 64

    /// Called with the set of currently-pressed key indices (0..24) whenever the
    /// pressed set *changes*. Fires on the HID background thread — the handler is
    /// responsible for hopping to the main actor.
    var onKeys: ((Set<Int>) -> Void)?
    /// Called when the keytar connects (true) / disconnects. HID thread.
    var onConnection: ((Bool) -> Void)?
    /// Called once per press (rising edge) of the handle button. HID thread.
    var onHandleButton: (() -> Void)?

    /// Handle button lives in byte 13, bit 7 (0x80) — resolved empirically.
    private static let handleButtonByte = 13
    private static let handleButtonMask: UInt8 = 0x80
    private var lastHandleDown = false

    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var runLoop: CFRunLoop?
    private let reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: reportBufferSize)

    private let debug = ProcessInfo.processInfo.environment["KEYTAR_DEBUG"] != nil
    private var lastKeys: Set<Int>? = nil
    private var lastRawHex = ""

    init() {
        if let s = ProcessInfo.processInfo.environment["KEYTAR_KEYOFF"], let v = Int(s) {
            keyByteOffset = v
        } else {
            keyByteOffset = 5    // matches the Python rb3keytar_hid.py default
        }
    }

    deinit { reportBuffer.deallocate() }

    // MARK: - Lifecycle

    func start() {
        let t = Thread { [weak self] in self?.runThread() }
        t.name = "KeytarHID"
        t.start()
    }

    private func runThread() {
        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = mgr

        let match: [String: Any] = [
            kIOHIDVendorIDKey as String: Self.vendorID,
            kIOHIDProductIDKey as String: Self.productID,
        ]
        IOHIDManagerSetDeviceMatching(mgr, match as CFDictionary)

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(mgr, matchCallback, ctx)
        IOHIDManagerRegisterDeviceRemovalCallback(mgr, removeCallback, ctx)

        guard let rl = CFRunLoopGetCurrent() else { return }
        self.runLoop = rl
        IOHIDManagerScheduleWithRunLoop(mgr, rl, CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        CFRunLoopRun()
    }

    func stop() {
        if let mgr = manager {
            IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        if let rl = runLoop { CFRunLoopStop(rl) }
        manager = nil
        device = nil
    }

    // MARK: - Device events

    fileprivate func deviceMatched(_ dev: IOHIDDevice) {
        device = dev
        let openRet = IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone))
        usleep(50_000)   // let the device settle before the handshake

        let feat = Self.handshake.withUnsafeBufferPointer { buf in
            IOHIDDeviceSetReport(dev, kIOHIDReportTypeFeature, 0, buf.baseAddress!, buf.count)
        }
        // Only fall back to an Output report if the Feature report failed —
        // on these Sony-licensed controllers an Output report also drives the
        // player LEDs, so sending it needlessly leaves them blinking.
        var out: IOReturn = 0
        if feat != kIOReturnSuccess {
            out = Self.handshake.withUnsafeBufferPointer { buf in
                IOHIDDeviceSetReport(dev, kIOHIDReportTypeOutput, 0, buf.baseAddress!, buf.count)
            }
        }
        if debug {
            FileHandle.standardError.write(Data(String(
                format: "HANDSHAKE open=0x%08x feature=0x%08x output=0x%08x\n",
                UInt32(bitPattern: openRet), UInt32(bitPattern: feat), UInt32(bitPattern: out)
            ).utf8))
        }

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(
            dev, reportBuffer, Self.reportBufferSize, inputReportCallback, ctx
        )
        onConnection?(true)
    }

    fileprivate func deviceRemoved() {
        device = nil
        lastKeys = nil
        onConnection?(false)
        onKeys?([])
    }

    /// Parse a raw input report into the set of pressed key indices (0..24).
    fileprivate func handleReport(_ report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        if debug {
            let n = min(Int(length), 20)
            var hex = ""
            for i in 0..<n { hex += String(format: "%02x ", report[i]) }
            if hex != lastRawHex {
                lastRawHex = hex
                FileHandle.standardError.write(Data("RAW len=\(length): \(hex)\n".utf8))
            }
        }

        // Handle button (rising-edge → cycle palettes).
        if Int(length) > Self.handleButtonByte {
            let down = (report[Self.handleButtonByte] & Self.handleButtonMask) != 0
            if down && !lastHandleDown { onHandleButton?() }
            lastHandleDown = down
        }

        let o = keyByteOffset
        guard Int(length) >= o + 4 else { return }

        var pressed = Set<Int>()
        func bits(_ byte: UInt8, base: Int) {
            for i in 0..<8 where (byte & (1 << (7 - i))) != 0 { pressed.insert(base + i) }
        }
        bits(report[o], base: 0)
        bits(report[o + 1], base: 8)
        bits(report[o + 2], base: 16)
        if report[o + 3] & 0x80 != 0 { pressed.insert(24) }

        guard pressed != lastKeys else { return }   // only emit on change
        lastKeys = pressed
        onKeys?(pressed)
    }
}

// MARK: - C callbacks (bounce through the context pointer back to the instance)

private func matchCallback(
    _ context: UnsafeMutableRawPointer?, _ result: IOReturn,
    _ sender: UnsafeMutableRawPointer?, _ device: IOHIDDevice
) {
    guard let context else { return }
    Unmanaged<KeytarHID>.fromOpaque(context).takeUnretainedValue().deviceMatched(device)
}

private func removeCallback(
    _ context: UnsafeMutableRawPointer?, _ result: IOReturn,
    _ sender: UnsafeMutableRawPointer?, _ device: IOHIDDevice
) {
    guard let context else { return }
    Unmanaged<KeytarHID>.fromOpaque(context).takeUnretainedValue().deviceRemoved()
}

private func inputReportCallback(
    _ context: UnsafeMutableRawPointer?, _ result: IOReturn,
    _ sender: UnsafeMutableRawPointer?, _ type: IOHIDReportType,
    _ reportID: UInt32, _ report: UnsafeMutablePointer<UInt8>, _ reportLength: CFIndex
) {
    guard let context else { return }
    Unmanaged<KeytarHID>.fromOpaque(context).takeUnretainedValue()
        .handleReport(report, length: reportLength)
}
