#-------------------------------------------------------------------------------
# Version
#-------------------------------------------------------------------------------
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  echo "Bash version 4.0 or higher is required"
  exit 1
fi
