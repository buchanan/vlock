#!%BOURNE_SHELL%

# ignore some signals
trap : HUP INT QUIT TSTP

# exit on error
set -e

# magic characters to clear the terminal
CLEAR_SCREEN="`echo -e '\033[H\033[J'`"

VLOCK_ENTER_PROMPT="Please press [ENTER] to unlock."

# message that is displayed when console switching is disabled
VLOCK_ALL_MESSAGE="${CLEAR_SCREEN}\
The entire console display is now completely locked.
You will not be able to switch to another virtual console.

${VLOCK_ENTER_PROMPT}"

# message that is displayed when only the current terminal is locked
VLOCK_CURRENT_MESSAGE="${CLEAR_SCREEN}\
This TTY is now locked.

${VLOCK_ENTER_PROMPT}"

# read user settings
if [ -r "${HOME}/.vlockrc" ] ; then
  . "${HOME}/.vlockrc"
fi

VLOCK_MAIN="%PREFIX%/sbin/vlock-main"
VLOCK_PLUGIN_DIR="%PREFIX%/lib/vlock/modules"
VLOCK_VERSION="%VLOCK_VERSION%"

print_help() {
  echo >&2 "vlock: locks virtual consoles, saving your current session."
  echo >&2 "Usage: vlock [options]"
  echo >&2 "       Where [options] are any of:"
  echo >&2 "-c or --current: lock only this virtual console, allowing user to"
  echo >&2 "       switch to other virtual consoles."
  echo >&2 "-a or --all: lock all virtual consoles by preventing other users"
  echo >&2 "       from switching virtual consoles."
  echo >&2 "-n or --new: allocate a new virtual console before locking,"
  echo >&2 "       implies --all."
  echo >&2 "-s or --disable-sysrq: disable SysRq while consoles are locked to"
  echo >&2 "       prevent killing vlock with SAK, implies --all."
  echo >&2 "-t <seconds> or --timeout <seconds>: run screen locking plugins"
  echo >&2 "       after the given amount of time."
  echo >&2 "-v or --version: Print the version number of vlock and exit."
  echo >&2 "-h or --help: Print this help message and exit."
}

main() {
  local options long_options short_options plugins

  short_options="acnst:vh"
  long_options="all,current,new,disable-sysrq,timeout:,version,help"

  # test for gnu getopt
  ( getopt -T >/dev/null )

  if [ $? -eq 4 ] ; then
    # gnu getopt
    options=`getopt -o "${short_options}" --long "${long_options}" -n vlock -- "$@"` || getopt_error=1
  else
    # other getopt, e.g. BSD
    options=`getopt "${short_options}" "$@"` || getopt_error=1
  fi

  if [ -n "${getopt_error}" ] ; then
    print_help
    exit 1
  fi

  eval set -- "${options}"

  while : ; do
    case "$1" in
      -a|--all)
        plugins="${plugins} all"
        shift
        ;;
      -c|--current)
        unset plugins
        shift
        ;;
      -n|--new)
        plugins="${plugins} new"
        shift
        ;;
      -s|--disable-sysrq)
        plugins="${plugins} nosysrq"
        shift
        ;;
      -t|--timeout)
        shift
        VLOCK_TIMEOUT="$1"
        shift
        ;;
      -h|--help)
       print_help
       exit
       ;;
      -v|--version)
        echo "vlock version ${VLOCK_VERSION}" >&2
        exit
        ;;
      --)
        # option list end
        shift
        break
        ;;
      *)
        echo >&2 "getopt error: $1"
        exit 1
        ;;
    esac
  done

  # export variables for vlock-main
  export VLOCK_TIMEOUT VLOCK_PROMPT_TIMEOUT
  export VLOCK_MESSAGE VLOCK_ALL_MESSAGE VLOCK_CURRENT_MESSAGE

  exec "${VLOCK_MAIN}" ${plugins} ${VLOCK_PLUGINS} "$@"
}

main "$@"
