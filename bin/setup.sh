#!/usr/bin/env bash
#===============================================================================
#
#  ________  ________  ________  ___  ___  ________ ___    ___ 
# |\   __  \|\   __  \|\   ____\|\  \|\  \|\  _____|\  \  /  /|
# \ \  \|\ /\ \  \|\  \ \  \___|\ \  \\\  \ \  \__/\ \  \/  / /
#  \ \   __  \ \   __  \ \_____  \ \   __  \ \   __\\ \    / / 
#   \ \  \|\  \ \  \ \  \|____|\  \ \  \ \  \ \  \_| /     \/  
#    \ \_______\ \__\ \__\____\_\  \ \__\ \__\ \__\ /  /\   \  
#     \|_______|\|__|\|__|\_________\|__|\|__|\|__|/__/ /\ __\ 
#                        \|_________|              |__|/ \|__| 
#                                                             
#-------------------------------------------------------------------------------
#$ name:bashfx-setup
#$ author:qodeninja
#$ date:
#$ semver:
#$ autobuild: 00004
#-------------------------------------------------------------------------------
#=====================================code!=====================================

#-------------------------------------------------------------------------------
# Meta
#-------------------------------------------------------------------------------

  readonly script_pid=$$
  readonly script_author="qodeninja"
  readonly script_id="bashfx"
  readonly script_prefix="FX"
  readonly script_rc_file=".fxrc"
  readonly script_log_file="$script_id.log"

#-------------------------------------------------------------------------------
# Term
#-------------------------------------------------------------------------------

  red=$(tput setaf 1)
  green=$(tput setaf 2)
  blue=$(tput setaf 12)
  orange=$(tput setaf 214)
  white=$(tput setaf 248)
  white2=$(tput setaf 15)
  x=$(tput sgr0)
  eol="$(tput el)"
  bld="$(tput bold)"
  line="##---------------$nl"
  tab=$'\t'
  nl=$'\n'
  delta="${orange}\xE2\x96\xB3"
  pass="${green}\xE2\x9C\x93"
  fail="${red}\xE2\x9C\x97"
  lambda="\xCE\xBB"
  logo=$(sed -n '6,11 p' $BASH_SOURCE)

#-------------------------------------------------------------------------------
# Utils
#-------------------------------------------------------------------------------

  function __printf(){
    local text color prefix
    text=${1:-}; color=${2:-white2}; prefix=${!3:-};
    [ $opt_quiet -eq 1 ] && [ -n "$text" ] && printf "${prefix}${!color}%b${x}" "${text}" 1>&2 || :
  }

  function confirm(){
    local ret;ret=1
    __printf "${1}? > " "white2" #:-Are you sure ?
    [ $opt_yes -eq 0 ] && __printf "${bld}${green}auto yes${x}\n" && return 0;
    [[ -f ${BASH_SOURCE} ]] && src='/dev/stdin' || src='/dev/tty'

    while read -r -n 1 -s answer < $src; do
      [ $? -eq 1 ] && exit 1;
      if [[ $answer = [YyNn10tf+\-q] ]]; then
        [[ $answer = [Yyt1+] ]] && __printf "${bld}${green}yes${x}" && ret=0 || :
        [[ $answer = [Nnf0\-] ]] && __printf "${bld}${red}no${x}" && ret=1 || :
        [[ $answer = [q] ]] && __printf "\n" && exit 1 || :
        break
      fi
    done
    __printf "\n"
    return $ret
  }

  function __sleep(){
    [ $opt_yes -eq 1 ] && sleep 1 || :
  }

  function error(){ local text=${1:-}; __printf " $text\n" "fail"; }
  function warn(){ local text=${1:-}; __printf " $text$x\n" "delta";  }
  function info(){ local text=${1:-}; [ $opt_debug -eq 0 ] && __printf "$lambda $text\n" "blue"; }
  function does(){ local text=${1:-}; [ $opt_debug -eq 0 ] && __printf "$delta $text\n" "white2"; }

  function die(){ __printf "\n$fail $1 "; exit 1; }


