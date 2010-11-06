#!/bin/bash

set -eu

#function debug_trap {
#    #(set -o posix ; set) 1>&2
#    echo "$(date +'%s%N') ${FUNCNAME[1]} ${BASH_LINENO[0]}" 1>&2
#}
#set -T
#shopt -s extdebug
#trap debug_trap DEBUG
#function return_trap {
#    #(set -o posix ; set) 1>&2
#    echo "$(date +'%s%N') ${FUNCNAME[1]} ${BASH_LINENO[1]} RETURN" 1>&2
#}
#trap return_trap RETURN

function traceback {
    local -i start=1
    if [[ -n "${1:-}" ]]; then
        # Always hide our function call...
        start=$(( $1 + ${start} ))
    fi
    local i
    local j
    echo "Traceback (last called is first):"
    for i in $(seq "${start}" $(( ${#BASH_SOURCE[@]} - 1 ))); do
        j=$(( $i - 1 ))
        local function="${FUNCNAME[$i]}"
        local file="${BASH_SOURCE[$i]}"
        local line="${BASH_LINENO[$j]}"
        echo "     ${function}() in ${file}:${line}"
    done
}

function push_a {
    local name="${1}"
    local value="${2}"
    local c="\"\${#${name}[@]}\""
    local v="\"\${${name}[@]}\""
    eval "
if (( ${c} == 0 )); then
  ${name}=( \"\${value}\" )
else
  ${name}=( ${v} \"\${value}\" )
fi
"
}

function print_field {
    local -a myfield=()
    if [[ "${#@}" = 0 ]]; then
	myfield=( "${field[@]}" )
    else
	myfield=( "$@" )
    fi

    for y in $(seq 0 $(( ${rows} - 1 ))); do
	for x in $(seq 0 $(( ${columns} - 1 ))); do
	    field_get $x $y "${myfield[@]}"
	    echo -n " "
	done
	echo
    done
}

function field_get {
    local -i x="${1}" ; shift
    local -i y="${1}" ; shift

    local -a myfield=()
    if [[ "${#@}" = 0 ]]; then
	myfield=( "${field[@]}" )
    else
	myfield=( "$@" )
    fi

    if (( $x < 0 )); then
	echo "NARFa $x $y" 1>&2
	traceback 1 1>&2
    fi

    echo -n "${myfield[$(( ${y} * ${rows} + ${x} ))]}"
}

function field_set {
    local -i x="${1}" ; shift
    local -i y="${1}" ; shift
    local value="${1}" ; shift

    local -a myfield=()
    if [[ "${#@}" = 0 ]]; then
	myfield=( "${field[@]}" )
    else
	myfield=( "$@" )
    fi

    # Assertion
    case "${value}" in
	.) ;;
	o) ;;
	*) echo "WRONG"; exit 1;;
    esac

    local -i idx=$(( ${y} * ${rows} + ${x} ))
    myfield[$idx]="${value}"

    echo "${myfield[@]}"
}

function neighbor_count {
    local -i x="${1}"
    local -i y="${2}"
    local -i count=0
    #local -i i=$(( ${y} * ${rows} + ${x} ))
    #echo field[$()$i] 1>&2

    for i in "-1" 0 "+1"; do
	for j in "-1" 0 "+1"; do
	    if [[ $i = 0 && $j = 0 ]]; then
		continue
	    fi
	    local -i new_x=$(( ($x + ${columns} + ${i}) % ${columns} ))
	    local -i new_y=$(( ($y + ${rows}    + ${j}) % ${rows} ))
            if [[ $(field_get ${new_x} ${new_y}) = o ]]; then
		count=$(( $count + 1 ))
	    fi
	done
    done

    echo "${count}"
}

declare -i rows=6
declare -i columns=8
declare -a field=()
declare -a new_field=()

declare -a seq=( 0 $(seq $(( ${rows} * ${columns} - 1 ))) )

for i in "${seq[@]}"; do
    push_a field '.'
done

case "${1}" in
    blinker)
	field=( $(field_set 0 1 o) )
	field=( $(field_set 1 1 o) )
	field=( $(field_set 2 1 o) )
	;;
    glider)
	field=( $(field_set 0 1 o) )
	field=( $(field_set 1 2 o) )
	field=( $(field_set 2 0 o) )
	field=( $(field_set 2 1 o) )
	field=( $(field_set 2 2 o) )
	;;
    spaceship)
	#   0 1 2 3 4
	# 0 o . . o .
	# 1 . . . . o
	# 2 o . . . o
	# 3 . o o o o
	field=( $(field_set 0 0 o) )
	field=( $(field_set 3 0 o) )

	field=( $(field_set 4 1 o) )

	field=( $(field_set 0 2 o) )
	print_field; exit
	field=( $(field_set 4 2 o) )

	field=( $(field_set 1 3 o) )
	field=( $(field_set 2 3 o) )
	field=( $(field_set 3 3 o) )
	field=( $(field_set 4 3 o) )
	;;
    *)
	echo "specify a shape"
	exit 13
esac
shift


declare -i iterations="${1:-100}"

echo
echo "Initial:"
print_field

while (( $iterations > 0 )); do
    echo
    echo "Iterations $iterations:"

    declare -i x=-1
    declare -i y=-1

    # Tick
    # Populate new_field with the next iteration.
    for y in $(seq 0 $(( ${rows} - 1 ))); do
	for x in $(seq 0 $(( ${columns} - 1 ))); do
	    declare -i i=$(( ${y} * ${rows} + ${x} ))
	    declare -i count=$(neighbor_count ${x} ${y})
	    declare old="${field[${i}]}"
	    if [[ "${old}" = 'o' ]]; then
		if (( $count < 2 || $count > 3 )); then # under-population
		    push_a new_field .
		else
		    push_a new_field o
		fi
	    else
		if (( $count == 3 )); then
		    push_a new_field o
		else
		    push_a new_field .
		fi
	    fi
	done
    done

    # Tock
    # Copy new_field to field, and empty new_field.
    field=( "${new_field[@]}" )
    new_field=()

    print_field
    iterations=$(( $iterations - 1 ))
done

# EOF