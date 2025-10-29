#!/bin/bash
# Note: docker only

# Set MDRMine Docker properties
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
WD=$(dirname "$SCRIPT_DIR")
$SCRIPT_DIR/set_docker_properties.sh
if [ $? = 1 ];  # Exiting if script returned an error code
then
    exit 1
fi

echo "--- Cleaning mine ---"
$WD/gradlew clean --stacktrace
$WD/gradlew integrate -Psource=update-publications --stacktrace --info
$WD/gradlew postprocess -Pprocess=do-sources --stacktrace
$WD/gradlew postprocess -Pprocess=create-attribute-indexes --stacktrace
$WD/gradlew postprocess -Pprocess=summarise-objectstore --stacktrace