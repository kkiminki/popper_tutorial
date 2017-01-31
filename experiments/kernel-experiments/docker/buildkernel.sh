set -xe

VERSION_POSTFIX=${VERSION_POSTFIX:-"-ci"}
BUILD_ONLY_LOADED_MODULES=${BUILD_ONLY_LOADED_MODULES:-"true"}
CONCURRENCY_LEVEL="$(grep -c '^processor' /proc/cpuinfo)"
STOCK_CONFIG=${STOCK_CONFIG:="config-4.6.0-0.bpo.1-amd64"}


CheckFreeSpace(){
  if (($(df -m . | awk 'NR==2 {print $4}') < 500 )); then
    echo "Not enough free disk space, you need at least 500MB"
    exit 1
  fi
}

echo "$(getconf _NPROCESSORS_ONLN) CPU cores detected"

export BUILD_DIR="/app"
export SRC_DIR="/linux"
if [ ! -d $SRC_DIR ] ; then
  echo "couldn't find $SRC_DIR"
  exit 1
fi

mkdir -p kpatch

cd $SRC_DIR

cp $BUILD_DIR/kernel_config.sh .

mv -f ".config .config.old" | true

cp $BUILD_DIR/"$STOCK_CONFIG" .config
./kernel_config.sh

yes "" | make oldconfig

if [ "$BUILD_ONLY_LOADED_MODULES" = "true" ]
then
  echo "Disabling modules that are not loaded by the running system.."
  make localmodconfig
fi


echo "Now building the kernel, this will take a while..."
time fakeroot make-kpkg --jobs "$(getconf _NPROCESSORS_ONLN)" --append-to-version "$VERSION_POSTFIX" --initrd kernel_image
time fakeroot make-kpkg --jobs "$(getconf _NPROCESSORS_ONLN)" --append-to-version "$VERSION_POSTFIX" --initrd kernel_headers

PACKAGE_NAME="$(ls -m1 /linux-image*.deb)"
HEADERS_PACKAGE_NAME = "$(ls -m1 /linux-headers*.deb)"

echo "Congratulations! You just built a linux kernel."
echo "Use the following command to install it: dpkg -i $PACKAGE_NAME $HEADERS_PACKAGE_NAME"

mv /*.deb /linux/
