#!/bin/bash
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
$SCRIPT_DIR/postprocess.sh
$SCRIPT_DIR/redeploy_webapp.sh