#-------------------------------------------------------------------------------
# SED Utils
#-------------------------------------------------------------------------------
  
  #sed block parses self to find meta data
  function sed_block(){
    local id="$1" pre="^[#]+[=]+" post=".*" str end;
    str="${pre}${id}[:]?[^\!=\-]*\!${post}";
    end="${pre}\!${id}[:]?[^\!=\-]*${post}";
    sed -rn "1,/${str}/d;/${end}/q;p" $BASH_SOURCE | tr -d '#'; 
  }

  #prints content between sed block
  function block_print(){
    local lbl="$1" IFS res;
    info "try block print"
    res=$(sed_block $lbl);
    if [ ${#res} -gt 0 ]; then
      while IFS= read -r line; do
        [[ $lbl =~ doc*|inf* ]] && line=$(eval "printf '%b' \"$line\"");
        echo "$line"
      done  <<< "$res";
    else
      return 1;
    fi
  }

  #create a block label using comments
  function file_marker(){
    local delim dst dend mode="$1" lbl="$2" as="$3"
    dst='#';dend='#';
    [ "$as" = "js" ] && { dst='\/\*'; dend='\*\/'; }|| :
    [ "$mode" = "str" ] && str='str' || str='end'
    echo "${dst}----${block_lbl}:${str}----${dend}"
  }

  #add a block of text wrapped by a block label
  function file_add_block(){
    local newval="$1" src="$2" block_lbl="$3" delim="$4" match_st match_end data res ret=1
    match_st=$(file_marker "str" "${block_lbl}" "${delim}" )
    match_end=$(file_marker "end" "${block_lbl}" "${delim}" )
    res=$(file_find_block "$src" "$block_lbl" "${delim}" )
    ret=$?
    if [ $ret -gt 0 ]; then #nomatch ret=1
      data="$(cat <<-EOF
        ${match_st}
        ${newval}
        ${match_end}
EOF #indents with spaces =(
      )";
      echo "$data" >> $src
      ret=$?
    else
      ret=1
    fi
    return $ret
  }

  #delete everything within in a block including label
  function file_del_block(){
    local src="$1" block_lbl="$2" delim="$3" match_st match_end data res ret dst dend
    match_st=$(file_marker "str" "${block_lbl}" "${delim}" )
    match_end=$(file_marker "end" "${block_lbl}" "${delim}" )
    #fix clobber
    sed -i.bak "/${match_st}/,/${match_end}/d" "$src";ret=$?
    #sed "/${match_st}/,/${match_end}/d" "$src" < "${src}.bak" > "$src" ;ret=$?
    res=$(file_find_block "$src" "$block_lbl" "${delim}" );ret=$?
    [ $ret -gt 0 ] && ret=0 || ret=1
    rm -f "${src}.bak"
    return $ret
  }

  #find a block by its label
  function file_find_block(){
    local src="$1" block_lbl="$2" delim="$3" match_st match_end data res ret=1
    match_st=$(file_marker "str" "${block_lbl}" "${delim}")
    match_end=$(file_marker "end" "${block_lbl}" "${delim}")
    res=$(sed -n "/${match_st}/,/${match_end}/p" "$src")
    [ -z "$res" ] && ret=1 || ret=0;
    echo "$res"
    return $ret;
  }


#-------------------------------------------------------------------------------
# FX Util Helpers
#-------------------------------------------------------------------------------

  #download a bash script NOT DONE
  function fx_download(){
    local URL=$1 TARGET=$2 TEMP=$(mktemp /tmp/fx.XXXXXXXX)
    info "Temp file is $TEMP"

    [ -f $TARGET ] && { warn "File $TARGET already exists"; return 0; } || :
    wget -q -O $TEMP $URL

    if [ -f "$TEMP" ]; then
       [ -d "$FX_BIN" ] && {
        mv "$TEMP" "$TARGET"
        if confirm "Enable local execution of $(basename $TARGET)"; then
          chmod +x "$TARGET"
        else
          warn "Be sure to set execution permission on $TARGET (chmod +x)"
        fi
        [ -f "$TARGET" ] && return 0
      } || :
    else
      :
    fi
    return 1
  }

  #show all the FX_* variables set in the environment
  function fx_dump(){
    local len arr i this flag newl
    [ $opt_quiet -eq 0 ] && return 0;
    newl="\n"
    vars=($(set | grep -E ^FX_[^=]+=.* | cut -d "=" -f1))
    for this in "${vars[@]}"; do
      printf "$this = ${!this} $newl"
    done
  }

  #setting FX variables based on prefix
  function fx_vars(){
    if [ -n $FX_PREFIX ]; then
      FX_LIB="$FX_PREFIX/lib/bashfx"
      FX_BIN="$FX_PREFIX/bin/bashfx"
      FX_ETC="$FX_PREFIX/etc/bashfx"
      FX_PRIV="$FX_PREFIX/priv/"
      FX_DATA="$FX_PREFIX/data/"
      FX_CONF_FILE="$FX_ETC/bashfx.conf"
      THIS_LINE="source \"$FX_CONF_FILE\""
      REGEX_LINE="^[^#]*\b$THIS_LINE"
      return 1
    fi
    return 0
  }

  #roll out sub dirs for fx - call fx_vars before
  function create_dirs(){
    FX_DIRS=($FX_LIB $FX_BIN $FX_ETC $FX_PRIV $FX_DATA);
    for this in "${FX_DIRS[@]}"; do
      [ ! -d $this ] && { info "Creating Directory $this..."; mkdir -p $this; } || info "Directory $this already exists";
      if [ ! -w $this ]; then
        __printf "${red}Install directory [$this] is not writeable. Exiting.${x}\n";
        exit 1;
      fi
    done
  }

  #nuke dirs with confirm
  function nuke_dirs(){
    info "Nuking Directories..."
    for this in "${FX_DIRS[@]}"; do
      [ ! -d $this ] && warn "$this does not exist"
      [ -d $this ] && { if confirm "Force remove ${this} dir? (y/n)"; then rm -rf $this; fi } || :
      [ -d $this ] && die "Unable to remove directory [$this] please check permissions." || :
    done

  }


  #clear FX variables
  function fx_unset(){
    info "Unsetting Vars..."
    if [ -n "$1" -o $opt_yes -eq 0 ] || confirm "Unset all BASHFX variables for the current shell? (y/n)"; then
      vars=($(set | grep -E ^FX_[^=]+=.* | cut -d "=" -f1))
      for v in "${vars[@]}"; do
        warn "removing ${v}"
        unset "$v" 2> /dev/null
      done
      unset vars 2> /dev/null
    fi
  }

  #print usage message
  function usage(){
    info "help"
    block_print 'doc:help'; 
  }

#-------------------------------------------------------------------------------
# Profile Linker
#-------------------------------------------------------------------------------

  function profile_link(){
    info "Linking profile..."
    local rc_file="$1" ret res data
    if [ -f "$rc_file" ]; then
      src="$FX_BASH_PROFILE" #link to bashrc so vars are available to subshells?
      [ ! -f "$src" ] && touch "$src"
      lbl="$script_id"
      res=$(file_find_block "$src" "$lbl" ); ret=$?;

      if [ $ret -eq 1 ]; then
        data="$(cat <<-EOF
          ${tab} if [ -f "$rc_file" ] ; then
          ${tab}   source "$rc_file"
          ${tab} else
          ${tab}   [ -t 1 ] && { echo "\$(tput setaf 214)$script_rc_file is missing, fx link or unlink to fix ${x}";FX_INSTALLED=1; } || :
          ${tab} fi
EOF #space indent
        )";
        res=$(file_add_block "$data" "$src" "$lbl" )
        ret=$?
      else
        warn "Profile already linked.";ret=0;
      fi

    else
      error "Profile doesnt exist @ $FX_BASH_PROFILE"
      ret=1
    fi
    return $ret
  }

  function profile_unlink(){
    local rc_file="$1" src="$FX_BASH_PROFILE" lbl="$script_id" ret res data
    [ -f "$rc_file" ] && rm -f "$rc_file" || :
    res=$(file_del_block "$src" "$lbl" ); ret=$?
    [ $ret -eq 0 ] && __printf "bashfx.conf removed from $rc_file\n" "red" ||:
  }


