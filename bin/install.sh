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
# Config
#-------------------------------------------------------------------------------

	THIS_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" || exit; pwd -P)"
	ROOT_DIR="$( cd "$THIS_DIR" && cd .. || exit; pwd -P)"


	THIS_PATH_USER="/usr/local/my"
	THIS_PATH_HOME="$HOME/.my"

#-------------------------------------------------------------------------------
# Term
#-------------------------------------------------------------------------------

	red=$(tput setaf 9)
	green=$(tput setaf 2)
	blue=$(tput setaf 39)
	blue2=$(tput setaf 27)
	cyan=$(tput setaf 14)
	orange=$(tput setaf 214)
	purple=$(tput setaf 213)
	white=$(tput setaf 248)
	white2=$(tput setaf 15)
	grey=$(tput setaf 244)

	x=$(tput sgr0)
	eol="$(tput el)"
	bld="$(tput bold)"
	line="##---------------$nl"
	tab=$'\t'
	nl=$'\n'

	delta="\xE2\x96\xB3"
	pass="\xE2\x9C\x93"
	fail="${red}\xE2\x9C\x97"
	star="\xE2\x98\x85"
	lambda="\xCE\xBB"
	idots="\xE2\x80\xA6"

  

#-------------------------------------------------------------------------------
# Utils
#-------------------------------------------------------------------------------

	__printf(){
		local text color prefix
		text=${1:-}; color=${2:-white2}; prefix=${!3:-};
		[ $opt_quiet -eq 1 ] && [ -n "$text" ] && printf "${prefix}${!color}%b${x}" "${text}" 1>&2 || :
	}

	confirm(){
		local ret;ret=1
		__printf "${1}? > " "white2" #:-Are you sure ?
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

	__sleep(){
		[ $opt_yes -eq 1 ] && [ $opt_quiet -eq 1 ] && sleep 0.5 || :
	}


	__logo(){
		if [ $opt_quiet -eq 1 ]; then
			local logo=$(sed -n '3,12 p' $BASH_SOURCE)
			printf "\n$blue${logo//#/ }$x\n"
		fi
	}

	error(){ local text=${1:-}; __printf " $text\n" "fail"; }
	warn(){ local text=${1:-}; [ $opt_debug -eq 0 ] &&__printf "$delta  $text$x\n" "orange"; }
	okay(){ local text=${1:-}; [ $opt_debug -eq 0 ] &&__printf "$pass $text$x\n" "green"; }
	info(){ local text=${1:-}; [ $opt_debug -eq 0 ] && __printf "$lambda $text\n" "blue"; }
	trace(){ local text=${1:-}; [ $opt_trace -eq 0 ] && __printf "$idots $text\n" "grey"; }

	fatal(){ trap - EXIT; __printf "\n$red$fail $1 $2 \n"; exit 1; }

	command_exists(){ type "$1" &> /dev/null; }
	# tput sed printf

#-------------------------------------------------------------------------------
# Sig / Flow
#-------------------------------------------------------------------------------


    handle_interupt(){ E="$?";  kill 0; exit $E; }
    handle_stop(){ kill -s SIGSTOP $$; }
    handle_input(){ [ -t 0 ] && stty -echo -icanon time 0 min 0; }
    cleanup(){ [ -t 0 ] && stty sane; }

    fin(){
        local E="$?"; cleanup
        if [ -z "$opt_quiet" ]; then
           [ $E -eq 0 ] && __printf "${green}${pass} ${1:-Done}." \
                        || __printf "$red$fail ${1:-${err:-Cancelled}}."
        fi
    }

    trap handle_interupt INT
    trap handle_stop SIGTSTP
    trap handle_input CONT
    trap fin EXIT


#-------------------------------------------------------------------------------
# SED Utils
#-------------------------------------------------------------------------------
	
	#sed block parses self to find meta data
	sed_block(){
		local id="$1" pre="^[#]+[=]+" post=".*" str end;
		str="${pre}${id}[:]?[^\!=\-]*\!${post}";
		end="${pre}\!${id}[:]?[^\!=\-]*${post}";
		sed -rn "1,/${str}/d;/${end}/q;p" $BASH_SOURCE | tr -d '#'; 
	}

	#prints content between sed block
	block_print(){
		local o=$orange;b=$blue;b2=$blue2;p=$purple;g=$green;r=$red;w=$white2;u=$grey; #shortcut colors
		local lbl="$1" IFS res;
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
	file_marker(){
		local delim dst dend mode="$1" lbl="$2" as="$3"
		dst='#';dend='#';
		[ "$as" = "js" ] && { dst='\/\*'; dend='\*\/'; }|| :
		[ "$mode" = "str" ] && str='str' || str='end'
		echo "${dst}----${block_lbl}:${str}----${dend}"
	}

	#add a block of text wrapped by a block label
	file_add_block(){
		local newval="$1" src="$2" data res ret=1
		res=$(file_find_block "$src")
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
	file_del_block(){
		local src="$1" data res ret dst dend

		#fix clobber
		sed -i.bak "/${match_st}/,/${match_end}/d" "$src";ret=$?
		#sed "/${match_st}/,/${match_end}/d" "$src" < "${src}.bak" > "$src" ;ret=$?

		res=$(file_find_block "$src" "$block_lbl" "${delim}" );ret=$?
		[ $ret -gt 0 ] && ret=0 || ret=1
		rm -f "${src}.bak"
		return $ret
	}

	#find a block by its label
	file_find_block(){
		local src="$1" data res err ret=1
		err="cannot find block ($2)"
		res=$(sed -n "/${match_st}/,/${match_end}/p" "$src")
		[ -z "$res" ] && ret=1;
		[ -n "$res" ] && err= && ret=0;
		echo "$res"
		return $ret;
	}


	file_match(){
		local block_lbl="$1" delim="$2" 
		match_st=$(file_marker "str" "${block_lbl}" "${delim}")
		match_end=$(file_marker "end" "${block_lbl}" "${delim}")
	}



	file_dump(){
		local src="$1" force="$2"
		[ $opt_quiet -eq 0 ] && return 0;
		if [ -f "$src" ]; then
			echo $line${nl}${nl}
			cat "$src"
			echo $line${nl}${nl}
		else
			fatal "File doesnt exist. ($src)"
		fi
	}

	debug_opts(){
		trace 'debug opts'
		local this vars=($(set | grep -E ^opt_[^=]+=.* | cut -d "=" -f1))
		for this in "${vars[@]}"; do
			printf "$this = ${!this} $nl"
		done    
	}

	debug_vars(){
		fx_vars;
		trace 'debug vars'
		local this vars=($(set | grep -E ^FX_[^=]+=.* | cut -d "=" -f1))
		for this in "${vars[@]}"; do
			printf "$this = ${!this} $nl"
		done  
	}

#-------------------------------------------------------------------------------
# FX UTIL
#-------------------------------------------------------------------------------

	create_dirs(){
		local prefix="$FX_PREFIX" rel_dirs this
		rel_dirs=("lib/bashfx" "etc/bashfx" bin priv data);

		local FX_DIRS=($FX_LIB $FX_BIN $FX_ETC $FX_DATA $FX_SERV);

		for this in "${rel_dirs[@]}"; do
			this="${prefix}/${this}"
			[ ! -w $this ] && fatal "Install directory [$this] is not writeable. Exiting." || :;
			[ ! -d $this ] && { info "Creating Directory $this..."; mkdir -p $this; } || info "Directory $this already exists";
		done
	}

	# FX_DIRS=($FX_LIB $FX_BIN $FX_ETC $FX_PRIV $FX_DATA);  

	nuke_dirs(){
			local prefix="$FX_PREFIX" this rel_dirs
			trace "Nuking Directories..."
			rel_dirs=("lib/bashfx" "etc/bashfx" bin priv data);
			for this in "${rel_dirs[@]}"; do
				[ ! -d $this ] && warn "$this does not exist"
				[ -d $this ] && { if confirm "Force remove ${this} dir? (y/n)"; then rm -rf $this; fi } || :
				[ -d $this ] && fatal "Unable to remove directory [$this] please check permissions." || :
			done
	}

#-------------------------------------------------------------------------------
# RC File
#-------------------------------------------------------------------------------
	has_rc_file(){
		[ -f "$FX_CONF_FILE" ] && return 0;
		return 1
	}


	rc_file_str(){
		trace "generate rcfile string..."
		local data
		data+=""
		data="$(cat <<-EOF
			#!/usr/bin/bash
			${line}
			### bashfx install generated config file $(date)
				export FX_INSTALLED=0
				export FX_PREFIX="$FX_PREFIX"
				if [[ ! "\$PATH" =~ "\$FX_BIN" ]]; then
					export PATH=\$PATH:\$FX_BIN;
				fi
			${line}
		EOF
		)";
		echo "$data"
	}


	rc_make(){
		local src="$FX_CONF_FILE" rc_str
		trace "make rc file..."

		has_rc_file && { warn "RC File already exists."; return 0; }

		if ! has_rc_file; then
			if [ -d "$FX_ETC" ]; then
				rc_str="$(rc_file_str)"
				echo -e "$rc_str" > ${src}
				[ -f "${src}" ] && okay "RC File created. ($rc_str)" || :
				return 0 
			else
				warn "$FX_ETC is missing!"
			fi
		fi

		err="Cannot make rc file!"
		return 1;
	}


	rc_load(){
		local list len 
		trace "find rcfile and load..."
		list=($(find "$THIS_PATH_HOME" "$THIS_PATH_USER" -type f -name "$FX_CONF_NAME" 2>/dev/null))
		len=${#list[@]}

		if [ $len -gt 0 ]; then
			source "${list[0]}"
			[ $FX_INSTALLED -eq 0 ] && fx_vars || :;
			return 0
		else
			warn "Could not find local $FX_CONF_NAME"
			return 1
		fi

	}


	rc_nuke(){
		[ -f "$FX_CONF_FILE" ] && rm "$FX_CONF_FILE" || :;
		[ -f "$FX_CONF_FILE" ] && fatal "Unable to delete conf file for cleanup" || :;
		#[ $force -eq 0 ] && fx_unset 0 || fx_unset
	}



#-------------------------------------------------------------------------------
# Profile Linker
#-------------------------------------------------------------------------------
	has_link(){
		local res ret=1 src="$FX_BASH_PROFILE"
		res=$(file_find_block "$src" "$script_id" ); ret=$?;
		return $ret;
	}


	profile_str(){
		trace "generate profile string"
		local data rc_file="$1"
		data+=""
		data="$(cat <<-EOF
			${tab} if [ -f "$rc_file" ] ; then
			${tab}   source "$rc_file"
			${tab} else
			${tab}   [ -t 1 ] && { echo "\$(tput setaf 214) $rc_file is missing, fx repair to fix ${x}";FX_INSTALLED=1; } || :
			${tab} fi
		EOF
		)";
		echo "$data"
	}


	profile_link(){
		trace "linking profile"
		local rc_file="$1" src ret res data
		if [ -f "$rc_file" ]; then

			src="$FX_BASH_PROFILE" #link to bashrc so vars are available to subshells?
			[ ! -f "$src" ] && touch "$src"

			if ! has_link; then
				data="$(profile_str $rc_file)";
				res=$(file_add_block "$data" "$src" "$script_id" )
				ret=$?
				okay "Profile linked."
			else
				warn "Profile already linked.";ret=0;
			fi

		else
			err="RCFILE doesnt exist @ $rc_file, cannot link!"
			ret=1
		fi

		return $ret
	}


	profile_unlink(){
		trace "unlinking profile..."
		local rc_file="$1" src="$FX_BASH_PROFILE" ret=1 
		if has_link; then
			res=$(file_del_block "$src" "$script_id" ); ret=$?
			[ $ret -eq 0 ] && okay "Profile unlinked." || :;
		else
			warn "Already unlinked."
		fi
		return $ret;
	}


#-------------------------------------------------------------------------------
# FX API
#-------------------------------------------------------------------------------
	
	fx_vars(){
		if [ -n $FX_PREFIX ]; then
			trace "setting vars..."
			FX_LIB="$FX_PREFIX/lib/bashfx"
			FX_BIN="$FX_PREFIX/bin/bashfx"
			FX_ETC="$FX_PREFIX/etc/bashfx"
			FX_PRIV="$FX_PREFIX/priv"
			FX_DATA="$FX_PREFIX/data"
			FX_CONF_NAME="fx.rc"
			FX_CONF_FILE="$FX_ETC/$FX_CONF_NAME"

			#find link
			#res=$(file_find_block "$FX_BASH_PROFILE" "$script_id" );ret=$?;
			#islinked=$ret;

			#find rcfile
			[ -f "$FX_CONF_FILE" ] && hasRCfile=0 || hasRCfile=1;

			return 0
		fi
		trace "vars not set..."
		return 1
	}


	fx_unset(){
		local vars 
		trace "Unsetting Vars..."
		if [ -n "$1" -o $opt_yes -eq 0 ] || confirm "Unset all BASHFX variables for the current shell? (y/n)"; then
			vars=($(set | grep -E ^FX_[^=]+=.* | cut -d "=" -f1))
			for v in "${vars[@]}"; do
				warn "removing ${v}"
				unset "$v" 2> /dev/null
			done
			unset vars 2> /dev/null
		fi
	}


	fx_prefix(){
		trace "getting prefix..."
		#option flag set
		if [ -z "$FX_PREFIX" -a $opt_system -eq 0 ]; then
			FX_PREFIX="$THIS_PATH_USER"
		fi

		#prompt user if param passed
		if [ -n "$1" ]; then

			if [ -z "$FX_PREFIX" ]; then
				if confirm "Set default FX_PREFIX to [$THIS_PATH_HOME] (y/n=custom)?"; then
					FX_PREFIX="$THIS_PATH_HOME"
				else
					FX_PREFIX="$THIS_PATH_USER"
				fi
			fi

		else
			#default
			FX_PREFIX="$THIS_PATH_HOME"
		fi

		info "FX_PREFIX set to [$FX_PREFIX]"
	}



	fx_show_file(){
		trace "dumping file..."
		local call="$1" arg="$2" cmd= ret=0;
		case $call in
			rc*)   file_dump "$FX_CONF_FILE";; 
			prof*) file_dump "$FX_BASH_PROFILE";;
			*)
				err="Invalid file => $call";
				ret=1;
			;;
		esac
		[ -n "$err" ] && error "$err";
		return $ret;

	}


	fx_link(){
		if [ -f "$FX_CONF_FILE" ]; then
			profile_link "$FX_CONF_FILE"
		else
			err="Cannot link rcfile ($FX_CONF_FILE)"
		fi
	}


	fx_unlink(){
		trace "unlinking..."
		profile_unlink $FX_CONF_FILE;
	}

	fx_nuke_dirs(){
	  trace "nuking Directories..."
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

#-------------------------------------------------------------------------------
# FX Main
#-------------------------------------------------------------------------------
 
 	status(){
		debug_opts
		debug_vars
	}


	#print usage message
	usage(){
		block_print 'doc:help'; 
	}

	#parse options
	options(){
		
		FX_INSTALLED=1
		FX_CONF_NAME="fx.rc"

		opt_dump=1
		opt_debug=1
		opt_quiet=1
		opt_yes=1
		opt_system=1
		opt_nuke=1
		opt_trace=1


		for arg in "${@}"; do
			case "$arg" in
				--quiet|-q)
					opt_quiet=0
					opt_yes=0
					;;
				--tra*|-t)
					opt_trace=0
					opt_debug=0
					opt_quiet=1
					;;
				--debug|-v)
					opt_debug=0
					opt_quiet=1
					;;
				--dump|-D)
					opt_dump=0
					;;
				--sys*)
					opt_system=0
					;;
				--nuke)
					opt_nuke=0
					;;
				--yes)
					opt_yes=0
					;;
			esac
		done

		rc_load;
		fx_prefix;
		fx_vars;

		FX_BASH_PROFILE="${HOME}/.profile"
		[ -f "$FX_BASH_PROFILE" ] || FX_BASH_PROFILE="$HOME/.bash_profile";

	}


