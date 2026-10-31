#!/usr/bin/env bash
# Downloads the MediaPipe runtime and segmentation models into ./vendor
set -euo pipefail
cd "$(dirname "$0")"
VER=0.10.14
mkdir -p vendor/wasm vendor/models
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

( cd "$tmp" && npm pack "@mediapipe/tasks-vision@$VER" >/dev/null && tar xzf "mediapipe-tasks-vision-$VER.tgz" )
sed 's#^//\# sourceMappingURL=.*$##' "$tmp/package/vision_bundle.mjs" > vendor/vision_bundle.js
cp "$tmp/package/wasm/vision_wasm_internal.js" "$tmp/package/wasm/vision_wasm_internal.wasm" vendor/wasm/

base=https://storage.googleapis.com/mediapipe-models/image_segmenter
curl -fsSL -o vendor/models/selfie_segmenter.tflite "$base/selfie_segmenter/float16/latest/selfie_segmenter.tflite"
curl -fsSL -o vendor/models/deeplab_v3.tflite      "$base/deeplab_v3/float32/1/deeplab_v3.tflite"

echo "vendor/ ready:"
find vendor -type f -exec ls -lh {} \; | awk '{print "  " $5 "\t" $9}'
