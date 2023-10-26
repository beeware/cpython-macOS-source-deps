CPython macOS source dependencies
=================================

A meta-package for building the binary packages for macOS that a
CPython build requires. This includes:

* BZip2
* XZ
* OpenSSL 1.1
* OpenSSL 3.0

The repository works by downloading, patching, and building binaries for each
SDK target and architecture that is requried. The compiled library is packed
into a tarball for distribution in "installed" form - that is, the contents of
the ``include`` and ``lib`` folders are included.

The binaries are all "fat" binaries that support arm64 and x86_64. This should
enable the code to run any modern macOS hardware.

Quickstart
----------

**Unless you're trying to directly link against one of these libraries, you
don't need to use this repository**. When you obtain a CPython build for an
Apple platform, it will have already been linked using these libraries.

If you *do* need to link against these libraries for some reason, you can use
the pre-compiled versions that are published on the `Github releases page
<https://github.com/beeware/cpython-apple-source-deps/releases>`__. You don't
need to compile them yourself.

However, if you *do* need to compile your own version for some reason:

* Clone this repository
* Create a Python 3 virtual environment. Any supported Python 3 release should
  be sufficient; some tools require python3 as part of their build.
* In the root directory, run:
  - ``make`` (or ``make all``) to build everything.
  - ``make BZip2`` to build BZip2

This should:

1. Download the original source packages
2. Patch them as required for compatibility with the selected OS
3. Build the libraries for the selected OS and architecture
4. Package a tarball containing build products.

The resulting artefacts will be packaged as ``.tar.gz`` files in the ``dist``
folder.
