#!/bin/bash

export WEBHOOK_B64KEY="agj+xWKk3gqkP+SsCsljkjbDth7bxguqVMRd4K3wm1I="
export PORT=8000

main() {
    if [ "$1" == "all" ]; then
        test_app "express-webhook"
        test_app "fastify-webhook"
        test_app "spring-boot-webhook"
    else
        test_app "$1"
    fi
}

test_app() {
    local appname=$1
    docker build -t "$appname" "$appname"
    docker run -d \
        -p "${PORT}:${PORT}" \
        -e "PORT" \
        -e "WEBHOOK_B64KEY" \
        --name "$appname" \
        "$appname"

    sleep 3

    data1='{"hello":"\u003eworld"}'
    ts1='2022-10-11T10:13:14.000000015Z'
    sig1='267bbfaf0036e3a4f1dec8018679c9123b4142aa972bdc68116ad30b3bc28eae'

    if ! curl_expect "200" \
        -H 'content-type: application/json' \
        -H "webhook-request-timestamp: $ts1" \
        -H "webhook-signature: $sig1" \
        -d "$data1"; then
        echo "Failed test: validate signature"
    fi

    if ! curl_expect "200" \
        -H 'content-type: application/json' \
        -H "webhook-request-timestamp: $ts1" \
        -H "webhook-signature: invalidsignature,$sig1" \
        -d "$data1"; then
        echo "Failed test: multiple signatures, second is valid"
    fi

    if ! curl_expect "200" \
        -H 'content-type: application/json' \
        -H "webhook-request-timestamp: $ts1" \
        -H "webhook-signature: $sig1,invalidsignature" \
        -d "$data1"; then
        echo "Failed test: multiple signatures, first is valid"
    fi

    if ! curl_expect "400" \
        -H 'content-type: application/json' \
        -H "webhook-request-timestamp: $ts1" \
        -d "$data1"; then
        echo "Failed test: signature header is missing"
    fi

    if ! curl_expect "400" \
        -H 'content-type: application/json' \
        -H "webhook-signature: $sig1" \
        -d "$data1"; then
        echo "Failed test: timestamp header is missing"
    fi

    if ! curl_expect "400" \
        -H 'content-type: application/json' \
        -d "$data1"; then
        echo "Failed test: webhook headers are missing"
    fi

    if ! curl_expect "401" \
        -H 'content-type: application/json' \
        -H "webhook-request-timestamp: $ts1" \
        -H "webhook-signature: invalidsignature" \
        -d "$data1"; then
        echo "Failed test: signature is invalid"
    fi

    if ! curl_expect "401" \
        -H 'content-type: application/json' \
        -H "webhook-request-timestamp: notatimestamp" \
        -H "webhook-signature: $sig1" \
        -d "$data1"; then
        echo "Failed test: timestamp is invalid"
    fi

    docker logs "$appname"
    docker rm --force "$appname"
}

curl_expect() {
    local expected_status=$1
    shift
    curl --silent -o /dev/null --write-out "%{http_code}" \
        "http://localhost:$PORT/" "$@" >res
    r=$(cat res)
    rm res
    if [ "$r" == "$expected_status" ]; then
        return 0
    else
        echo "Expected status $expected_status but got $r"
        return 1
    fi
}

main "$@"
