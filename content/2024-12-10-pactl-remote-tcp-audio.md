+++
title = "Streaming audio over the network with pactl"
[taxonomies]
categories = ["misc"]
+++

```bash
# On the receiving end:
pactl load-module module-native-protocol-tcp-new port=4656 listen=<local server IP>

# On the sending end:
pactl load-module module-native-protocol-tcp-new sink=<local server IP>:4656

# To finish:
pactl unload-module module-native-protocol-tcp-new
```