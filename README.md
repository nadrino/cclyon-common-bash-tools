# cclyon-common-bash-tools
cclyon-common-bash-tools

Source `setup.sh` through a symlink next to your `install` directory:

```bash
ln -s /path/to/cclyon-common-bash-tools/setup.sh /path/to/software/setup.sh
source /path/to/software/setup.sh
common_soft_setup
```

Each `install/<software>-v<version>` directory is detected automatically, for
example `install/root-v6-40-04`. The highest numeric version of each software is
enabled through `PATH` (`bin`) and `LD_LIBRARY_PATH` (`lib` and `lib64`), when
those directories exist. Versions support numeric components separated by `-`
or `.`. Directories without a version are also supported; a numbered version
takes precedence for the same software.

```bash
common_soft_list                  # List available software
common_soft_versions              # List all installed software and versions
common_soft_versions root         # List ROOT versions
common_soft_use root v6-32-04      # Switch to a specific installed version
common_soft_use root              # Switch back to the latest installed version
```

Sourcing only loads the commands and directory variables. Call `common_soft_setup`
to enable the latest versions (or reset to them later). Switching removes the previous
version's paths. This script adds search paths; it does not run software-specific
initialization scripts such as `thisroot.sh`.

Enable the development commands explicitly:

```bash
common_soft_enable_devtools
common_soft_dev_build root-v6-40-04
common_soft_dev_install root-v6-40-04
```

The repository must already exist in `repo/root-v6-40-04` and contain a
`CMakeLists.txt`. Build configures CMake in `build/root-v6-40-04` with
`CMAKE_BUILD_TYPE=Release` and `CMAKE_INSTALL_PREFIX` pointing to
`install/root-v6-40-04`, then compiles it. Extra CMake options can be passed
after the name, for example `-DCMAKE_BUILD_TYPE=Debug`. Parallel builds use
`CMAKE_BUILD_PARALLEL_LEVEL`, then `SLURM_CPUS_PER_TASK`, or two jobs by default.
Install runs the CMake `install` target (equivalent to `make install`).
Run `common_soft_setup` or `common_soft_use root v6-40-04` to activate the result.

Projects with `CMakeLists.txt` always use CMake. Otherwise, if `.go` files exist
at the repository root, the commands use Go (which must be available in `PATH`):

```bash
common_soft_dev_build rclone-v1.70.0
common_soft_dev_install rclone-v1.70.0
```

Build runs `go build` in the repository and writes the executable to
`build/rclone-v1.70.0/bin/rclone`. Install copies it to
`install/rclone-v1.70.0/bin/rclone`. The executable name excludes the numeric
version suffix. The root Go package must be a command (`package main`). Extra
arguments to the build command are passed as Go build flags, for example
`common_soft_dev_build rclone-v1.70.0 -tags cmount`.
