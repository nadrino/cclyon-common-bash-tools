#! /bin/bash

# Source this file through the symlink: source /path/to/software/setup.sh
# Deliberately do not resolve the symlink: install/ belongs to its location.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  echo 'Use: source /path/to/setup.sh then call common_soft_setup.' >&2
  exit 1
fi

# Capture the symlink location now, so commands also work after changing directory.
COMMON_WORK_DIR=$(builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || return 1
export COMMON_WORK_DIR
export COMMON_REPO_DIR="$COMMON_WORK_DIR/repo"
export COMMON_BUILD_DIR="$COMMON_WORK_DIR/build"
export COMMON_INSTALL_DIR="$COMMON_WORK_DIR/install"

common_soft_list() {
  local directory software version name
  local -a names=()
  for directory in "$COMMON_INSTALL_DIR"/*; do
    [[ -d $directory ]] || continue
    _common_soft_install_name "${directory##*/}"
    for name in "${names[@]}"; do
      [[ $name == "$software" ]] && continue 2
    done
    names+=("$software")
    printf '%s\n' "$software"
  done
}

_common_soft_version_newer() {
  local candidate=${1#v} current=${2#v} i left right
  local -a candidate_parts current_parts
  IFS='.-' read -r -a candidate_parts <<< "$candidate"
  IFS='.-' read -r -a current_parts <<< "$current"
  for ((i=0; i<${#candidate_parts[@]} || i<${#current_parts[@]}; i++)); do
    left=${candidate_parts[i]:-0}
    right=${current_parts[i]:-0}
    if ((10#$left > 10#$right)); then return 0; fi
    if ((10#$left < 10#$right)); then return 1; fi
  done
  return 1
}

_common_soft_install_name() {
  # Results are local to the calling function (Bash dynamic scope).
  if [[ $1 =~ ^(.+)-(v[0-9]+([.-][0-9]+)*)$ ]]; then
    software=${BASH_REMATCH[1]}
    version=${BASH_REMATCH[2]}
  else
    software=$1
    version=''
  fi
}

common_soft_versions() {
  local directory software version
  for directory in "$COMMON_INSTALL_DIR"/*; do
    [[ -d $directory ]] || continue
    _common_soft_install_name "${directory##*/}"
    if [[ -z ${1:-} || $software == "$1" ]]; then
      printf '%s %s\n' "$software" "${version:-unversioned}"
    fi
  done
}

_common_soft_update_path() {
  local variable=$1 software=$2 selected=$3 suffix=$4 entry directory version
  local result='' existing=${!1:-}
  local -a entries
  IFS=: read -r -a entries <<< "$existing"
  # Remove other installed versions of this software, including on repeated setup.
  for entry in "${entries[@]}"; do
    [[ -n $entry ]] || continue
    local remove=0
    for directory in "$COMMON_INSTALL_DIR"/*; do
      [[ -d $directory ]] || continue
      local installed_name=$software
      _common_soft_install_name "${directory##*/}"
      if [[ $software == "$installed_name" && $entry == "$directory/$suffix" ]]; then
        remove=1
      fi
      software=$installed_name
    done
    if (( ! remove )) && [[ :$result: != *":$entry:"* ]]; then
      result=${result:+$result:}$entry
    fi
  done
  if [[ -d $selected/$suffix ]]; then
    result="$selected/$suffix${result:+:$result}"
  fi
  printf -v "$variable" '%s' "$result"
  export "$variable"
}

common_soft_use() {
  local requested=${1:-} requested_version=${2:-} directory software version
  local selected='' latest=''
  if [[ -z $requested ]]; then
    echo 'Usage: common_soft_use <software> [version]; common_soft_versions [software]' >&2
    return 1
  fi
  for directory in "$COMMON_INSTALL_DIR"/*; do
    [[ -d $directory ]] || continue
    _common_soft_install_name "${directory##*/}"
    [[ $software == "$requested" ]] || continue
    if [[ -n $requested_version ]]; then
      [[ $version == "$requested_version" ]] || continue
      selected=$directory
      break
    elif [[ -z $selected || ( -n $version && -z $latest ) ]]; then
      selected=$directory
      latest=$version
    elif [[ -n $version ]] && _common_soft_version_newer "$version" "$latest"; then
      selected=$directory
      latest=$version
    fi
  done
  if [[ -z $selected ]]; then
    printf 'Software not found: %s %s\n' "$requested" "$requested_version" >&2
    return 1
  fi
  _common_soft_update_path PATH "$requested" "$selected" bin
  _common_soft_update_path LD_LIBRARY_PATH "$requested" "$selected" lib
  _common_soft_update_path LD_LIBRARY_PATH "$requested" "$selected" lib64
  printf 'Using %s\n' "${selected##*/}"
}

common_soft_setup() {
  local directory software version name
  local -a names=()
  if [[ ! -d $COMMON_INSTALL_DIR ]]; then
    printf 'Install directory not found: %s\n' "$COMMON_INSTALL_DIR" >&2
    return 1
  fi
  for directory in "$COMMON_INSTALL_DIR"/*; do
    [[ -d $directory ]] || continue
    _common_soft_install_name "${directory##*/}"
    for name in "${names[@]}"; do
      [[ $name == "$software" ]] && continue 2
    done
    names+=("$software")
    common_soft_use "$software" || return
  done
}

common_soft_enable_devtools() {
  _common_soft_dev_has_go_sources() {
    local file
    for file in "$1"/*.go; do
      [[ -f $file ]] && return 0
    done
    return 1
  }

  common_soft_dev_build() {
    local name=${1:-}
    if [[ -z $name || $name == */* || $name == . || $name == .. ]]; then
      echo 'Usage: common_soft_dev_build <repo-folder> [build options...]' >&2
      return 1
    fi
    shift
    local source_dir="$COMMON_REPO_DIR/$name"
    local build_dir="$COMMON_BUILD_DIR/$name"
    local install_dir="$COMMON_INSTALL_DIR/$name"
    if [[ ! -f $source_dir/CMakeLists.txt ]]; then
      if _common_soft_dev_has_go_sources "$source_dir"; then
        local software version
        _common_soft_install_name "$name"
        mkdir -p -- "$build_dir/bin" || return
        (
          builtin cd -- "$source_dir" || return
          go build -o "$build_dir/bin/$software" "$@" .
        )
        return $?
      fi
      printf 'No CMakeLists.txt or Go source files found: %s\n' "$source_dir" >&2
      return 1
    fi
    local jobs=${CMAKE_BUILD_PARALLEL_LEVEL:-${SLURM_CPUS_PER_TASK:-2}}
    if [[ ! $jobs =~ ^[0-9]+$ || ! $jobs =~ [1-9] ]]; then
      echo 'CMAKE_BUILD_PARALLEL_LEVEL / SLURM_CPUS_PER_TASK must be a positive integer.' >&2
      return 1
    fi
    mkdir -p -- "$build_dir" || return
    cmake -S "$source_dir" -B "$build_dir" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="$install_dir" "$@" || return
    cmake --build "$build_dir" --parallel "$jobs"
  }

  common_soft_dev_install() {
    local name=${1:-}
    if [[ $# != 1 || -z $name || $name == */* || $name == . || $name == .. ]]; then
      echo 'Usage: common_soft_dev_install <repo-folder>' >&2
      return 1
    fi
    local build_dir="$COMMON_BUILD_DIR/$name"
    local source_dir="$COMMON_REPO_DIR/$name"
    if [[ ! -f $source_dir/CMakeLists.txt ]]; then
      if _common_soft_dev_has_go_sources "$source_dir"; then
        local software version
        _common_soft_install_name "$name"
        if [[ ! -x $build_dir/bin/$software ]]; then
          printf 'Go binary not found: %s (run common_soft_dev_build first)\n' "$name" >&2
          return 1
        fi
        mkdir -p -- "$COMMON_INSTALL_DIR/$name/bin" || return
        install -m 755 "$build_dir/bin/$software" "$COMMON_INSTALL_DIR/$name/bin/$software"
        return $?
      fi
      printf 'No CMakeLists.txt or Go source files found: %s\n' "$source_dir" >&2
      return 1
    fi
    if [[ ! -f $build_dir/CMakeCache.txt ]]; then
      printf 'Build not configured: %s (run common_soft_dev_build first)\n' "$name" >&2
      return 1
    fi
    # Equivalent to make install, also works with Ninja and other generators.
    cmake --build "$build_dir" --target install
  }
}