#-------------------------------------------------------------------------------
# FX API
#-------------------------------------------------------------------------------
  api_check_deps(){
    _deps=(tput printf sed git find sleep);
 		_missing=();
    if ! command_exists "${_deps[@]}"; then
        fatal "Missing dependencies!" "${_missing[*]}";
        return 1
    else
        unset _missing _deps dep;
        return 0
    fi
  }

	api_install(){
		create_dirs
		rc_make
		fx_link
	}

	api_uninstall(){
		:
	}
	
	api_nuke(){
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
	

	api_clean(){
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

	api_repair(){
		:
		#has prefix

		#vars ready
		#directories
		#rc file
		#profile
		#profile link
	}

#-------------------------------------------------------------------------------
# FX Main
#-------------------------------------------------------------------------------
 
	dispatch(){

		local call="$1" arg="$2" cmd= ret;
		case $call in
			help)    cmd="usage";; #doesnt work on mac
			stat*)   cmd="status"; opt_dump=1;;#no need to do this twice
			inst*)   cmd="api_install";;
			vars*)   cmd="fx_vars";;
			rc*)     cmd="rc_make";;  
			rmrc*)   cmd="rc_nuke";;
			link*)   cmd="fx_link";;
			unli*)   cmd="fx_unlink";;
			show*)   cmd="fx_show_file";;
			nuke*)   cmd="api_nuke";;
			#unin*)   cmd="api_uninstall";;
			#dl)       cmd="api_download";;
			*)
				if [ ! -z "$call" ]; then
					err="Invalid command => $call";
				fi
			;;
		esac

		trace "dispatch: $cmd ($arg)"

		$cmd "$arg";ret=$?;
		[ -n "$err" ] && error "$err";
		return $ret;
	}

	main(){
		local args=("${@}")
		__logo
		file_match "$script_id" #setup match blocks
		dispatch "${args[@]}";ret=$?
		[ $opt_dump -eq 0 ] && status || :;
		return $ret
	}