#-------------------------------------------------------------------------------
# RC File
#-------------------------------------------------------------------------------

  function rc_file_str(){
    local data
    data+=""
    data="$(cat <<-EOF
      #!/usr/bin/bash
      ${line}
      ### bashfx install generated config file $(date)
        export FX_INSTALLED=0
        export FX_PREFIX="$FX_PREFIX"
        export FX_BIN="$FX_BIN"
        if [[ ! "\$PATH" =~ "\$FX_BIN" ]]; then
          export PATH=\$PATH:\$FX_BIN;
        fi
      ${line}
EOF  #space indent
    )";
    echo "$data"
  }


  function rc_make(){
    local show src rc_str
    info "Saving $1 file..."
    src="$1"
    if [ -n $src ]; then
      rc_str="$(rc_file_str)"
      echo -e "$rc_str" > ${src}
    fi
    [ -f "${src}" ] && return 0 || return 1;
  }


  function rc_dump(){
    local src="$1"
    [ $opt_quiet -eq 0 ] && return 0;
    if [ -f "$src" ]; then
      echo $line${nl}
      cat "$src"
    else
      die "RC File doesnt exist. ($src)"
    fi
  }


#-------------------------------------------------------------------------------
# FX API
#-------------------------------------------------------------------------------

  function api_download(){
    fx_vars; 
    fx_download;  
  }

  function api_options(){

    local this next opts=("${@}");

    opt_debug=1
    opt_quiet=1
    opt_yes=1
    opt_local=1
    opt_nuke=1
    opt_clean=1
    opt_custom=1

    FX_THIS_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" || exit; pwd -P)"
    FX_ROOT_DIR="$( cd "$FX_THIS_DIR" && cd .. || exit; pwd -P)"

    FX_INSTALLED=1
    FX_OPT_USER="/usr/local/my"
    FX_OPT_HOME="$HOME/.my"

    FX_PKG_URL="https://git.io/fx-pkg"
    FX_SETUP_URL="https://git.io/fx-setup"
    FX_UTIL_URL="https://git.io/fx-util"

    FX_BASH_PROFILE="${HOME}/.profile"

    [ -f "$FX_BASH_PROFILE" ] || FX_BASH_PROFILE="$HOME/.bash_profile"

    #for arg in "${@}"; do

    for ((i=0; i<${#opts[@]}; i++)); do
      this=${opts[i]}
      next=${opts[i+1]}
      case "$this" in
        --quiet)
          opt_quiet=0
          opt_yes=0
          ;;
        --debug)
          opt_debug=0
          ;;
        --system)
          #this requires usr local to be writeable by user
          die "Please use --local flag, --system no longer supported"
          opt_local=1
          FX_PREFIX="/usr/local/my"
          ;;
        --local)
          opt_local=0
          FX_PREFIX="$HOME/.my"
          ;;
        --custom)
          warn "Using custom prefix path=${next}"
          opt_custom=0
          FX_PREFIX="$next"
          if confirm "Is this custom prefix correct ($FX_PREFIX) (y/n=cancel)"; then
            continue
          else
            FX_PREFIX=
            exit 1
          fi
          ;;
        --nuke)
          opt_nuke=0
          ;;
        --clean)
          opt_clean=0
          ;;
        --yes)
          opt_yes=0
          ;;
      esac
    done

    list=($(find "$FX_OPT_HOME" "$FX_OPT_USER" -type f -name "bashfx.conf"))
    len=${#list[@]}

    if [ $len -gt 0 ]; then
      source "${list[0]}"
    else
      info "Could not find local bashfx.conf"
    fi

    [ $FX_INSTALLED -eq 0 ] && fx_vars || :

    info "FX_PREFIX defined? ($FX_PREFIX)"
  }


  function api_install(){

    if [ $FX_INSTALLED -eq 0 ] && [ ! -z "$FX_PREFIX" ]; then
      msg="FX is already installed, attempt repair"

      [ $opt_clean -eq 0 ] && { FX_PREFIX=; msg="Clean repair with unset prefix";  }

      if confirm "$msg (y/n=cancel)"; then
        info "Repairing..."
        __sleep
        api_clean 0
        [ $opt_quiet -eq 1 ] && clear || :
        api_options "${orig_args[@]}"
      else
        exit 0
      fi
    else
      info "Installing... ($FX_PREFIX)"
      __sleep
    fi

    if [ -z "$FX_PREFIX" ]; then
      warn "FX_PREFIX not defined."
      if confirm "Install BASHFX for just the current user [$HOME/.my] (y/n)"; then
        FX_PREFIX="$FX_OPT_HOME"
      else
        FX_PREFIX="$FX_OPT_USER"
      fi
    else
      info "BASHFX will set <FX_PREFIX> and install to [ $FX_PREFIX ]\n"
    fi

    fx_vars;
    create_dirs;

    if [ -d "$FX_ETC" ]; then
      FX_CONF_FILE="$FX_ETC/bashfx.conf"
      rc_make "$FX_CONF_FILE"
    else
      err="Cannot generate rc file!"
    fi

    if [ -f "$FX_CONF_FILE" ]; then
      profile_link "$FX_CONF_FILE"
      rc_dump "$FX_CONF_FILE"
    else
      err="Cannot link rcfile"
    fi

    if fx_download "$FX_SETUP_URL" "$FX_BIN/fx-setup"; then
      info "FX-SETUP installed to $FX_BIN"
    else
      err="Cannot download fx-setup, try again!"
    fi

    if fx_download "$FX_PKG_URL" "$FX_BIN/fx-pkg"; then
      info "FX-PKG installed to $FX_BIN"
    else
      err="Cannot download fx-pkg, try again!"
    fi

    if fx_download "$FX_UTIL_URL" "$FX_BIN/fx"; then
      info "FX-UTIL installed to $FX_BIN"
    else
      err="Cannot download fx-util, try again!"
    fi

    ls $FX_BIN

    [ ! -z "$err" ] && die "$err" || { info "Refresh shell to load FX vars; use <fx> or <fx-setup>";
      return 0; }

  }

  function api_uninstall(){
    api_nuke 0
    info "Refresh terminal to clear remaining FX vars"
  }


  function api_clean(){
    local force=${1:-1};
    if [ $opt_clean -eq 0 -o $opt_nuke -eq 0 -o $force -eq 0 ]; then
      info "Cleaning..."
      profile_unlink $FX_CONF_FILE;
      [ -f $FX_CONF_FILE ] && rm $FX_CONF_FILE || :;
      [ -f "$FX_CONF_FILE" ] && die "Unable to delete conf file for cleanup" || :
      [ $force -eq 0 ] && fx_unset 0 || fx_unset
    else
      printf "Didnt clean $opt_clean"
    fi
    return 0
  }


  function api_nuke(){
    local force=${1:-1};
    if [ $opt_nuke -eq 0 -o $force -eq 0 ]; then
      fx_vars;
      if [ -n $FX_PREFIX -a -d $FX_PREFIX ]; then
        FX_DIRS=($FX_LIB $FX_BIN $FX_ETC $FX_PRIV $FX_DATA);
        nuke_dirs
      fi
      api_clean 0
    fi
    fx_dump
    return 0
  }

