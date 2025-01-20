# Rock Band 3 Keytar Integration, aka "Goonies Piano"

This repository provides **Python scripts** and instructions to make a Rock Band 3 keytar (PS3 version) function as a real MIDI instrument on Linux (or other systems). 

There are two ways to get the Rock Band keytar working as a MIDI instrument.  The easiest way (and least satisfying AFAIC) is to get a MIDI to USB adapter [like this one](https://www.amazon.com/dp/B092QN6BTV/nthmost-20) and plug the MIDI port from the keytar into the USB-A receiver on a computer.

The harder but more satisfying way is to use the wireless dongle that enables the keytar to function as an input from within the range of the dongle (about 15-20 feet). 

This repo assumes you want the MORE AWESOME thing of being able to use the keytar wirelessly.  But this took some doing.  Some coding, that is.  The unique wireless protocol needs to be interpreted and reshaped into MIDI notes.

Additionally, the main.py script can **publish key presses** (or chord events) to **MQTT** (all while still generating MIDI notes) enabling integration with Home Assistant or other automation platforms.  

So now you can have a working Goonies Piano -- play the right chord and your coffee gets made just how you like it. Play the wrong chord and maybe you get flashing red lights all over your house. That's up to you!

## Table of Contents

- [Overview](#overview)  
- [Hardware Requirements](#hardware-requirements)  
- [Udev Permissions](#udev-permissions)  
- [Python Dependencies](#python-dependencies)  
- [Scripts](#scripts)  
  - [1. `rb3keytar.py`](#1-rb3keytarpy)  
  - [2. `main.py` (MIDI + MQTT)](#2-mainpy-midi--mqtt)  
  - [3. `main_audio.py` (PyGame WAV samples)](#3-main_audiopy-pygame-wav-samples)  
  - [4. `chord_listener.py` (MQTT subscriber)](#4-chord_listenerpy-mqtt-subscriber)  
- [MIDI Sound Setup](#midi-sound-setup)  
  - [Using JACK and Qsynth](#using-jack-and-qsynth)  
- [MQTT Setup](#mqtt-setup)  
- [License](#license)

---

## Overview

This project shows how to:

1. **Read** raw USB data from the Rock Band 3 **PS3 Keytar** via a Python script.  
2. **Convert** that data into note-on/note-off events (MIDI) for real-time audio.  
3. **Optionally** publish those events to MQTT for home automation triggers.  

Works best on **Linux**, tested primarily on Debian/Ubuntu-based distros. Should also work with minimal changes on Raspberry Pi OS.

---

## Hardware Requirements

- **Rock Band 3 Keytar (PS3 version)** with its USB wireless dongle.  
- A **Linux** machine (could be a Raspberry Pi, mini PC, or standard desktop) with at least one free USB port.  
- (Optional) A **PC audio setup** for real-time MIDI playback.  

---

## Udev Permissions

By default, regular users can’t always read/write USB HID devices. Create a **udev rule** so you don’t have to run Python scripts as root. For the Rock Band 3 Keytar (Vendor ID `0x12ba`, Product ID `0x2330`), use:

```
# /etc/udev/rules.d/99-rb3-keytar.rules

SUBSYSTEM=="usb", \
  ATTRS{idVendor}=="12ba", \
  ATTRS{idProduct}=="2330", \
  MODE="0666", \
  GROUP="plugdev"
```

Then reload rules and replug the device:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Make sure your user is in the `plugdev` group (or whichever group you specify in the rule).

---

## Python Dependencies

These scripts require the following Python libraries:

```text
pyusb
paho-mqtt
mido
python-rtmidi
pygame
```

Some are optional depending on which script you run:

- **`pyusb`**: Required for USB communication with the keytar.  
- **`paho-mqtt`**: For publishing events to an MQTT broker (optional if you only want MIDI).  
- **`mido` + `python-rtmidi`**: For creating a **virtual MIDI port** that can be routed to a software synth (e.g., Qsynth).  
- **`pygame`**: Used only if you want direct WAV sample playback instead of MIDI.  

### Installation

```bash
pip3 install pyusb paho-mqtt mido python-rtmidi pygame
```

On **Debian/Ubuntu**, also ensure ALSA sequencer support is installed:

```bash
sudo apt-get update
sudo apt-get install \
    alsa-utils \
    libasound2-dev \
    libasound2-data
```

And ensure you’re in the **audio** group for ALSA sequencer:

```bash
sudo usermod -aG audio $(whoami)
```

Logout/login (or reboot) to apply group changes.

---

## Scripts

Below is a short description of the main scripts in this repository.

### 1. `rb3keytar.py`

- A **class** that handles the raw USB device:
  - Finding the keytar by Vendor & Product ID  
  - Claiming the USB interface and sending the “magic” handshake  
  - Reading 27-byte reports and parsing which keys are pressed  

### 2. `main.py` (MIDI + MQTT)

- Creates a **virtual MIDI output** using Mido/rtmidi (so you can route it to a software synth).  
- Also **publishes** note-on/off events to an MQTT broker under a topic like `keytar/notes`.  
- For each pressed key:
  1. Sends a `note_on` message to the MIDI port  
  2. Publishes an MQTT message (JSON or string)  
- For each released key:
  - Sends `note_off` + MQTT message  

**Run** (assuming your broker allows anonymous or you set credentials in the code):
```bash
python3 main.py
```
Then connect a synth (e.g., Qsynth) to “RB3 Keytar Out” to hear notes, and subscribe to `keytar/notes` in your MQTT client.

### 3. `main_audio.py` (PyGame WAV samples)

- Demonstrates direct audio playback (looping WAV files) via **PyGame** instead of MIDI.  
- Requires a `.wav` sample for each note (e.g. `C1.wav`, `C#1.wav`, …).  
- Press a key => loop the corresponding WAV. Release => stop it.

### 4. `chord_listener.py` (MQTT subscriber)

- Example of a script that **subscribes** to the same MQTT topic your keytar script publishes.  
- Interprets chord sets (like `["C1","E1","G1"]`) by looking them up in a dictionary.  
- Prints or logs the chord name (e.g., “C1 major”).

---

## MIDI Sound Setup

If you’re using **MIDI** output from `main.py`, you need a **software synthesizer** to turn MIDI messages into audio. Common choices:

- **Qsynth + FluidSynth**  
- **Timidity++**  
- A DAW like **Ardour**, **LMMS**, or **Ableton** (if on Linux with Wine, etc.)

### Using JACK and Qsynth

1. **Install JACK** and Qsynth:
   ```bash
   sudo apt-get install jackd qjackctl qsynth fluidsynth
   ```
2. **Run** `qjackctl` (a GUI) to start the **JACK** server.  
3. **Launch** Qsynth. Load a **SoundFont** (like `FluidR3_GM.sf2`).  
4. **Connect** “RB3 Keytar Out” (your script’s virtual MIDI port) to Qsynth’s input in either QJackCtl’s Graph or the Connections window.  

Now you should hear your key presses as a piano (or whatever SoundFont instrument you’ve loaded).

> **Note**: On modern distros, you might skip JACK and just use **ALSA** with Qsynth; results vary. JACK may be more trouble than it's worth if you're not doing anything complicated. 

---

## MQTT Setup

If you want to see **published** note or chord messages:

1. **Install an MQTT broker** (like **Mosquitto**).  
2. **Allow** anonymous or create credentials.  
3. **In** `main.py`, adjust:
   ```python
   MQTT_BROKER = "192.168.x.x"  # or "localhost"
   MQTT_PORT = 1883
   client.username_pw_set("mqttuser","mqttpass")  # if needed
   ```
4. **Subscribe** in another terminal:
   ```bash
   mosquitto_sub -h 192.168.x.x -p 1883 -t "keytar/notes" -v
   ```
You should see JSON-like messages for each note on/off event.

---

## License

This project is licensed under the [MIT License](LICENSE) — feel free to modify, distribute, or integrate into your own projects.

---

### Questions or Issues

- If you encounter **udev** or permission errors, ensure you’re not running your script as root and that the correct rules are in place.  
- For **ALSA**/**MIDI** errors like “`MidiOutAlsa::initialize: error creating ALSA sequencer client object`,” verify your user is in the `audio` group and that ALSA sequencer modules are loaded.  
- Join the discussion or open issues here on GitHub for help.  
