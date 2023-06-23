#!/usr/bin/env bash

VERSION="1.0.0"
WORKDIR="/working"
NAME="kola run"
OUTPUT=""
INPUT=""

function usage() {
    echo "Usage $(basename "$0") - v$VERSION: Converts kola results to junit xml"
    echo "Example usage: [-h|--help] [-w|--workdir WORKDIR] [-o|--output OUTPUT] [-i|--input INPUT] [-n|--name NAME]"
    echo "  -h|--help             displays this help message"
    echo "  -n|--name    NAME     name of the test suite"
    echo "  -w|--workdir WORKDIR  kola work directory, defaults to /working"
    echo "  -o|--output  OUTPUT   outputs the converted results to OUTPUT, defaults to stdout"
    echo "  -i|--input   INPUT    the input file to convert, defaults to stdin"
}

function parse_args() {
    local param
    while [ -n "$*" ]; do
        param=$1
        case "$param" in
            -h|--help) usage; exit;;
            -o|--output) shift; OUTPUT=$1;;
            -w|--workdir) shift; WORKDIR=$1;;
            -i|--input) shift; INPUT=$1;;
            -n|--name) shift; NAME=$1;;
            *) usage; return 1;;
        esac
        shift
    done
    [ -d "$WORKDIR" ] || {
        >&2 echo "The working directory $WORKDIR does not exist"
        return 1
    }
    if [ -n "$INPUT" ] && [ ! -e "$INPUT" ]; then
        >&2 echo "The input file $INPUT does not exist"
        return 1
    fi
    return 0
}

function output_properties() {
    echo "<properties>"
    if [ -f "$WORKDIR"/properties.json ]; then
        local cmdline="NA"; cmdline=$(jq -r '.cmdline | join(" ")' < "$WORKDIR/properties.json")
        echo "<property name=\"cmdline\" value=\"$cmdline\"/>"
    fi
    echo "</properties>"
}

function nano_to_seconds() {
    local nanos=$1
    echo "scale=2; $nanos / 1000 / 1000 / 1000" | bc
}

function main() {
    local tests=0
    local failures=0
    local testcases=()
    local testname
    local tmp_output
    local old_ifs=$IFS
    local total_time=0
    IFS=$'\n'
    for test_result in $(jq -c '.tests[]' < "${INPUT:-/dev/stdin}"); do
        # Skip tests
        [ "$(echo "$test_result" | jq '.subtests')" != "null" ] && continue
        local elements=()
        testname=$(echo "$test_result" | jq -r '.name')
        resultstatus=$(echo "$test_result" | jq -r '.result')
        output=$(echo "$test_result" | jq -r '.output')
        duration=$(echo "$test_result" | jq -r '.duration')
        total_time=$((total_time + duration))
        if [ "$resultstatus" = "PASS" ]; then
            [ -n "$output" ] && elements+=("<system-out>" "<![CDATA[" "$output" "]]>" "</system-out>")
        else
            failures=$(( failures + 1 ))
            [ -n "$output" ] && elements+=("<system-err>" "<![CDATA[" "$output" "]]>" "</system-err>")
        fi
        testcases+=("<testcase name=\"$testname\" time=\"$(nano_to_seconds "$duration")\">${elements[*]}</testcase>")
        tests=$(( tests + 1))
    done

    tmp_output=$(mktemp)
    cat << EOF > "$tmp_output"
<testsuites tests="$tests" failures="$failures">
    <testsuite name="$NAME" time="$(nano_to_seconds "$total_time")" tests="$tests" failures="$failures">
        $(output_properties)
        ${testcases[*]}
    </testsuite>
</testsuites>
EOF
    IFS=$old_ifs

    xmllint --schema /junit5/schema.xsd "$tmp_output" --noout >/dev/null || return 1
    cat "$tmp_output" > "${OUTPUT:-/dev/stdout}"
}

parse_args "$@" || exit 1
main
