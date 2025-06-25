#!/bin/bash
#
# updates cloudflare dns records
#
# begin configuration
CFTOKEN="foobazbar"
RECORD="record"
DOMAIN="domain.tld"
INTERFACE="eth0"
TTL="300"
RECORDTYPE="AAAA"

API="https://api.cloudflare.com/client/v4"
UPSTREAMDNS="hazel.ns.cloudflare.com"

CFDOMAINID=$(curl -s $API"/zones?name="$DOMAIN"" -X GET -H "Authorization: Bearer "$CFTOKEN"" | jq -r '.result[] | .id')
CFRECORDID=$(curl -s $API"/zones/"$CFDOMAINID"/dns_records?name="$RECORD.$DOMAIN"&type="$RECORDTYPE"" -X GET -H "Authorization: Bearer "$CFTOKEN"" | jq -r '.result[] | .id')

DNSIP=$(dig +short @$UPSTREAMDNS $RECORD.$DOMAIN $RECORDTYPE | tr -d '\n')
IP6=$(ip -j -6 address show | jq -j -r '.[] | select(.ifname == "'$INTERFACE'") | .addr_info[] | select((.scope == "global") and (.prefixlen == 64) and (.local|test("fd00.")|not)) | .local')

if [[ -z "$IP6" || -z "$DNSIP" ]]; then
    echo "Something went wrong. Cannot get your IPv6 address from public dns or cannot set your interface IPv6 address"
    exit 1
fi

if [[ ! -z "$IP6" && ("$DNSIP" != "$IP6") ]]; then
    DATA='{"name":"'$RECORD.$DOMAIN'","ttl":'$TTL',"type":"'$RECORDTYPE'","content":"'$IP6'","proxied":false}'
    curl -s -X PATCH -d ""$DATA"" -H "Authorization: Bearer "$CFTOKEN"" $API/zones/$CFDOMAINID/dns_records/$CFRECORDID
fi
