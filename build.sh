
# Compile script for QuicksilveR kernel
# Copyright (C) 2020-2021 Adithya R.

#
apt-get install sudo
sudo apt-get install xz-utils
sudo apt-get install -y lld
sudo apt-get install cpio
#
SECONDS=0 # builtin bash timer
ZIPNAME="kernel-vayu-$(date '+%Y%m%d-%H%M').zip"
TC_DIR="$HOME/tc/azure-clang"
DEFCONFIG="vayu_defconfig"
CHATID=-467253822
BOT_MSG_URL="https://api.telegram.org/1376150581:AAHv0Zk5LOBN9qytAzo0AMgiZlGYmP1S6ik/sendMessage"
BOT_BUILD_URL="https://api.telegram.org/1376150581:AAHv0Zk5LOBN9qytAzo0AMgiZlGYmP1S6ik/sendDocument"

tg_post_msg() {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$CHATID" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"
}

tg_post_build() {
	#Show the Checksum alongwith caption
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$CHATID"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$2 | <b>MD5 Checksum : </b><code>$MD5CHECK</code>"
}

export PATH="$TC_DIR/bin:$PATH"

if ! [ -d "$TC_DIR" ]; then
	echo "Azure clang not found! Cloning to $TC_DIR..."
	tg_post_msg "Building..."
	if ! git clone -q --depth=1 --single-branch https://gitlab.com/Panchajanya1999/azure-clang.git "$TC_DIR"; then
		echo "Cloning failed! Aborting..."
		exit 1
	fi
fi

if [[ $1 = "-r" || $1 = "--regen" ]]; then
	make O=out ARCH=arm64 $DEFCONFIG
	cp out/.config arch/arm64/configs/$DEFCONFIG
	exit
fi

if [[ $1 = "-c" || $1 = "--clean" ]]; then
	rm -rf out
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- Image.gz dtbo.img

kernel="out/arch/arm64/boot/Image.gz"
dtb="out/arch/arm64/boot/dts/qcom/sm8150-v2.dtb"
dtbo="out/arch/arm64/boot/dtbo.img"

if [ -f "$kernel" ] && [ -f "$dtb" ] && [ -f "$dtbo" ]; then
	echo -e "\nKernel compiled succesfully! Zipping up...\n"
	if ! git clone -q https://github.com/xawlw/AnyKernel3; then
		echo -e "\nCloning AnyKernel3 repo failed! Aborting..."
		exit 1
	fi
	cp $kernel $dtbo AnyKernel3
	cp $dtb AnyKernel3/dtb
	rm -f *zip
	cd AnyKernel3 || exit
	rm -rf out/arch/arm64/boot
	zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
	cd ..
	rm -rf AnyKernel3
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	echo "Zip: $ZIPNAME"
	tg_post_build "$ZIPNAME" "Build Success !"
	echo
else
	echo -e "\nCompilation failed!"
fi

