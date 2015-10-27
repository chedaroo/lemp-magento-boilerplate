# Array of formating escape codes
declare -A FORMAT
FORMAT[nf]="\033[0m"
FORMAT[black]="\033[0;30m"
FORMAT[red]="\033[0;31m"
FORMAT[green]="\033[0;32m"
FORMAT[yellow]="\033[0;33m"
FORMAT[blue]="\033[0;34m"
FORMAT[purple]="\033[0;35m"
FORMAT[cyan]="\033[0;36m"
FORMAT[lightgrey]="\033[0;37m"

FORMAT[darkgrey]="\033[1;30m"
FORMAT[lightred]="\033[1;31m"
FORMAT[lightgreen]="\033[1;32m"
FORMAT[lightyellow]="\033[1;33m"
FORMAT[lightblue]="\033[1;34m"
FORMAT[lightpurple]="\033[1;35m"
FORMAT[lightcyan]="\033[1;36m"
FORMAT[white]="\033[1;37m"

FORMAT[bold]="\033[1m"
FORMAT[dim]="\033[2m"
FORMAT[underlined]="\033[4m"

FORMAT[notbold]="\033[21m"
FORMAT[notdim]="\033[22m"
FORMAT[notunderlined]="\033[24m"