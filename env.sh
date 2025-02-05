#! /bin/bash

export COMMON_WORK_DIR=/sps/t2k/common/software
export COMMON_REPO_DIR=$COMMON_WORK_DIR/source
export COMMON_BUILD_DIR=$COMMON_WORK_DIR/build
export COMMON_INSTALL_DIR=$COMMON_WORK_DIR/install


# Detect the OS and version
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS_NAME=$ID
  OS_VERSION=$VERSION_ID
else
  echo "Cannot determine the OS version."
fi


function t2k_link_common_soft(){
  echo -e "Setting up T2K libs..."

  local current_path=${PWD}

  echo -e "Linking libs in $COMMON_INSTALL_DIR"
  for dir in $COMMON_INSTALL_DIR/*/     # list directories in the form "/tmp/dirname/"
  do
    dir=${dir%*/}      # remove the trailing "/"
    sub_folder=${dir##*/} # print everything after the final "/"

    # Skip directories that start with "root-"
    if [[ $sub_folder == root-* ]]; then
      continue
    fi

    export PATH="$COMMON_INSTALL_DIR/$sub_folder/bin:$PATH"
    export LD_LIBRARY_PATH="$COMMON_INSTALL_DIR/$sub_folder/lib:$LD_LIBRARY_PATH"
    echo "   ├─ Adding : $sub_folder"
  done

  builtin cd $current_path

  t2k_setup_root v6-32-04

  # cleanup in case it has been called multiple times
  t2k_remove_duplicate_paths PATH
  t2k_remove_duplicate_paths LD_LIBRARY_PATH

  echo "T2K common software has been setup."
}; export -f t2k_link_common_soft

function t2k_setup_root(){

  if [ -z "$1" ]; then
    echo "Version not specified, printing out the available versions..."
  else
    echo "Looking for ROOT: $1"
  fi

  for dir in $COMMON_INSTALL_DIR/*/     # list directories in the form "/tmp/dirname/"
  do
    dir=${dir%*/}      # remove the trailing "/"
    sub_folder=${dir##*/} # print everything after the final "/"

    # Skip directories that start with "root-"
    if [[ $sub_folder == root-* ]]; then
      if [ -z "$1" ]; then
        echo "   ├─ ${sub_folder#root-}"
      else
        if [[ $sub_folder == root-$1 ]]; then
          echo "Found requested version: $sub_folder"
          source $COMMON_INSTALL_DIR/$sub_folder/bin/thisroot.sh
        fi
      fi
    fi

  done

  if [ -z "$1" ]; then
    echo "Usage: setup_root <version-tag>"
    echo "Example: setup_root v6-32-04"
  else
    echo "   ├─ ROOT Prefix : $(root-config --prefix)"
    echo "   ├─ ROOT Version : $(root-config --version)"
  fi

}; export -f t2k_setup_root

function t2k_remove_duplicate_paths() {
  local var_name="$1"  # Name of the variable to modify
  local var_value="${!var_name}"  # Get the value of the variable
  local result=""
  local path

  # Split the colon-separated string and process each path
  IFS=":" read -ra paths <<< "$var_value"

  # Iterate over the paths and add them if they are not already in the result
  for path in "${paths[@]}"; do
    if [[ ":$result:" != *":$path:"* ]]; then
      # Add the path to the result if it's not a duplicate
      if [[ -n "$result" ]]; then
        result="$result:$path"
      else
        result="$path"
      fi
    fi
  done

  # Set the new value back to the original variable using eval
  eval "$var_name=\"$result\""
}; export -f t2k_remove_duplicate_paths

# execute
t2k_link_common_soft
