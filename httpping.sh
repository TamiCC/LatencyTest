#!/bin/bash

HOST="$1"
PORT="$2"

if [ -z "$HOST" ] || [ -z "$PORT" ]; then
    echo "Usage: bash ping.sh <IP> <PORT>"
    echo "Example: bash ping.sh 45.192.96.226 8080"
    exit 1
fi

# Deliberately request a non-existent file to minimize traffic.
URL="http://${HOST}:${PORT}/ping-test-404"

count=0
ok=0
fail=0
sum_connect=0
sum_app=0
min_connect=999999
max_connect=0
min_app=999999
max_app=0

summary() {
    echo
    echo "---------------- Summary ----------------"
    echo "Target:  ${HOST}:${PORT}"
    echo "Sent:    $count"
    echo "Success: $ok"
    echo "Failed:  $fail"

    if [ "$count" -gt 0 ]; then
        loss=$(awk "BEGIN {printf \"%.1f\", ($fail/$count)*100}")
        echo "Loss:    ${loss}%"
    fi

    if [ "$ok" -gt 0 ]; then
        avg_connect=$(awk "BEGIN {printf \"%.1f\", $sum_connect/$ok}")
        avg_app=$(awk "BEGIN {printf \"%.1f\", $sum_app/$ok}")

        echo
        echo "TCP Connect:"
        echo "  Avg: $avg_connect ms"
        echo "  Min: $min_connect ms"
        echo "  Max: $max_connect ms"

        echo
        echo "App RTT:"
        echo "  Avg: $avg_app ms"
        echo "  Min: $min_app ms"
        echo "  Max: $max_app ms"
    fi
}

trap 'summary; exit 0' INT

echo "HTTP RTT test: ${HOST}:${PORT}"
echo "Press Ctrl+C to stop."
echo

while true; do
    count=$((count + 1))

    result=$(curl --connect-timeout 3 --max-time 5 \
        -o /dev/null -s \
        -w "%{time_connect} %{time_starttransfer}" \
        "$URL")

    status=$?

    if [ "$status" -ne 0 ]; then
        fail=$((fail + 1))
        printf "%4d  timeout/fail\n" "$count"
    else
        connect=$(echo "$result" | awk '{printf "%.1f", $1*1000}')
        app=$(echo "$result" | awk '{printf "%.1f", ($2-$1)*1000}')

        if [ "$connect" = "0.0" ] || [ "$app" = "0.0" ]; then
            fail=$((fail + 1))
            printf "%4d  fail\n" "$count"
        else
            ok=$((ok + 1))

            sum_connect=$(awk "BEGIN {print $sum_connect+$connect}")
            sum_app=$(awk "BEGIN {print $sum_app+$app}")

            min_connect=$(awk "BEGIN {print ($connect<$min_connect)?$connect:$min_connect}")
            max_connect=$(awk "BEGIN {print ($connect>$max_connect)?$connect:$max_connect}")
            min_app=$(awk "BEGIN {print ($app<$min_app)?$app:$min_app}")
            max_app=$(awk "BEGIN {print ($app>$max_app)?$app:$max_app}")

            printf "%4d  Connect: %6.1f ms   App RTT: %6.1f ms\n" \
                "$count" "$connect" "$app"
        fi
    fi

    sleep 1
done
