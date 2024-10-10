# Using a fork of the https://github.com/lukechilds/dockerpi vm with multiple
# improvements and fixes.
FROM biomi-emulator-qemu:8.2.0

# Select the GitHub tag from the release that hosts the OS files
# https://github.com/carlosperate/rpi-os-custom-image/releases/
ARG GH_TAG="bookworm-2023-10-10"

# To build a different image type from the release the FILE_SUFFIX variable
# can be overwritten with the `docker build --build-arg` flag
ARG FILE_SUFFIX="autologin-ssh-expanded"

# This only needs to be changed if the releases filename format changes
ARG FILE_PREXIF="raspberry-pi-os-lite-"${GH_TAG}"-"

ARG FILESYSTEM_IMAGE_URL="https://github.com/carlosperate/rpi-os-custom-image/releases/download/"${GH_TAG}"/"${FILE_PREXIF}${FILE_SUFFIX}".zip"
ADD $FILESYSTEM_IMAGE_URL /filesystem.zip

# entrypoint.sh has been added in the parent lukechilds/dockerpi:vm
ENTRYPOINT ["/entrypoint.sh"]
