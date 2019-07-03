#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

apt-get update
apt-get install nginx
apt-get install ufw
ufw allow 'Nginx HTTP'