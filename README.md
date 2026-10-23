# bScan-wheel

Pre-built [Open3D](https://www.open3d.org/) wheel for x86-64 CPUs **without AVX/AVX2**
(e.g. pre-2011 Xeons such as the X5600 series).

## Why this exists

Open3D's official PyPI wheel SIGILLs on import on any CPU lacking AVX2. The
actual cause is Open3D's bundled [Embree](https://www.embree.org/) library,
which hardcodes AVX/AVX2 code paths on the Linux x86 build target regardless
of the host CPU's real capabilities:

- https://github.com/isl-org/Open3D/issues/4970
- https://github.com/isl-org/Open3D/issues/6127

This repo builds Open3D from source with that Embree ISA selection patched to
target SSE4.2 only (see `scripts/patch_embree.py`), and with `-DUSE_BLAS=ON`
so it links OpenBLAS instead of bundling Intel MKL.

## How it works

- `open3d-version.txt` pins the Open3D version to build.
- `scripts/build.sh` clones that version, applies the Embree patch, and
  builds a wheel via Open3D's own `make pip-package` target.
- `.github/workflows/build-wheel.yml` runs that build on GitHub Actions
  (`ubuntu-22.04`) and publishes the resulting `.whl` as a GitHub Release
  asset.

The workflow only runs when `open3d-version.txt` or the build scripts change
(plus manual `workflow_dispatch`) — not on a fixed schedule, since the output
wheel doesn't change unless one of those inputs does.

## Usage

Download the `.whl` from the [latest release](../../releases/latest) and
`pip install` it in place of the PyPI `open3d` package, on any Ubuntu 22.04
x86-64 target.

## Bumping the Open3D version

Edit `open3d-version.txt` to the new version tag (e.g. `0.19.0`) and push to
`main` — the workflow will rebuild and publish automatically.

## Staying current with upstream Open3D

`.github/workflows/check-open3d-version.yml` runs weekly (plus manual
`workflow_dispatch`) and checks `isl-org/Open3D`'s latest release against
`open3d-version.txt`. If there's a newer one, it opens a PR bumping the
version file - it does not merge automatically. The PR body notes whether
the newer release changed `3rdparty/embree/embree.cmake`'s structure (via
`scripts/patch_embree.py --check`); if it has, `patch_embree.py` needs
manual review before merging, since the build will otherwise fail fast
rather than silently produce an unpatched (AVX2-dependent) wheel.

Merging the PR triggers `build-wheel.yml` as usual and publishes a new
release.
