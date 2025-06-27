########### Variables ###########

:local Debug "false"
:local InetInterface "inet"

:local UpdateV4 "true"
:local UpdateV6 "true"

:local Domain "domain.tld"
:local Record "record"
:local TTL "300"
:local ResolverAddress "hazel.ns.cloudflare.com"
:local V4RecordType "A"
:local V6RecordType "AAAA"

:local CFToken "foobazbar"
:local APIUrl "https://api.cloudflare.com/client/v4/"

########### Script Variables ###########

:global V4ResolvedIP ""
:global V6ResolvedIP ""
:global V4InetIP ""
:global V6InetIP ""
:local FQDN ""
:global V4RequestUrl ""
:global V6RequestUrl ""
:global V4data ""
:global V6data ""
:global CFDomainIDRequestUrl ""
:global CFV4RecordIDRequestUrl ""
:global CFV6RecordIDRequestUrl ""
:global CFDomainID ""
:global CFV4RecordID ""
:global CFV6RecordID ""
:global JsonData ""

########### Set FQDN ###########

:set FQDN ($Record . ".$Domain");
:if ($Debug = "true") do={
:put $FQDN
}

########### Resolve addresses ###########

:if ($UpdateV4 = "true") do={
:local V4CIDR [/ip address get [/ip address find interface=$InetInterface ] address];
:set V4InetIP [:pick [:tostr $V4CIDR] 0 [:find [:tostr $V4CIDR] "/"]];
:if ($Debug = "true") do={
:put $V4InetIP
}

:set V4ResolvedIP [:resolve server=$ResolverAddress type=ipv4 $FQDN];
:if ($Debug = "true") do={
:put $V4ResolvedIP
}
}

:if ($UpdateV6 = "true") do={
:local V6CIDR [/ipv6 address get [:pick [find dynamic global interface=$InetInterface] 0 ] address];
:set V6InetIP [:pick [:tostr $V6CIDR] 0 [:find [:tostr $V6CIDR] "/"]];
:if ($Debug = "true") do={
:put $V6InetIP
}

:set V6ResolvedIP [:resolve server=$ResolverAddress type=ipv6 $FQDN];
:if ($Debug = "true") do={
:put $V6ResolvedIP
}
}

########### Set headers ###########

:local headers "Authorization: Bearer $CFToken, Content-Type: application/json"
:if ($Debug = "true") do={
:put $headers
}

########### Get Cloudflare domainid and recordids ###########

:if (($UpdateV4 = "true") || ($UpdateV6 = "true")) do={
    :if (($V4InetIP != $V4ResolvedIP) || ($V6InetIP != $V6ResolvedIP)) do={
        :set CFDomainIDRequestUrl ($APIUrl . "zones?name=$Domain");
        :set $JsonData [/tool fetch mode=https check-certificate=yes url="$CFDomainIDRequestUrl" http-method=get http-header-field="$headers" as-value output=user];
        :set CFDomainID ([:deserialize from=json options=json.no-string-conversion value=($JsonData->"data")]->"result"->0->"id")
        :if ($UpdateV4 = "true") do={
            :set CFV4RecordIDRequestUrl ($APIUrl . "zones/$CFDomainID/dns_records?name=$Record.$Domain&type=$V4RecordType")
            :set $JsonData [/tool fetch mode=https check-certificate=yes url="$CFV4RecordIDRequestUrl" http-method=get http-header-field="$headers" as-value output=user];
            :set CFV4RecordID ([:deserialize from=json options=json.no-string-conversion value=($JsonData->"data")]->"result"->0->"id")
        }
        :if ($UpdateV6 = "true") do={
            :set CFV6RecordIDRequestUrl ($APIUrl . "zones/$CFDomainID/dns_records?name=$Record.$Domain&type=$V6RecordType")
            :set $JsonData [/tool fetch mode=https check-certificate=yes url="$CFV6RecordIDRequestUrl" http-method=get http-header-field="$headers" as-value output=user];
            :set CFV6RecordID ([:deserialize from=json options=json.no-string-conversion value=($JsonData->"data")]->"result"->0->"id")
        }
    }
}

########### Build url ###########

:if ($UpdateV4 = "true") do={
:set V4RequestUrl ($APIUrl . "zones/$CFDomainID/dns_records/$CFV4RecordID");
:if ($Debug = "true") do={
:put $V4RequestUrl
}
}

:if ($UpdateV6 = "true") do={
:set V6RequestUrl ($APIUrl . "zones/$CFDomainID/dns_records/$CFV6RecordID");
:if ($Debug = "true") do={
:put $V6RequestUrl
}
}

########### Payload ###########

:if ($UpdateV4 = "true") do={
:set V4data "{\"name\":\"$Record.$Domain\",\"ttl\":$TTL,\"type\":\"$V4RecordType\",\"content\":\"$V4InetIP\",\"proxied\":false}"
:if ($Debug = "true") do={
:put $V4data
}
}

:if ($UpdateV6 = "true") do={
:set V6data "{\"name\":\"$Record.$Domain\",\"ttl\":$TTL,\"type\":\"$V6RecordType\",\"content\":\"$V6InetIP\",\"proxied\":false}"
:if ($Debug = "true") do={
:put $V6data
}
}

########### Execute request ###########

:if ($UpdateV4 = "true") do={
:if ($V4InetIP != $V4ResolvedIP) do={
/tool fetch mode=https check-certificate=yes url="$V4RequestUrl" http-method=patch http-header-field="$headers" http-data="$V4data" output=none
}
}
:if ($UpdateV6 = "true") do={
:if ($V6InetIP != $V6ResolvedIP) do={
/tool fetch mode=https check-certificate=yes url="$V6RequestUrl" http-method=patch http-header-field="$headers" http-data="$V6data" output=none
}
}
/ip dns cache flush
