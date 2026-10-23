#!/usr/bin/env python3
"""
Patches Open3D's bundled Embree build config so the Linux x86 path drops its
hard AVX/AVX2 requirement in favor of SSE4.2 only. Without this, importing
open3d SIGILLs on any CPU without AVX2 (e.g. pre-2011 Xeons).

Confirmed root cause and fix, from Open3D maintainers/users on the same
CPU generation this is built for:
  https://github.com/isl-org/Open3D/issues/4970
  https://github.com/isl-org/Open3D/issues/6127
"""
import sys

OLD_BLOCK = '''else() # Linux(x86) and WIN32
    set(ISA_ARGS -DEMBREE_ISA_AVX=ON
                 -DEMBREE_ISA_AVX2=ON
                 -DEMBREE_ISA_AVX512=OFF
                 -DEMBREE_ISA_SSE2=OFF
                 -DEMBREE_ISA_SSE42=OFF
    )
    # order matters. link libs with increasing ISA order.
    set(ISA_LIBS embree_avx embree_avx2)
    set(ISA_BUILD_BYPRODUCTS "<INSTALL_DIR>/${Open3D_INSTALL_LIB_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}embree_avx${CMAKE_STATIC_LIBRARY_SUFFIX}"
                             "<INSTALL_DIR>/${Open3D_INSTALL_LIB_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}embree_avx2${CMAKE_STATIC_LIBRARY_SUFFIX}"
    )'''

NEW_BLOCK = '''else() # Linux(x86) and WIN32
    # Patched by bScan-wheel: disable AVX/AVX2 so the resulting binary runs
    # on pre-2011 CPUs (e.g. Xeon 5600 series) that lack those instructions.
    # See https://github.com/isl-org/Open3D/issues/4970 and #6127.
    set(ISA_ARGS -DEMBREE_ISA_AVX=OFF
                 -DEMBREE_ISA_AVX2=OFF
                 -DEMBREE_ISA_AVX512=OFF
                 -DEMBREE_ISA_SSE2=OFF
                 -DEMBREE_ISA_SSE42=ON
    )
    set(ISA_LIBS embree_sse42)
    set(ISA_BUILD_BYPRODUCTS "<INSTALL_DIR>/${Open3D_INSTALL_LIB_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}embree_sse42${CMAKE_STATIC_LIBRARY_SUFFIX}"
    )'''


def main():
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} <path-to-embree.cmake>")

    path = sys.argv[1]
    with open(path, "r") as f:
        content = f.read()

    if OLD_BLOCK not in content:
        if NEW_BLOCK in content:
            print(f"{path} is already patched, nothing to do.")
            return
        sys.exit(
            f"ERROR: expected ISA block not found in {path}.\n"
            "Open3D likely changed this file in a newer version - update "
            "OLD_BLOCK in patch_embree.py to match before rebuilding."
        )

    content = content.replace(OLD_BLOCK, NEW_BLOCK)
    with open(path, "w") as f:
        f.write(content)

    print(f"Patched {path}: Linux x86 Embree build now targets SSE4.2 only (no AVX/AVX2).")


if __name__ == "__main__":
    main()
