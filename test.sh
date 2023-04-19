#!/bin/bash

export WEBHOOK_B64KEY="agj+xWKk3gqkP+SsCsljkjbDth7bxguqVMRd4K3wm1I="
export PORT=8000
export MAX_REQUEST_AGE_SECONDS=31536000 # One year

main() {
    if [ "$1" == "" ]; then
        test_app "nodejs-express-webhook"
        test_app "nodejs-fastify-webhook"
        test_app "java-spring-boot-webhook"
        test_app "go-webhook"
        test_app "python-flask-webhook"
        test_app "ruby-sinatra-webhook"
    else
        test_app "$1"
    fi
}

test_app() {
    local appname=$1
    echo "Testing $appname"
    docker build -q -t "$appname" "$appname" >/dev/null
    docker run -d \
        -p "${PORT}:${PORT}" \
        -e "PORT" \
        -e "WEBHOOK_B64KEY" \
        -e "MAX_REQUEST_AGE_SECONDS" \
        --name "$appname" \
        "$appname" >/dev/null

    sleep 3

    data1='{"hello":"\u003eworld"}'
    ts1='2022-10-11T10:13:14.000000015Z'
    sig1='267bbfaf0036e3a4f1dec8018679c9123b4142aa972bdc68116ad30b3bc28eae'
    failure=false

    if ! curl_expect "Validate signature" "200" \
        -H 'content-type: application/json' \
        -H "webhook-request-timestamp: $ts1" \
        -H "webhook-signature: $sig1" \
        -d "$data1"; then
        failure=true
    fi

    if ! curl_expect "Multiple signatures, second is valid" "200" \
        -H 'content-type: application/json' \
        -H "webhook-request-timestamp: $ts1" \
        -H "webhook-signature: invalidsignature,$sig1" \
        -d "$data1"; then
        failure=true
    fi

    if ! curl_expect "Multiple signatures, first is valid" "200" \
        -H 'content-type: application/json' \
        -H "webhook-request-timestamp: $ts1" \
        -H "webhook-signature: $sig1,invalidsignature" \
        -d "$data1"; then
        failure=true
    fi

    if ! curl_expect "Signature header is missing" "400" \
        -H 'content-type: application/json' \
        -H "webhook-request-timestamp: $ts1" \
        -d "$data1"; then
        failure=true
    fi

    if ! curl_expect "Timestamp header is missing" "400" \
        -H 'content-type: application/json' \
        -H "webhook-signature: $sig1" \
        -d "$data1"; then
        failure=true
    fi

    if ! curl_expect "Both headers are missing" "400" \
        -H 'content-type: application/json' \
        -d "$data1"; then
        failure=true
    fi

    if ! curl_expect "Signature is invalid" "401" \
        -H 'content-type: application/json' \
        -H "webhook-request-timestamp: $ts1" \
        -H "webhook-signature: invalidsignature" \
        -d "$data1"; then
        failure=true
    fi

    if ! curl_expect "Timestamp is invalid" "401" \
        -H 'content-type: application/json' \
        -H "webhook-request-timestamp: notatimestamp" \
        -H "webhook-signature: $sig1" \
        -d "$data1"; then
        failure=true
    fi

    echo ""

    if $failure; then
        docker logs "$appname"
    fi
    docker rm --force "$appname" &>/dev/null
}

curl_expect() {
    local test_description=$1
    local expected_status=$2
    shift
    shift
    res=$(curl --silent -o /dev/null --write-out "%{http_code}" \
        "http://localhost:$PORT/" "$@")
    if [ "$res" == "$expected_status" ]; then
        echo_err_green "  Passed: $test_description"
        return 0
    else
        echo_err_red "  Failed: $test_description"
        echo_err_red "    Expected status $expected_status but got $res"
        return 1
    fi
}

echo_err_red() {
    (
        tput setaf 01
        echo "$@"
        tput sgr0
    ) 1>&2
}

echo_err_green() {
    (
        tput setaf 02
        echo "$@"
        tput sgr0
    ) 1>&2
}

main "$@"
