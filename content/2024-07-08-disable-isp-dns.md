+++
title = "systemd-resolved takes 10 seconds to resolve with DNS over TLS (DoT)"
[taxonomies]
categories = ["misc"]
+++

If you're using `DnsOverTLS=yes` in your `resolved.conf`` and some applications need 10 seconds to resolve something - try disabling your router's DNS servers:

```
[DHCP]
UseDNS=false

[IPv6AcceptRA]
UseDNS=false
DHCPv6Client=false
```

`systemd-resolved` always tries to contact the IPv6 DNS server of my ISP's router on port 853 - but it doesn't respond at all (not even a `RST`), which is why it retransmitted the SYN several times until it gave up after 10 seconds and switched to one of the configured global DNS resolvers.

