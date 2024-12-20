#!/bin/bash
#
# Compile script for Cuh kernel
# Copyright (C) 2020-2023 Adithya R.
# Copyright (C) 2023 Tejas Singh.

SECONDS=0 # builtin bash timer
ZIPNAME="NakamaKernel-ginkgo-$(TZ=Asia/Kolkata date +"%Y%m%d-%H%M").zip"
ZIPNAME_KSU="NakamaKernel-ginkgo-KSU-$(TZ=Asia/Kolkata date +"%Y%m%d-%H%M").zip"
TC_DIR="/workspace/gitpod/tc/clang"
GCC_64_DIR="/workspace/gitpod/tc/aarch64-linux-android-4.9"
GCC_32_DIR="/workspace/gitpod/tc/arm-linux-androideabi-4.9"
AK3_DIR="AnyKernel3"
DEFCONFIG="vendor/ginkgo-perf_defconfig"
export PATH="$TC_DIR/bin:$PATH"

# Build Environment
sudo -E apt-get -qq update
sudo -E apt-get -qq install bc python2 python3 python-is-python3

# Check for essentials
if ! [ -d "${TC_DIR}" ]; then
echo "Clang not found! Cloning to ${TC_DIR}..."
if ! git clone --depth=1 https://gitlab.com/nekoprjkt/aosp-clang.git -b 17 ${TC_DIR}; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

if ! [ -d "${GCC_64_DIR}" ]; then
echo "gcc not found! Cloning to ${GCC_64_DIR}..."
if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git ${GCC_64_DIR}; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

if ! [ -d "${GCC_32_DIR}" ]; then
echo "gcc_32 not found! Cloning to ${GCC_32_DIR}..."
if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git ${GCC_32_DIR}; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

if [[ $1 = "-k" || $1 = "--ksu" ]]; then
	echo -e "\nCleanup KernelSU first on local build\n"
	rm -rf KernelSU drivers/kernelsu
else
	echo -e "\nSet No KernelSU Install, just skip\n"
fi

# Set function for override kernel name and variants
if [[ $1 = "-k" || $1 = "--ksu" ]]; then
echo -e "\nKSU Support, let's Make it On\n"
curl -kLSs "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh" | bash -
git apply KernelSU-hook.patch
sed -i 's/CONFIG_KSU=n/CONFIG_KSU=y/g' arch/arm64/configs/vendor/ginkgo-perf_defconfig
sed -i 's/CONFIG_LOCALVERSION="-NakamaKernel"/CONFIG_LOCALVERSION="-NakamaKernel-KSU"/g' arch/arm64/configs/vendor/ginkgo-perf_defconfig
else
echo -e "\nKSU not Support, let's Skip\n"
fi

if [[ $1 = "-r" || $1 = "--regen" ]]; then
make O=out ARCH=arm64 $DEFCONFIG savedefconfig
cp out/defconfig arch/arm64/configs/$DEFCONFIG
exit
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AR=llvm-ar AS=llvm-as NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=$GCC_64_DIR/bin/aarch64-linux-android- CROSS_COMPILE_ARM32=$GCC_32_DIR/bin/arm-linux-androideabi- CLANG_TRIPLE=aarch64-linux-gnu- Image.gz-dtb dtbo.img

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -f "out/arch/arm64/boot/dtbo.img" ]; then
echo -e "\nKernel compiled succesfully! Zipping up...\n"
fi
cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3
cp out/arch/arm64/boot/dtbo.img AnyKernel3
rm -f *zip
cd AnyKernel3
git checkout master &> /dev/null
if [[ $1 = "-k" || $1 = "--ksu" ]]; then
zip -r9 "../$ZIPNAME_KSU" * -x '*.git*' README.md *placeholder
else
zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder
fi
cd ..
echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
if [[ $1 = "-k" || $1 = "--ksu" ]]; then
echo "Zip: $ZIPNAME_KSU"
else
echo "Zip: $ZIPNAME"
fi
else
echo -e "\nCompilation failed!"
exit 1
fi
