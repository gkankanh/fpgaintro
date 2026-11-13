# Third-party material

Everything in this repository is original work except the file listed below.

## `common/ulx3s_v20.lpf`

The ECP5 pin constraint file for the ULX3S v2.0 board — the map from signal
names like `led[0]` to package balls like `B2`.

| | |
|---|---|
| **Source** | the ULX3S project, by EMARD |
| **Copyright** | Copyright (c) 2016–2018 EMARD |
| **Licence** | MIT-style; redistribution is expressly permitted |

It is included because the course cannot work without it, and because
reproducing a 598-line pin map by hand would be both pointless and
error-prone.

The upstream licence requires that its copyright notice and permission notice
travel with any copy, so both are reproduced in full below.

> Copyright (c) 2016-2018 EMARD
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this hardware, software, and associated documentation files (the
> "Product"), to deal in the Product without restriction, including without
> limitation the rights to use, copy, modify, merge, publish, distribute,
> sublicense, and/or sell copies of the Product, and to permit persons to whom
> the Product is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Product.
>
> The logotypes "EMARD", "RADIONA" and "FER" shall remain unmodified, visible,
> and in the original location, shape and size on the top PCB silkscreen
> layer.
>
> THE PRODUCT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
> FROM, OUT OF OR IN CONNECTION WITH THE PRODUCT OR THE USE OR OTHER DEALINGS
> IN THE PRODUCT.

The silkscreen condition concerns physical boards and has no bearing on
redistributing a text constraint file.

## The toolchain

**Downloaded, not vendored.** `tools/install.sh` fetches the
[OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build) into
`toolchain/`, which is gitignored and contains no files tracked by this
repository. Each tool carries its own licence, collected in
`toolchain/oss-cad-suite/license/` after installation.

## Names used descriptively

"ULX3S", "Lattice", "ECP5" and "RISC-V" are the names of products and
standards belonging to others. They are used here only to say what this course
is about — which board it targets and which instruction set it implements —
and no affiliation or endorsement is claimed or implied.

The projects involved, and the people behind them, are credited in chapter 3
of the course book and in the repository README. They are the reason this
course can exist at all.
