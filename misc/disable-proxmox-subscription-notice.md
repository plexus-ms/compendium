---
title: Disable Proxmox Subscription Notice
description: One-liner to disable the Proxmox "No valid subscription" dialog.
---

Run this command on the Proxmox host:

```bash
sed -Ezi.bak "s/(function\(orig_cmd\) \{)/\1\n\torig_cmd\(\);\n\treturn;/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js && systemctl restart pveproxy.service
```
