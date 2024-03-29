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
#$ name:bashfx-install
#$ author:qodeninja
#$ autobuild: 00001
#$ date:
#-------------------------------------------------------------------------------


#=====================================code!=====================================

  opt_args=("${@}")

#-------------------------------------------------------------------------------
# CONFIG PARAMS
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# CHECK FOR BASIC DEPENDENCIES
#-------------------------------------------------------------------------------

    opt_quiet=1 #default quiet mode
    opt_debug=1
    opt_yes=1
    opt_local=1
    opt_nuke=1
    opt_clean=1
    opt_run=1
    opt_pipe=1
    opt_silly=1

    logo=$(sed -n '3,12 p' $BASH_SOURCE)

    BASH_RC="${HOME}/.bashrc";
    _DEPS_LOCAL=(tput printf sed git find sleep);
    _DEPS_MISSING=();
    FX_INSTALLED=1;

    function command_exists(){
        type "$1" &> /dev/null ;
    }

    function check_deps(){
        local ret=0;
        for dep in "${@}"; do
            if ! command_exists "$dep"; then
                _DEPS_MISSING+=("$dep")
                ret=1
            fi
        done

        return $ret;
    }

#-------------------------------------------------------------------------------
# Term
#-------------------------------------------------------------------------------

    red=$(tput setaf 9)
    green=$(tput setaf 2)
    blue=$(tput setaf 39)
    orange=$(tput setaf 214)
    white=$(tput setaf 248)
    white2=$(tput setaf 15)
    purple=$(tput setaf 213)
    x=$(tput sgr0)
    eol="$(tput el)"
    bld="$(tput bold)"
    tab=$'\t'
    nl=$'\n'
    delta="\xE2\x96\xB3"
    pass="${green}\xE2\x9C\x93"
    fail="${red}\xE2\x9C\x97"
    lambda="\xCE\xBB"
    dots='\xE2\x80\xA6'
    space='\x20'
    line="##---------------$nl"




#-------------------------------------------------------------------------------
# Term
#-------------------------------------------------------------------------------
  
  function stderr(){ printf "${@}${x}\n" 1>&2; }

  function __printf(){
      local text color prefix
      text=${1:-}; color=${2:-white2}; prefix=${!3:-};
      [ $opt_quiet -eq 1 ] && [ -n "$text" ] && printf "${prefix}${!color}%b${x}" "${text}" 1>&2 || :
  }

  function __sleep(){
      [ $opt_yes -eq 1 ] && sleep 1 || :
  }

  function pass(){ local text=${1:-}; __printf "$pass $text\n" "green"; }
  function error(){ local text=${1:-}; __printf "$fail $text\n" "red"; }
  function silly(){ local text=${1:-}; [ $opt_silly   -eq 0 ] && __printf "$dots $text\n" "purple"; }
  function warn(){ local text=${1:-}; [ $opt_debug -eq 0 ] && __printf "$delta $text$x\n" "orange";  }
  function info(){ local text=${1:-}; [ $opt_debug -eq 0 ] && __printf "$lambda $text\n" "blue"; }
  function does(){ local text=${1:-}; [ $opt_debug -eq 0 ] && __printf "$delta $text\n" "purple"; }


  function fatal(){ trap - EXIT; __printf "\n$red$fail $1 $2 \n"; exit 1; }
  function quiet(){ [ -t 1 ] && opt_quiet=${1:-1} || opt_quiet=1; }



#-------------------------------------------------------------------------------
# Sig / Flow
#-------------------------------------------------------------------------------


    function handle_interupt(){ E="$?";  kill 0; exit $E; }
    function handle_stop(){ kill -s SIGSTOP $$; }
    function handle_input(){ [ -t 0 ] && stty -echo -icanon time 0 min 0; }
    function cleanup(){ [ -t 0 ] && stty sane; }

    function fin(){
        local E="$?"; cleanup
        if [ -z "$opt_quiet" ]; then
           [ $E -eq 0 ] && __printf "${green}${pass} ${1:-Done}." \
                        || __printf "$red$fail ${1:-${err:-Cancelled}}."
        fi
    }


#-------------------------------------------------------------------------------
# Traps
#-------------------------------------------------------------------------------

    trap handle_interupt INT
    trap handle_stop SIGTSTP
    trap handle_input CONT
    trap fin EXIT