#-------------------------------------------------------------------------------
# FX Driver
#-------------------------------------------------------------------------------


	if [ "$0" = "-bash" ]; then
		:
	else
		if api_check_deps; then

			orig_args=("${@}")
			options "${orig_args[@]}";
			args=( "${orig_args[@]/\-*}" ); #delete anything that looks like an option
			main "${args[@]}";ret=$?

		fi
	fi




#-------------------------------------------------------------------------------
#=====================================!code=====================================
#====================================doc:help!==================================
#  \n\t${b}fx-install <cmd> [--options]${x}
#
#  \t${w}Commands:${x}
#		
#  \t${u}inst uninst
#  \t${u}help stat
#  \t${u}rc rmrc
#  \t${u}link unlink
#  \t${u}vars
#
#  \t${u}--quiet  : disable versbosity, useful for subshells
#  \t${u}--debug  : level 1 verbosity
#  \t${u}--trace  : level 2 verbosity
#  \t${u}--system : sets default prefix to system path
#  \t${u}--local  : sets default prefi to user path
#  \t${u}--nuke   : nuke folders and files as needed
#  \t${u}--clean  : reset vars and rc files
#  \t${u}--yes    : respond yes to all prompts
#
#  \t${w}Meta:${x}
#
#  \t${o}home: $FX_PREFIX${x}
#  \t${o}linked: $FX_BASH_PROFILE${x}
#  \t${o}rcfile($hasRCfile): $FX_CONF_FILE ${x}
#
#${x}
#=================================!doc:help=====================================





