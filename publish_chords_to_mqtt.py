# main.py
import time
import paho.mqtt.client as mqtt
from rb3keytar import RB3Keytar
from chord_detector import ChordDetector

MQTT_BROKER = "192.168.0.78"
MQTT_PORT = 1883
MQTT_TOPIC = "keytar/chords"

def main():
    # 1. Setup MQTT
    client = mqtt.Client()
    client.connect(MQTT_BROKER, MQTT_PORT, 60)
    client.loop_start()

    # 2. Connect to the keytar
    keytar = RB3Keytar()
    keytar.connect()  # raises ValueError if not found

    # 3. Instantiate chord detector
    chord_detector = ChordDetector(hold_time=0.2)

    print(f"Connected to Keytar. Publishing stable chords to '{MQTT_TOPIC}'. Press Ctrl+C to exit.")

    try:
        while True:
            # Read raw packet
            data = keytar.read_packet(timeout=500)
            # Parse keys
            pressed = keytar.parse_keys(data)

            # Update chord detector
            chord_notes, triggered = chord_detector.update(pressed)
            if triggered and chord_notes:
                # We got a stable chord
                # For example, publish JSON-ish data
                payload = {"chord": chord_notes, "timestamp": time.time()}
                # Convert payload to string or JSON
                client.publish(MQTT_TOPIC, str(payload))
                print(f"Published chord: {payload}")

            time.sleep(0.01)

    except KeyboardInterrupt:
        print("\nExiting...")
    finally:
        keytar.close()
        client.loop_stop()

if __name__ == "__main__":
    main()
