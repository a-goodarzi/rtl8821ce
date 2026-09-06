#!/bin/bash
#
# Usage:
#   sudo ./dkms-install.sh              # build/install this tree as DKMS version "local"
#   sudo ./dkms-install.sh --remove-old # also remove any other rtl8821ce DKMS
#                                        # versions registered on this system first
#                                        # (e.g. leftovers from an AUR package or an
#                                        # older manual install)

if [[ $EUID -ne 0 ]]; then
  echo "You must run this with superuser priviliges.  Try \"sudo ./dkms-install.sh\"" 2>&1
  exit 1
else
  echo "About to run dkms install steps..."
fi

DRV_NAME=rtl8821ce
DRV_VERSION=local

if [[ "${1:-}" == "--remove-old" ]]; then
  echo "Removing other registered ${DRV_NAME} DKMS versions..."
  dkms status ${DRV_NAME} | cut -d, -f1 | sort -u | grep -v "^${DRV_NAME}/${DRV_VERSION}$" | while read -r modver; do
    echo "Removing ${modver}..."
    dkms remove -m "${modver%%/*}" -v "${modver##*/}" --all
    rm -rf "/usr/src/${modver/\//-}"
  done
fi
if dkms status ${DRV_NAME}/${DRV_VERSION} | grep -q .; then
  dkms remove -m ${DRV_NAME} -v ${DRV_VERSION} --all
fi
rm -rf /usr/src/${DRV_NAME}-${DRV_VERSION}
cp -r . /usr/src/${DRV_NAME}-${DRV_VERSION}

dkms add -m ${DRV_NAME} -v ${DRV_VERSION}
dkms build -m ${DRV_NAME} -v ${DRV_VERSION}
dkms install -m ${DRV_NAME} -v ${DRV_VERSION}
RESULT=$?

echo "Finished running dkms install steps."

exit $RESULT
