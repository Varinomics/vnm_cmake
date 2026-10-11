# vnm_cmake

CMake-only BSD utilities for acquiring owned source dependencies and configuring
nested consumers with their producer's toolchain. No language or Qt dependency
is enabled by this package.

Use `find_package(vnm_cmake CONFIG REQUIRED)` for an installed package, or acquire
the source with the canonical FetchContent name `vnm_cmake` and `GIT_TAG master`.
`FETCHCONTENT_SOURCE_DIR_VNM_CMAKE` selects a local checkout.

`vnm_acquire_owned_dependency(NAME name GIT_REPOSITORY url TARGET target)` reuses
an existing target, otherwise validates `FETCHCONTENT_SOURCE_DIR_<NAME>`, searches
the canonical checkout's workspace, and fetches `master` when no local source
exists. Workspace discovery searches sibling checkouts and the adjacent
`bsd_licensed` and `varinomics` directories. Linked worktrees resolve from their
Git common directory. `SOURCE_ROOT` selects a different discovery origin.

For a file contract, supply `FILES_VARIABLE VNM_FONTS_DIRECTORY` instead of a
target. File-only fonts consumption remains Qt-free and does not link the font
registration library. Do not request `EXCLUDE_FROM_ALL` for fonts: directory
exclusion suppresses licence installation. That option requires CMake 3.28 when
used for other dependencies.

`vnm_find_dependency_source(result NAME name REQUIRED_FILE relative/path)` exposes
the same local-source resolution to dependencies with their own build adapters.
It does not fetch or define targets. Third-party revision policy remains with
the caller.

`vnm_acquire_dependency_sources(result NAME name GIT_REPOSITORY url GIT_TAG ref
REQUIRED_FILE relative/path)` shares acquisition for third-party source adapters
such as Lexilla, which has no root CMake project. If the dependency has a root
CMake project, it is added through FetchContent. Owned dependencies use the
master-only `vnm_acquire_owned_dependency` wrapper.

Package-specific assertions, install components and dependency options belong
to each consumer. These modules do not own a build scheduler or select a local
compiler installation.

`vnm_add_qml_resources(target URI uri RESOURCE_PREFIX prefix QRC_FILES manifests)`
compiles the selected manifests' QML and JavaScript with Qt's QML module tools,
preserving their resource URLs and embedding their other assets separately.
Existing qmldir files and C++ type registration remain with the owner. Direct
`QML_FILES` inputs use their `QT_RESOURCE_ALIAS` values. Release discards QML
source contents; other configurations retain them. Qt fixes that choice at
configure time, so use separate Release and non-Release trees. Static-library
owners must install/export the `VNM_QML_RESOURCE_TARGETS` object targets with
their backing library.

Call `vnm_write_toolchain_context(path)` while configuring a producer. A nested
`cmake -P` harness includes that generated file, then calls
`vnm_append_toolchain_args(command)` to append the producer's explicit CMake
toolchain settings to a configure command. `LANGUAGES NONE` forwards only
generator settings and the build tool, preserving compiler-free package tests.
The caller provides its normal developer environment when running any
compiler-capable harness; environment variables are neither stored nor
reconstructed by this package.
