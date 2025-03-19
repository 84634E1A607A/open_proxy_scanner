#!/bin/bash

SLEEP_TIME=14400
TOKEN=$TOKEN
ip_list=(
  $LIST
)

sleep 5

mkdir -p /data

# If the clash config file already exists, apply it
if [ -f /data/config.yaml ]; then
    echo "Clash config found. Applying initial config"
    curl -s -X PUT "http://clash:9090/configs" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{\"payload\": $(jq -Rs . < /data/config.yaml)}"
fi

noscan=$((259200 / $SLEEP_TIME + 5))

# Endless loop
while true; do

noscantime=$(($noscan * $SLEEP_TIME))

# If there is already a list, and more than 25 proxies, use them
if [ -f /data/alive_proxies.txt ] && [ $(wc -l < /data/alive_proxies.txt) -gt 25 ] && [ $noscantime -lt 259200 ]; then
    echo "Enough proxies found, skipping scan"
    cp /data/alive_proxies.txt /tmp/open_ports.txt
    noscan=$(($noscan+1))
else
    echo "Scanning for open ports"
    # First, scan for open ports
    nmap -sT -p7890 -Pn -n --open --min-rate 1000 --randomize-hosts -oG - "${ip_list[@]}" \
     | grep '7890/open' \
     | awk '{print $2}' \
     | tee /tmp/open_ports.txt
    noscan=0
fi

echo "Checking for open proxy"
# Then, use socks-open-proxy nse to identify open socks proxies
nmap -sT -p7890 -Pn -n --script socks-open-proxy -oX - -iL /tmp/open_ports.txt \
 | grep -B5 'socks5"' \
 | grep 'address' \
 | sed -r 's/.*addr="([^"]+)".*/\1/' \
 > /data/alive_proxies.txt

alive_count=$(wc -l < /data/alive_proxies.txt)
echo "Found $alive_count alive proxies"

echo "Constructing Clash config"
# Now we construct a clash yaml file and publish it to the server
cat > /data/config.yaml <<EOF
log-level: silent
mode: Rule
dns:
  enable: true
  use-hosts: false
  nameserver:
    - 119.29.29.29
    - 8.8.8.8
    - 223.5.5.5
    - 223.6.6.6
    - tcp://223.5.5.5
    - tcp://223.6.6.6
    - https://dns.google/dns-query
    - https://8.8.8.8/dns-query
    - https://8.8.4.4/dns-query
    - https://dns.alidns.com/dns-query
    - https://223.5.5.5/dns-query
    - https://223.6.6.6/dns-query
  default-nameserver:
    - 119.29.29.29
    - 223.5.5.5
    - 223.6.6.6
    - tcp://119.29.29.29
    - tcp://223.5.5.5
    - tcp://223.6.6.6
proxies:
EOF

while read -r proxy; do
cat >> /data/config.yaml <<EOF
  - name: "$proxy"
    type: socks5
    server: "$proxy"
    port: 7890
EOF
done < /data/alive_proxies.txt

# Construct the default proxy group
cat >> /data/config.yaml <<EOF
proxy-groups:
  - name: "LB"
    type: load-balance
    url: http://cp.cloudflare.com/generate_204
    interval: 240
    proxies:
EOF

while read -r proxy; do
cat >> /data/config.yaml <<EOF
      - "$proxy"
EOF
done < /data/alive_proxies.txt

# The Docker group
cat >> /data/config.yaml <<EOF
  - name: "Docker"
    type: load-balance
    url: https://registry-1.docker.io/v2/
    interval: 240
    proxies:
EOF

while read -r proxy; do
cat >> /data/config.yaml <<EOF
      - "$proxy"
EOF
done < /data/alive_proxies.txt

cat >> /data/config.yaml <<EOF
rules:
  - DOMAIN-KEYWORD,docker,Docker
  - IP-CIDR,192.168.0.0/16,REJECT,no-resolve
  - IP-CIDR,10.0.0.0/8,REJECT,no-resolve
  - IP-CIDR,172.16.0.0/12,REJECT,no-resolve
  - MATCH, LB
EOF

echo "Updating clash config"
# Now use clash web api to update the config
# PUT /configs HTTP/1.1
# Host: 127.0.0.1
# Content-Type: application/json
# 
# {
#     payload: "{payload}"
# }
curl -s -X PUT "http://clash:9090/configs" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{\"payload\": $(jq -Rs . < /data/config.yaml)}"


# Every 5 minutes execute latency test command
CYCLES=$(($SLEEP_TIME / 300))

for i in $(seq 1 $CYCLES); do
  echo "Initiating latency test"
  while read -r proxy; do
    curl -s -X GET "http://clash:9090/proxies/$proxy/delay?timeout=3000&url=http:%2F%2Fwww.gstatic.com%2Fgenerate_204" \
        -H "Authorization: Bearer $TOKEN" \
	> /dev/null

  done < /data/alive_proxies.txt
  sleep 300
done

done

