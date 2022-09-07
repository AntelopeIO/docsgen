#!/usr/bin/env bash

# Clones Git repos and processes Markdown and Code to produce static HTML documentation
# created Sep 2022
# author @ericpassmore
##############################################################################
# Setup
##############################################################################
#Create_Top_Level_Dir
#Install_Docusaurus
#Install_Web_Content
#Install_Branding_Logos
##############################################################################
# Main - Calls Code Based on Arguments Passed In
##############################################################################
#Bootstrap_Repo
##############################################################################
# Remote - Copy and install to remote
##############################################################################
#Remote_Upload

#############################################################################
# FUNCTIONS
#############################################################################
Help() {
  echo "Creates web version of documentation pulling together documentation from several gitrepositories across the EOS Networks"
  echo ""
  echo "Syntax: generate_documents.sh [-r|d|b|t|i|h|x|f]"
  echo "mandatory: -r owner/rep and -d directory"
  echo ""
  echo "options:"
  echo "-r: owner/repository name of the git repository and source for documentation"
  echo "-d: specify directory for building the static HTML documentation"
  echo "-b: branch to use for git"
  echo "-t: tag to use for git"
  echo "-i: private key for web host, needed to install files"
  echo "-h: destination user@host(s) where to install files"
  echo "-x: suppress build statics process"
  echo "-f: fast, skip git clone if files less then 1 hour old"
  echo ""
  echo "example: generate_documents.sh -r eosnetworkfoundation/mandel -b ericpassmore-working -t v3.1.1 -d /path/to/build_root -i aws_identity -h eric@hostA -h eric@hostB"
  echo "Run script to build mandel docs and update production site , with branch ericpassmore-working and tag v3.1.1. This updates latest documentation version"
  exit 1
}

####
# Create Top Level Directories
Create_Top_Level_Dir() {
  if [ -z "$ARG_BUILD_DIR" ]; then
    echo "Empty root dir! Exiting"
    exit 1
  fi
  # devdocs is for docusarus , reference for non-markdown content
  # :? pattern for saftey don't create in root dir
  [ ! -d "${ARG_BUILD_DIR}/devdocs/eosdocs" ] && mkdir -p "${ARG_BUILD_DIR:?}/devdocs/eosdocs"
  [ ! -d "${ARG_BUILD_DIR}/devdocs/eosdocs/welcome" ] && mkdir -p "${ARG_BUILD_DIR:?}/devdocs/eosdocs/welcome"
  [ ! -d "${ARG_BUILD_DIR}/devdocs/eosdocs/cdt" ] && mkdir -p "${ARG_BUILD_DIR:?}/devdocs/eosdocs/cdt"
  [ ! -d "${ARG_BUILD_DIR}/devdocs/eosdocs/system-contracts" ] && mkdir -p "${ARG_BUILD_DIR:?}/devdocs/eosdocs/system-contracts"
  [ ! -d "${ARG_BUILD_DIR}/devdocs/eosdocs/leap" ] && mkdir -p "${ARG_BUILD_DIR:?}/devdocs/eosdocs/leap"
  # i18n directories zh and ko, english is the default and not included
  [ ! -d "${ARG_BUILD_DIR}/devdocs/i18n" ] && mkdir "${ARG_BUILD_DIR:?}/devdocs/i18n"
  [ ! -d "${ARG_BUILD_DIR}/devdocs/i18n/ko" ] && mkdir "${ARG_BUILD_DIR:?}/devdocs/i18n/ko"
  [ ! -d "${ARG_BUILD_DIR}/devdocs/i18n/zh" ] && mkdir "${ARG_BUILD_DIR:?}/devdocs/i18n/zh"
  [ ! -d "${ARG_BUILD_DIR}/devdocs/i18n/zh/docusaurus-plugin-content-docs" ] && mkdir "${ARG_BUILD_DIR:?}/devdocs/i18n/zh/docusaurus-plugin-content-docs"
  [ ! -d "${ARG_BUILD_DIR}/devdocs/i18n/zh/docusaurus-plugin-content-docs/current" ] && mkdir "${ARG_BUILD_DIR:?}/devdocs/i18n/zh/docusaurus-plugin-content-docs/current"
  [ ! -d "${ARG_BUILD_DIR}/devdocs/i18n/ko/docusaurus-plugin-content-docs" ] && mkdir "${ARG_BUILD_DIR:?}/devdocs/i18n/ko/docusaurus-plugin-content-docs/"
  [ ! -d "${ARG_BUILD_DIR}/devdocs/i18n/ko/docusaurus-plugin-content-docs/current" ] && mkdir "${ARG_BUILD_DIR:?}/devdocs/i18n/ko/docusaurus-plugin-content-docs/current"
}