#-------------------------------------------------------------------------------
# Input
#-------------------------------------------------------------------------------


  function confirm(){
      local ret;ret=1
      __printf "${1}? > " "white2" #Are you sure ?
      [ $opt_yes -eq 0 ] && __printf "${bld}${green}auto yes${x}\n" && return 0;
      [[ -f ${BASH_SOURCE} ]] && src='/dev/stdin' || src='/dev/tty'

      while read -r -n 1 -s answer < $src; do
          [ $? -eq 1 ] && exit 1;
          if [[ $answer = [YyNn10tf+\-q] ]]; then
               [[ $answer = [Yyt1+] ]] && __printf "${bld}${green}yes${x}" && ret=0 || :
               [[ $answer = [Nnf0\-] ]] && __printf "${bld}${red}no${x}" && ret=1 || :
               [[ $answer = [q] ]] && __printf "${bld}${purple}quit${x}\n" && exit 1 || :
              break
          fi
      done
      __printf "\n"
      return $ret
  }


  function prompt(){
    local res ret next __VALUE prompt="$1" prompt_sure="$2" default="$3"
    [[ -f ${BASH_SOURCE} ]] && src='/dev/stdin' || src='/dev/tty'
    while [[ -z "$next" ]]; do
      read -p "${x}$prompt? > ${bld}${green}" __VALUE < $src;
      next=1
      __printf "${x}"
    done
    echo $__VALUE
  }

  function prompt_path(){
    local res ret next __NEXT_DIR
    prompt="$1"
    prompt_sure="$2"
    default="$3"
    prompt=$(eval echo "$prompt")
    [[ -f ${BASH_SOURCE} ]] && src='/dev/stdin' || src='/dev/tty'
    while [[ -z "$next" ]]; do
      read -p "$prompt ($default)$nl > ${bld}${green}" __NEXT_DIR < $src;
      res=$(eval echo $__NEXT_DIR)
      [ -z "$res" ] && res="$default"
      if [ -n "$res" ]; then
        if confirm "${x}${prompt_sure} [ ${blue}$res${x} ] (y/n/q)"; then
          if [ ! -d "$res" ]; then
            error "Couldn't find the directory ($res). Try Again. Or 'q' to exit."
          else
            next=1
          fi
        fi
      else
        warn "Invalid Entry! Try Again."
      fi
    done
    echo "$res"
  }


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
        EOF
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
# Profile Linker
#-------------------------------------------------------------------------------
    


    function rc_link(){
      info "Linking RC..."
      local rc_file="$1" ret res data

      
      if [ -f "$rc_file" ]; then

        src="$BASH_RC" #link to bashrc so vars are available to subshells?

        [ ! -f "$src" ] && touch "$src"
        lbl="$script_id"
        res=$(file_find_block "$src" "$lbl" ); ret=$?;

        if [ $ret -eq 1 ]; then
          data="$(cat <<-EOF
            ${tab} if [ -f "$rc_file" ] ; then
            ${tab}   source "$rc_file"
            ${tab} else
            ${tab}   [ -t 1 ] && { echo "\$(tput setaf 214)$script_rc_file is missing, fx-install link or unlink to fix ${x}";FX_INSTALLED=1; } || :
            ${tab} fi
          EOF
          )";
          res=$(file_add_block "$data" "$src" "$lbl" )
          ret=$?
        else
          warn "RC already linked.";ret=0;
        fi

      else
        err="RC doesnt exist @ $BASH_RC"
        ret=1
      fi
      return $ret
    }

    function rc_unlink(){
      local rc_file="$1" src="$BASH_RC" lbl="$script_id" ret res data
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
          if [[ ! "\$PATH" =~ "\$THIS_BIN" ]]; then
            export PATH=\$PATH:\$THIS_BIN;
          fi
        ${line}
      EOF
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
# FX SUB API
#-------------------------------------------------------------------------------


    function fx_repair_check(){
      if [ $FX_INSTALLED -eq 0 ] && [ -n "$FX_PREFIX" ]; then
        msg="FX is already installed, attempt repair"

        [ $opt_clean -eq 0 ] && { FX_PREFIX=; msg="Clean repair with unset prefix";  }

        if confirm "$msg (y/n/q)"; then
          info "Repairing..."
          __sleep
          api_clean 0
          [ $opt_quiet -eq 1 ] && clear || :
          api_options "${orig_args[@]}"
        else
          exit 0
        fi
      else
        info "Installing... (FX_PREFIX=$FX_PREFIX)"
        __sleep
      fi
    }

    function fx_prefix_check(){
      local res ret;
      FX_OPT_SYS="/opt/fx/this"
      FX_OPT_HOME="$HOME/.this"



      if [ -z "$FX_PREFIX" ]; then
        warn "FX_PREFIX not defined."
        if confirm "Install BASHFX on the default user path [$FX_OPT_HOME] (y/n/q)"; then
          FX_PREFIX="$FX_OPT_HOME"
        else
          FX_PREFIX="$FX_OPT_HOME"
          res=$(prompt_path "Where to set \${blue}FX_PREFIX\$x root directory" "Is this correct" "$FX_PREFIX");ret=$?;
          FX_PREFIX="$res"
        fi
      else
        info "BASHFX will set <FX_PREFIX> and install to [ $FX_PREFIX ]\n"
      fi 
    }


    function fx_vars(){
      if [ -n $FX_PREFIX ]; then
        THIS_LIB="$FX_PREFIX/lib"
        THIS_BIN="$FX_PREFIX/bin"
        THIS_ETC="$FX_PREFIX/etc"
        THIS_DATA="$FX_PREFIX/data"
        THIS_SERV="$HOME/.serv"
        FX_CONF_FILE="$FX_ETC/bashfx.conf"
        MATCH_LINE="source \"$FX_CONF_FILE\""
        REGEX_LINE="^[^#]*\b$MATCH_LINE"
        return 1
      fi
      return 0
    }


    function fx_create_dirs(){
      local FX_DIRS=($THIS_LIB $THIS_BIN $THIS_ETC $THIS_DATA $THIS_SERV);
      for this in "${FX_DIRS[@]}"; do
        [ ! -d $this ] && { info "Creating Directory $this..."; mkdir -p $this; } || info "Directory $this already exists";
        if [ ! -w $this ]; then
          fatal "${red}Install directory [$this] is not writeable. Cannot create directories.${x}\n";
        fi
      done
    }

    function fx_nuke_dirs(){
      info "Nuking Directories..."
      for this in "${FX_DIRS[@]}"; do
        if [ $opt_quiet -eq 1 ]; then
          [ ! -d $this ] && warn "$this does not exist"
          [ -d $this ] && { if confirm "Force remove ${this} dir? (y/n/q)"; then rm -rf $this; fi } || :
          [ -d $this ] && fatal "Unable to remove directory [$this] please check permissions." || :
        else
          rm -rf $this;
        fi
      done

    }


    function fx_rc_file_check(){
      local ret=1;
      if [ -d "$THIS_ETC" ]; then
        FX_CONF_FILE="$THIS_ETC/fx/bashfx.conf"
        #rc_make "$FX_CONF_FILE"
        info 'make rc file here'
      else
        err="Cannot generate rc file!"
      fi

      if [ -f "$FX_CONF_FILE" ]; then
        :
        info 'link profile here'
        #profile_link "$FX_CONF_FILE"
        #rc_dump "$FX_CONF_FILE"
      else
        err="Cannot link rcfile"
        ret=1;
      fi

    }

    function fx_copy_installer(){
      local ret=1 TARGET LINK_DEST

      if [ -d "$THIS_BIN" ] && [ -d "$THIS_LIB" ]; then

        TARGET="$THIS_LIB/fx/fx-install"
        LINK_DEST="$THIS_BIN/fx/fx-install" 

        cp "$BASH_SOURCE" "$TARGET" #copy script to lib
        if [ -f $TARGET ]; then
          if [ ! -L "$LINK_DEST" ]; then
            $(ln -s "$LINK_DEST" "$TARGET"); ret=$?; #link lib=>bin
            [ $ret -eq 1 ] && err="Cannot link installer to $THIS_BIN";
          else
            warn "Installer already linked!"
            ret=0;
          fi
        else
          err="Cannot copy installer (fx-install) to $THIS_LIB"
        fi
      else
        err='Cannot enable installer because bin or lib is missing.'
        ret=1;
      fi
      return $ret

    }

  #show all the FX_* variables set in the environment
  function fx_dump(){
    local len arr i this flag newl 
    [ $opt_quiet -eq 0 ] && return 0;
    newl="\n"
    vars=($(set | grep -E ^THIS_[^=]+=.* | cut -d "=" -f1))
    for this in "${vars[@]}"; do
      printf "$this = ${!this} $newl"
    done
    vars=($(set | grep -E ^FX_[^=]+=.* | cut -d "=" -f1))
    for this in "${vars[@]}"; do
      printf "$this = ${!this} $newl"
    done
  }


#-------------------------------------------------------------------------------
# FX API
#-------------------------------------------------------------------------------



    function api_check_deps(){
        if ! check_deps "${_DEPS_LOCAL[@]}"; then
            fatal "Missing dependencies!" "${_DEPS_MISSING[*]}";
            return 1
        else
            unset _DEPS_MISSING _DEPS_LOCAL dep;
            return 0
        fi
    }


    function api_install(){

     local steps=(fx_repair_check fx_prefix_check fx_vars fx_create_dirs fx_rc_file_check fx_copy_installer)

      for step in "${steps[@]}"; do
        # Call the function and capture its return value
        "$step"
        local step_status=$?

        # Check the status of the step
        if [ $step_status -eq 0 ]; then
          info "Step ($step) completed successfully."
        else 
          warn "Step ($step) was not executed."
        fi

        if [ -n "$err" ]; then
          # Handle the fatal error condition
          error "Step ($step) encountered a fatal error. ($err)"
          break
        fi

      done

      if [ -n "$err" ]; then 
        
        msg="${fail} All files stored in ($FX_PREFIX) will be lost in order to cleanup. Continue? ";
        
        if confirm "$msg (y/n/q)"; then
          info "Cleaning up..."
          __sleep 1
          api_nuke
          err="Installation terminated."
        else
          fatal "Installation terminated." "$err"
        fi

      fi

    }


    function api_nuke(){
      local force=${1:-1};
      if [ $opt_nuke -eq 0 -o $force -eq 0 ]; then
        fx_vars;
        if [ -n $FX_PREFIX -a -d $FX_PREFIX ]; then
          FX_DIRS=($THIS_LIB $THIS_BIN $THIS_ETC $THIS_DATA $THIS_SERV);
          fx_nuke_dirs
        fi
        api_clean 0
      fi
      fx_dump
      return 0
    }



#-------------------------------------------------------------------------------
# FX Main
#-------------------------------------------------------------------------------

    #print usage message
    function usage(){
      info "help"
      block_print 'doc:help'; 
    }


    function api_options(){


        for arg in "${@}"; do
            case "$arg" in
                --quiet|-q)
                    opt_quiet=0
                    opt_yes=0
                    opt_silly=1
                    opt_debug=1
                    info "quiet_mode"
                    info "auto_yes"
                    ;;
                --silly)
                    opt_silly=0
                    opt_debug=0
                    info "silly_mode"
                    ;;
                --pipe|-P)
                    opt_pipe=0
                    info "pipe_simulation"
                    ;;
                --debug|-v)
                    opt_debug=0
                    info "debug_mode"
                    ;;
                --sys*)
                    opt_local=0
                    FX_PREFIX="/opt/fx/this"
                    info "system_install"
                    ;;
                --local)
                    opt_local=1
                    FX_PREFIX="$HOME/.this"
                    info "local_install"
                    ;;
                --nuke)
                    opt_nuke=0
                    ;;
                --clean|-C)
                    opt_clean=0
                    ;;
                --run|-X)
                    opt_run=0
                    info "do_run"
                    ;;
                --yes|-Y)
                    opt_yes=0
                    info "auto_yes"
                    ;;
            esac
        done

    }



    function dispatch(){
      does "try dispatch"
      local call="$1" arg= path= cmd_str= ret;
      case $call in
        help)    cmd="usage";; #doesnt work on mac
        inst*)   cmd="api_install";;
        unin*)   cmd="api_uninstall";;
        dl)      cmd="api_download";;
        nuke)    cmd="api_nuke";;
        *)
          if [ ! -z "$call" ]; then
            die "Invalid command $call";
            ret 1;
          fi
        ;;
      esac

      does "$cmd"
      $cmd;ret=$?;
      [ -n "$err" ] && return 1;
      return $ret;

    }


    function main(){
      local ret args=("${@}")
      printf "\n\n\n\n\n$blue${logo//#/ }\n\tInstall$x\n\n"
      dispatch "$@"; ret=$?;
      [ -n "$err" ] && fatal "$err" || stderr "$out";
      return $ret
    }

#-------------------------------------------------------------------------------
# FX Driver
#-------------------------------------------------------------------------------


    if [ "$0" = "-bash" ]; then
        :
    else

        if api_check_deps; then 

            api_options "${opt_args[@]}"

            if [ ! -t 0 ]; then opt_pipe=0; fi;

            if [ $opt_pipe -eq 0 ]; then

                silly "piped run detected."

                if [ $opt_run -eq 1 ]; then
                    warn "You must opt-in to auto run the script with --run in pipe mode."
                fi
                
            else
              silly "normal run detected"
            fi


            args=( "${opt_args[@]/\-*}" ); #delete anything that looks like an option
            main "${args[@]}";ret=$?


        fi

    fi




#=====================================!code=====================================





#====================================doc:help!==================================
#
#  \n\t${b}fx-install --option [<n>ame] [<p>ath]${x}
#
#  \t${o}home: $FX${x}
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
