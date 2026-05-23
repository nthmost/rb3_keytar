"""macOS-friendly RB3 Keytar driver using hidapi instead of pyusb.

Same API surface as rb3keytar.RB3Keytar so callers can swap backends.
"""
import hid


class RB3Keytar:
    VENDOR_ID = 0x12ba
    PRODUCT_ID = 0x2330
    PACKET_SIZE = 27

    MSG2 = bytes([
        0xE9, 0x00, 0x89, 0x1B, 0x00, 0x00, 0x00, 0x02,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00,
        0x00, 0x00, 0x89, 0x00, 0x00, 0x00, 0x00, 0x00,
        0xE9, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    ])

    def __init__(self):
        self.dev = None

    def connect(self):
        self.dev = hid.Device(self.VENDOR_ID, self.PRODUCT_ID)
        # Original pyusb code sent ctrl_transfer(0x21, 0x09, 0x0300, ...) which
        # is HID Set_Report with report-type=Feature (0x03), report-id=0.
        # In hidapi that's send_feature_report(); the leading byte is the
        # report ID.
        try:
            self.dev.send_feature_report(b"\x00" + self.MSG2)
        except Exception as e:
            # Fall back to an Output report in case feature reports aren't
            # supported on this descriptor.
            try:
                self.dev.write(b"\x00" + self.MSG2)
            except Exception:
                pass

    def read_packet(self, timeout=500):
        if not self.dev:
            raise RuntimeError("Not connected.")
        data = self.dev.read(self.PACKET_SIZE, timeout=timeout)
        return data

    @staticmethod
    def parse_keys(data):
        if not data or len(data) < 9:
            return set()
        pressed = set()
        b = data[5]
        for i in range(8):
            if b & (1 << (7 - i)):
                pressed.add(i)
        b = data[6]
        for i in range(8):
            if b & (1 << (7 - i)):
                pressed.add(8 + i)
        b = data[7]
        for i in range(8):
            if b & (1 << (7 - i)):
                pressed.add(16 + i)
        if data[8] & 0x80:
            pressed.add(24)
        return pressed

    def close(self):
        if self.dev:
            self.dev.close()
            self.dev = None
