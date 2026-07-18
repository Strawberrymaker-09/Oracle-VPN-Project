#!/bin/bash
ATTEMPT=1

while true; do
  echo "=================================================="
  echo "Attempt #$ATTEMPT at $(date)"
  echo "=================================================="

  terraform apply -auto-approve

  if [ $? -eq 0 ]; then
    echo "Success! VM created on attempt #$ATTEMPT."
    break
  fi

  echo "Failed (likely capacity issue). Waiting 3 minutes before retrying..."
  ATTEMPT=$((ATTEMPT + 1))
  sleep 180
done