####
# Copy over logos
Install_Branding_Logos() {
  # copy over the logo these directories created when docusarus site is build
  [ ! -f "${ARG_BUILD_DIR}/devdocs/static/img/eosn_logo.png" ] && cp "${SCRIPT_DIR:?}/../web/eosn_logo.png" "${ARG_BUILD_DIR:?}/devdocs/static/img/eosn_logo.png"
  SMALL_LOGO="cropped-EOS-Network-Foundation-Site-Icon-1-150x150.png"
  [ ! -f "${ARG_BUILD_DIR}/devdocs/static/img/${SMALL_LOGO}" ] && cp "${SCRIPT_DIR:?}/../web/${SMALL_LOGO}" "${ARG_BUILD_DIR:?}/devdocs/static/img/${SMALL_LOGO}"
}

#####
# Setup docusaurus
Install_Docusaurus() {
  DOC6S_CORE_PACKAGE="node_modules/@docusaurus/core/package.json"
  # eat the error
  version=$(grep version "${ARG_BUILD_DIR:?}/devdocs/${DOC6S_CORE_PACKAGE}" \
         | cut -d: -f2 | tr -d " ,\"") 2>/dev/null
  # parse . seperate version into semver array
  IFS="." read -r -a semver <<< "$version"
  # check if major version exists
  # semver[2] is minor version
  # semver[3] is patch
  if [ -z "${semver[1]}" ]; then
    if ! npx create-docusaurus@latest "${ARG_BUILD_DIR:?}/devdocs" classic --typescript;
    then
      >&2 echo "npx create-docusaurus@latest failed exiting"
      exit 1
    fi
    # add another module exit if we can't get into the directory
    pushd "${ARG_BUILD_DIR}"/devdocs || exit
    if ! npm i --save redocusaurus;
    then
      >&2 echo "npm redocusaurus failed exiting"
      exit 1
    fi
    popd || exit
  fi
  # push our own config
  cp "${SCRIPT_DIR:?}/../config/docusaurus.config.js" "${ARG_BUILD_DIR:?}/devdocs"
  # copy over side sidebars one for each seperly versioned doc-id
  find "${SCRIPT_DIR:?}"/../web/docusaurus/src -type f -name "sidebar*.js" -print0 | while IFS= read -r -d '' sidebar
  do
    cp "$sidebar" "${ARG_BUILD_DIR:?}"/devdocs
  done
  # copy in i18n files
  cp -r "${SCRIPT_DIR:?}/../web/docusaurus/i18n" "${ARG_BUILD_DIR:?}/devdocs/"
  # Overwrite entry page for docusarus
  cp "${SCRIPT_DIR:?}/../web/docusaurus/src/pages/index.tsx" "${ARG_BUILD_DIR:?}/devdocs/src/pages"
  cp "${SCRIPT_DIR:?}/../web/docusaurus/src/components/HomepageFeature/index.tsx" "${ARG_BUILD_DIR:?}/devdocs/src/components/HomepageFeatures"
  # Customer CSS for Doc6s
  cp "${SCRIPT_DIR:?}/../web/docusaurus/src/css/custom.css" "${ARG_BUILD_DIR:?}/devdocs/src/css"
}

####
# Copy in index files like API Reference
Install_Web_Content() {
  cp "${SCRIPT_DIR:?}/../web/api-listing.md" "${ARG_BUILD_DIR:?}/devdocs/eosdocs/welcome/"
}

