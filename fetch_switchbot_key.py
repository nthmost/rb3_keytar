#!/usr/bin/env python3
"""One-shot: fetch a SwitchBot device's encryption key from SwitchBot Cloud.

Encrypted SwitchBot devices (newer bulbs, strips, neon rope lights) require a
per-device key for any BLE command. This script uses your SwitchBot account
credentials once to retrieve that key, then prints it so it can be stored in
~/.config/rb3_keytar/env for use by the BLE bridge.

Usage:
    SWITCHBOT_USERNAME=email@example.com \\
    SWITCHBOT_PASSWORD=... \\
    DEVICE_MAC=90:E5:B1:35:E2:02 \\
    python fetch_switchbot_key.py

After it prints the key_id and encryption_key, append them to
~/.config/rb3_keytar/env as:
    SWITCHBOT_DEVICE_MAC=90:E5:B1:35:E2:02
    SWITCHBOT_KEY_ID=<value>
    SWITCHBOT_ENCRYPTION_KEY=<value>
"""
import asyncio
import os
import sys

import aiohttp
from switchbot import SwitchbotEncryptedDevice


async def main():
    username = os.environ.get("SWITCHBOT_USERNAME")
    password = os.environ.get("SWITCHBOT_PASSWORD")
    mac = os.environ.get("DEVICE_MAC")

    missing = [
        n for n, v in [
            ("SWITCHBOT_USERNAME", username),
            ("SWITCHBOT_PASSWORD", password),
            ("DEVICE_MAC", mac),
        ] if not v
    ]
    if missing:
        sys.exit(f"missing env vars: {', '.join(missing)}")

    async with aiohttp.ClientSession() as session:
        result = await SwitchbotEncryptedDevice.async_retrieve_encryption_key(
            session, mac, username, password
        )

    print()
    print(f"Device MAC: {mac}")
    print(f"key_id:         {result['key_id']}")
    print(f"encryption_key: {result['encryption_key']}")
    print()
    print("Append to ~/.config/rb3_keytar/env:")
    print(f"SWITCHBOT_DEVICE_MAC={mac}")
    print(f"SWITCHBOT_KEY_ID={result['key_id']}")
    print(f"SWITCHBOT_ENCRYPTION_KEY={result['encryption_key']}")


if __name__ == "__main__":
    asyncio.run(main())