#-------------------------------------------------------------------------------
# FX Main
#-------------------------------------------------------------------------------

  function dispatch(){
    does "try dispatch"
    local call="$1" arg= path= cmd_str= ret;
    case $call in
      help)    cmd="usage";; #doesnt work on mac
      inst*)   cmd="api_install";;
      unin*)   cmd="api_uninstall";;
      dl)      cmd="api_download";;
      *)
        if [ ! -z "$call" ]; then
          die "Invalid command $call";
          ret 1;
        fi
      ;;
    esac

    does "$cmd"
    [ -n "$err" ] && return 1;
    $cmd;ret=$?;
    return $ret;
  }


  function main(){
    does "try main"
    local args=("${@}")
    dispatch "${args[@]}";ret=$?
    return $ret
  }

#-------------------------------------------------------------------------------
# FX Driver
#-------------------------------------------------------------------------------


  if [ "$0" = "-bash" ]; then
    :
  else
    orig_args=("${@}")
    api_options "${orig_args[@]}"
    args=( "${orig_args[@]/\-*}" ); #delete anything that looks like an option
    main "${args[@]}";ret=$?
  fi





#-------------------------------------------------------------------------------
#=====================================!code=====================================
#====================================doc:help!==================================
#
#  \n\t${b}fx-setup --option [<n>ame] [<p>ath]${x}
#
#  \t${o}home: $MY_MARK${x}
#  \t${o}size: ($count)${x}
#  \t${w}Commands:${x}
#
#  \t${b}--quiet
#  \t${b}--debug
#  \t${b}--system
#  \t${b}--local
#  \t${b}--nuke
#  \t${b}--clean  : 
#  \t${b}--yes    : respond yes to all prompts
#
#=================================!doc:help=====================================













