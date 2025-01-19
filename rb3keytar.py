# rb3keytar.py
import usb.core
import usb.util

class RB3Keytar:
    VENDOR_ID = 0x12ba
    PRODUCT_ID = 0x2330
    ENDPOINT_ADDRESS = 0x81
    PACKET_SIZE = 27

    # 40-byte "handshake" from earlier code
    MSG2 = [
        0xE9, 0x00, 0x89, 0x1B, 0x00, 0x00, 0x00, 0x02,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00,
        0x00, 0x00, 0x89, 0x00, 0x00, 0x00, 0x00, 0x00,
        0xE9, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ]

    def __init__(self):
        self.dev = None
        self.endpoint = None

    def connect(self):
        """Find and claim the keytar device, then send the handshake."""
        # Find device
        self.dev = usb.core.find(
            idVendor=self.VENDOR_ID,
            idProduct=self.PRODUCT_ID
        )
        if self.dev is None:
            raise ValueError("RB3 PS3 Keytar not found.")

        # Detach kernel driver if active
        if self.dev.is_kernel_driver_active(0):
            self.dev.detach_kernel_driver(0)

        # Set config, claim interface
        self.dev.set_configuration()
        usb.util.claim_interface(self.dev, 0)

        # Send MSG2 handshake
        self.dev.ctrl_transfer(0x21, 0x09, 0x0300, 0, self.MSG2)

        # Find endpoint
        cfg = self.dev.get_active_configuration()
        intf = cfg[(0, 0)]
        for ep in intf.endpoints():
            if ep.bEndpointAddress == self.ENDPOINT_ADDRESS:
                self.endpoint = ep
                break

        if not self.endpoint:
            raise ValueError("Keytar endpoint 0x81 not found.")

    def read_packet(self, timeout=500):
        """Read one 27-byte packet from the keytar (returns a bytes array)."""
        if not self.endpoint:
            raise RuntimeError("No endpoint to read from.")
        return self.dev.read(self.endpoint.bEndpointAddress, self.PACKET_SIZE, timeout=timeout)

    @staticmethod
    def parse_keys(data):
        """Given 27-byte array from keytar, return a set of pressed key indices (0..24)."""
        pressed = set()
        # Byte 5 => keys [0..7]
        b = data[5]
        for i in range(8):
            if b & (1 << (7 - i)):
                pressed.add(i)
        # Byte 6 => [8..15]
        b = data[6]
        for i in range(8):
            if b & (1 << (7 - i)):
                pressed.add(8 + i)
        # Byte 7 => [16..23]
        b = data[7]
        for i in range(8):
            if b & (1 << (7 - i)):
                pressed.add(16 + i)
        # Byte 8 => top bit = key 24
        b = data[8]
        if b & 0x80:
            pressed.add(24)
        return pressed

    def close(self):
        """Release interface and attempt to reattach kernel driver."""
        if self.dev:
            usb.util.release_interface(self.dev, 0)
            try:
                self.dev.attach_kernel_driver(0)
            except:
                pass