###
# Prepare build by coping in other statics
Arrange_Statics() {
  [ -d "${ARG_BUILD_DIR}"/devdocs/build/reference ] && (rm -rf "${ARG_BUILD_DIR}"/devdocs/build/reference || exit)
  mkdir -p "${ARG_BUILD_DIR}"/devdocs/build/reference
  cp -R "${ARG_BUILD_DIR}"/reference/* "${ARG_BUILD_DIR}"/devdocs/build/reference/
}

###
# Prepare tar file
Create_Tar() {
  # initial check
  item_count=$(find "${ARG_BUILD_DIR}"/devdocs/build -maxdepth 1 | wc -l)
  # UTC date YYMMDDHH
  todays_date=$(date -u +%y%m%d%H)
  tar_file=/tmp/devdocs_"${todays_date}"_update.tgz
  if [ "$item_count" -gt 2 ]; then
    cd "${ARG_BUILD_DIR}"/devdocs/build || exit
    tar czf "$tar_file" -- *
  fi
  # return file name
  echo "$tar_file"
}

####
# Bootstrap repo
#  git clone into working directory
#  sources bash script naming convention install_${repo}.sh
#  calls function Install_${Repo} passes in arguments
Bootstrap_Repo() {
  WORKING_DIR="${SCRIPT_DIR:?}/../working"
  GIT_URL="https://github.com/${ARG_GIT_REPO}"
  GIT_OWNER=$(echo "$ARG_GIT_REPO" | cut -d'/' -f1)
  GIT_BASE_REPO=$(basename "$ARG_GIT_REPO")

  # source script
  if [ -f "${SCRIPT_DIR}/install_${GIT_BASE_REPO}.sh" ]; then
    # directive to ignore source file we will lint seperatly
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR:?}/install_${GIT_BASE_REPO:?}.sh" || exit
  else
    echo -e "${Red_Text}${On_White}Can not source ${SCRIPT_DIR}/install_${GIT_BASE_REPO}.sh"
    echo -e "Does File Exist"
    echo -e "${Reset_Color}"
    exit 1
  fi

  #### Logic to clean out working directory
  # incl some optimization for speed up when fast_flag provided
  if [ -d "${WORKING_DIR}/${ARG_GIT_REPO}" ]; then
    # fast flag is faster but leaves dirty copy
    # no flag remove dir
    if [ -z "$ARG_FAST" ]; then
      rm -rf "${WORKING_DIR:?}/${ARG_GIT_REPO}" || exit
    else
      now=$(date +%s)
      one_hour_earlier=$(echo "$now" "- 60*60" | bc)
      last_modified=$( stat -f %m "${WORKING_DIR}"/"${ARG_GIT_REPO}" )
      if [ "$DEBUG" ]; then
         echo "detected fast flag last modified ${last_modified} sec since epoch"
      fi
      # there is a fast flag, but if older then 1 hour we still remove and clean
      [ "$last_modified" -lt "$one_hour_earlier" ] && rm -rf "${WORKING_DIR:?}/${ARG_GIT_REPO}"
    fi
  fi
  # failed checks then directory still exists and reuse content
  #### end Logic to clean out working directory

  ## Assemble Git Command
  GIT_CLONE="git clone"
  GIT_CHECKOUT=""
  # ONLY TAG MOST LIKELY
  if [ -z "$ARG_BRANCH" ] && [ -n "$ARG_TAG" ]; then
    # hard tag
    GIT_CLONE="${GIT_CLONE} -b $ARG_TAG"
  fi
  # ONLY BRANCH
  if [ -n "$ARG_BRANCH" ] && [ -z "$ARG_TAG" ]; then
    # single branch
    GIT_CLONE="${GIT_CLONE} -b $ARG_BRANCH"
  fi
  # BOTH BRANCH AND TAG
  if [ -n "$ARG_BRANCH" ] && [ -n "$ARG_TAG" ]; then
    GIT_CLONE="${GIT_CLONE} -b $ARG_BRANCH"
    GIT_CHECKOUT="git checkout tags/${ARG_TAG}"
  fi
  ## FISHISH OFF CLONE CMD
  GIT_CLONE="${GIT_CLONE} ${GIT_URL}"

  # create working dir if it does not exist
  if [ ! -d "${WORKING_DIR}/${ARG_GIT_REPO}" ]; then
    mkdir -p "${WORKING_DIR}/${ARG_GIT_REPO}"
    # move to owner directory and clone
    echo "$GIT_CLONE"
    cd "${WORKING_DIR:?}"/"${GIT_OWNER:?}" && $GIT_CLONE
  fi
  # move into newly cloned dir
  cd "${WORKING_DIR}"/"${ARG_GIT_REPO}" || exit
  # run checkout command if needed
  [ -n "$GIT_CHECKOUT" ] && "$GIT_CHECKOUT"

  # This weird command upper cases the first letter of GIT_BASE_REPO
  GIT_BASE_REPO=$(tr '[:lower:]' '[:upper:]' <<< "${GIT_BASE_REPO:0:1}")"${GIT_BASE_REPO:1}"
  COMMAND="Install_${GIT_BASE_REPO} $SCRIPT_DIR $ARG_GIT_REPO $ARG_BUILD_DIR $ARG_BRANCH $ARG_TAG"
  $COMMAND
}

Run_Doc6s_Build() {
  pushd "${ARG_BUILD_DIR:?}"/devdocs || exit
  if ! npm run build;
  then
    >&2 echo "npm run build failed exiting"
    exit 1
  fi
  popd || exit
}

Remote_Upload() {
  ### check for valid params
  if [ -n "$ARG_ID_FILE" ] && [ -n "${ARG_HOST[0]}" ]; then
    if [ -f "$ARG_ID_FILE" ]; then
      [ "$DEBUG" ] && echo "Found host and id file"
      # copies reference into build directory
      Arrange_Statics
      # makes a tar file under /tmp
      archive=$(Create_Tar)
      # debug does archive exist?
      [ "$DEBUG" ] && echo "stat of ${archive}" && stat "$archive"
      # loop over hosts
      for host in "${ARG_HOST[@]}"; do
        ### vars
        user=$(echo "$host" | cut -d'@' -f1)
        machine=$(echo "$host" | cut -d'@' -f2)
        # base date
        bdate=$(date -u +%y%m%d%H)
        base_tar_file=$(basename "${archive}")
        # on remote move into content directory
        move_cmd="mv ${base_tar_file} content/"
        # on remote backup existing
        backup_cmd="cd /var/www/html && tar czf /home/ubuntu/content/devdocs_${bdate}_backup.tgz -- *"
        # loop over tar 1st level and delete on remote host
        delete_cmd="cd /var/www/html && tar tfz /home/ubuntu/content/${base_tar_file} | cut -d'/' -f1 | sort -u | xargs rm -rf"
        # un-pack tar populate new things
        update_cmd="cd /var/www/html && tar xzf /home/ubuntu/content/${base_tar_file}"
        ### sftp copy over
        echo "put ${archive}" | sftp -i "$ARG_ID_FILE" "$host"
        ### move
        ssh -i "$ARG_ID_FILE" -l "$user" "$machine" "$move_cmd"
        ### backup
        ssh -i "$ARG_ID_FILE" -l "$user" "$machine" "$backup_cmd"
        ### delete
        ssh -i "$ARG_ID_FILE" -l "$user" "$machine" "$delete_cmd"
        ### update
        ssh -i "$ARG_ID_FILE" -l "$user" "$machine" "$update_cmd"
        ### clean old files in content directory
        ssh -t -t -i "$ARG_ID_FILE" -l "$user" "$machine" <<EOF
find content -type f -mtime +30 -print0 | while IFS= read -r -d '' oldfile
do
  rm \$oldfile
done
exit
EOF
      done
    fi
  else
    [ "$DEBUG" ] && echo "No host or id file provided"
  fi
}


############################################################################
# Global Vars
# remove next line to turn off Debug
DEBUG=1
# compute script dir for copying files from here to web directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
Red_Text='\033[1;31m'
On_White='\033[47m'
Reset_Color='\033[0m' # No Color

############################################################################
# Get the options
while getopts "r:d:b:t:i:h:xf" option; do
   case $option in
      r) # repository
        ARG_GIT_REPO=${OPTARG}
        ;;
      d) # set build dir
        ARG_BUILD_DIR=${OPTARG}
        ;;
      b) # set branch
        ARG_BRANCH=${OPTARG}
        ;;
      t) # set tag
        ARG_TAG=${OPTARG}
        ;;
      i) # set identity
        ARG_ID_FILE=${OPTARG}
        ;;
      h) # set host
        ARG_HOST+=("${OPTARG}")
        ;;
      x) # set fast
        ARG_SUPPRESS_BUILD="True"
        ;;
      f) # set fast
        ARG_FAST="True"
        ;;
      :) # no args
        Help;
        ;;
      *) # abnormal args
        Help;
        ;;
   esac
done
# check for required args
if [ -z "$ARG_GIT_REPO" ] || [ -z "$ARG_BUILD_DIR" ]; then
  echo -e "${Red_Text}${On_White}Missing required arguments -r repo or -d directory"
  echo -e "${Reset_Color}"
  Help;
fi

##############################################################################
# Initialize
##############################################################################

if [ "$DEBUG" ]; then
  echo "git repo " "$ARG_GIT_REPO"
  echo "build dir " "$ARG_BUILD_DIR"
  echo "branch " "$ARG_BRANCH"
  echo "tag " "$ARG_TAG"
  echo "identity " "$ARG_ID_FILE"
  echo "supress build" "$ARG_SUPPRESS_BUILD"
  echo "fast flag" "$ARG_FAST"

  echo "host "
  for val in "${ARG_HOST[@]}"; do
      echo " $val"
    done
fi

##############################################################################
# Setup
##############################################################################
Create_Top_Level_Dir
Install_Docusaurus
Install_Web_Content
Install_Branding_Logos


##############################################################################
# Main - Calls Code Based on Arguments Passed In
##############################################################################
Bootstrap_Repo
### Create statics from markdown and config
# run if supress flag not present
if [ -z "$ARG_SUPPRESS_BUILD" ]; then
  Run_Doc6s_Build
fi

##############################################################################
# Remote - Copy and install to remote
##############################################################################
Remote_Upload