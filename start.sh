#!/bin/bash
set -e

bash start_voyager.sh
bash setup.sh
sudo docker compose up -d