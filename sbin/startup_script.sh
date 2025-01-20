#!/bin/bash

# Ensure a dedicated directory for Fluidsynth runtime files
RUNTIME_DIR=/run/fluidsynth
sudo mkdir -p $RUNTIME_DIR
sudo chown nthmost:nthmost $RUNTIME_DIR

# Start Fluidsynth and write its PID to the runtime directory
fluidsynth -i -a alsa -m alsa_seq -g 1.0 /home/nthmost/chronotrigger.sf2 &
FLUIDSYNTH_PID=$!

# Write the PID to the PID file
echo $FLUIDSYNTH_PID > $RUNTIME_DIR/fluidsynth.pid

# Allow some time for Fluidsynth to initialize
sleep 2

# Connect RB3 Keytar to Fluidsynth
aconnect 128:0 129:0

