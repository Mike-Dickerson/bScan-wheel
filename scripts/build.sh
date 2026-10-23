#!/usr/bin/env bash
# Builds an Open3D wheel from source with Embree's AVX/AVX2 requirement
# removed, so it runs on CPUs without those instructions (e.g. pre-2011
# Xeons). See scripts/patch_embree.py for the root cause and fix.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPEN3D_VERSION="$(tr -d '[:space:]' < "$REPO_ROOT/open3d-version.txt")"
SRC_DIR="$REPO_ROOT/open3d-src"

echo "==> Building Open3D v${OPEN3D_VERSION} (no AVX/AVX2 requirement)"

rm -rf "$SRC_DIR"
git clone --recursive --branch "v${OPEN3D_VERSION}" --depth 1 \
    https://github.com/isl-org/Open3D.git "$SRC_DIR"

cd "$SRC_DIR"
bash util/install_deps_ubuntu.sh assume-yes

echo "==> Patching Embree to drop its AVX/AVX2 requirement"
python3 "$REPO_ROOT/scripts/patch_embree.py" "$SRC_DIR/3rdparty/embree/embree.cmake"

mkdir build
cd build

cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_PYTHON_MODULE=ON \
    -DBUILD_CUDA_MODULE=OFF \
    -DBUILD_PYTORCH_OPS=OFF \
    -DBUILD_TENSORFLOW_OPS=OFF \
    -DBUNDLE_OPEN3D_ML=OFF \
    -DBUILD_UNIT_TESTS=OFF \
    -DUSE_BLAS=ON \
    -DCMAKE_C_FLAGS="-march=x86-64 -mtune=generic" \
    -DCMAKE_CXX_FLAGS="-march=x86-64 -mtune=generic" \
    ..

make -j"$(nproc)"
make pip-package

mkdir -p "$REPO_ROOT/dist"
cp lib/python_package/pip_package/*.whl "$REPO_ROOT/dist/"

echo "==> Built wheel(s):"
ls -la "$REPO_ROOT/dist"
