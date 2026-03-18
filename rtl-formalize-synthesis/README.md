# rtl-formalize-synthesis

This subtree contains the Sparkle-based RTL formalization and emission flow used in this repository.

## Upstream Sparkle

- Original project: <https://github.com/Verilean/sparkle>
- Local vendor path: `rtl-formalize-synthesis/vendor/Sparkle`
- Pinned upstream revision: `2d3dda875b0aa12d850322f26a2c42a9379931c8`
- Vendor preparation script: `rtl-formalize-synthesis/scripts/prepare_sparkle.sh`

`prepare_sparkle.sh` checks out the pinned upstream Sparkle revision and then applies the local patch at `rtl-formalize-synthesis/patches/sparkle-local.patch`.

## License and Patch Notice

The top-level repository is licensed under Apache License 2.0. That license applies to repository-local source files unless a file or subdirectory states otherwise.

The vendored Sparkle source under `rtl-formalize-synthesis/vendor/Sparkle` remains derived from the upstream Sparkle project and carries its upstream Apache License 2.0 terms. See `rtl-formalize-synthesis/vendor/Sparkle/LICENSE`.

The local changes maintained in `rtl-formalize-synthesis/patches/sparkle-local.patch` are repository-local modifications applied on top of upstream Sparkle. They are distributed under this repository's Apache License 2.0, but they do not replace or narrow the upstream Sparkle license that continues to govern the vendored derivative work.

In practical terms:

- upstream origin and revision are identified above
- upstream license text is preserved in `vendor/Sparkle/LICENSE`
- local Sparkle-specific modifications are recorded in `patches/sparkle-local.patch`
- regenerated vendor content should continue to preserve the upstream license and attribution notices
