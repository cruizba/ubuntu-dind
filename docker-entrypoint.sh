#!/bin/bash

if [ "$DEBUG" = true ]; then
    dockerd &
else
    dockerd &> /dev/null &
fi
sleep 2

exec bash