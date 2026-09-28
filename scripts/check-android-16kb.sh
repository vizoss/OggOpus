#!/bin/bash
set -euo pipefail
apk="${1:?Usage: bash scripts/check-android-16kb.sh path/to/app.apk}"
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
: "${sdk:?Set ANDROID_HOME to the Android SDK directory}"
ndk="$sdk/ndk/28.0.12674087"
case "$(uname -s)" in
  Darwin) host=darwin-x86_64 ;;
  Linux) host=linux-x86_64 ;;
  *) echo 'Unsupported host' >&2; exit 1 ;;
esac
objdump="$ndk/toolchains/llvm/prebuilt/$host/bin/llvm-objdump"
zipalign="$sdk/build-tools/35.0.0/zipalign"
test -x "$objdump"
test -x "$zipalign"
unpacked="$(mktemp -d "${TMPDIR:-/tmp}/oggopus-16kb.XXXXXX")"
unzip -q "$apk" 'lib/*' -d "$unpacked"
count=0
while IFS= read -r library; do
  "$objdump" -p "$library" | awk '
    $1 == "LOAD" {
      count++
      split($NF, exponent, "\\*\\*")
      if (exponent[2] + 0 < 14) bad=1
    }
    END { if (!count || bad) exit 1 }
  '
  echo "16 KB ELF: ${library#"$unpacked"/}"
  count=$((count + 1))
done < <(find "$unpacked/lib" -type f -name '*.so' \( -path '*/arm64-v8a/*' -o -path '*/x86_64/*' \))
test "$count" -gt 0
"$zipalign" -c -P 16 4 "$apk"
echo "PASS: $count 64-bit shared libraries; ELF LOAD and APK ZIP alignment verified."
echo "Extracted verification files: $unpacked"
