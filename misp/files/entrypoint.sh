#!/bin/bash

export RUN_MODE=${RUN_MODE:-server}
if [ -n $RUN_MODE ]
then
  if [ $RUN_MODE == "server" ]
  then
    bash /run_misp.sh
  elif [ $RUN_MODE == "workers" ]
  then
    bash /run_workers.sh
  else
    echo "Invalid option for RUN_MODE. Value must be 'server' or 'workers'."
  fi
else
    echo -e "RUN_MODE not set. Defaulting to 'server'"
    bash /run_misp.sh
fi
