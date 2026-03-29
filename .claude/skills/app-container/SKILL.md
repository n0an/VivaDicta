---
name: app-container
description: Print the path to VivaDicta's app container directory in the iOS Simulator
disable-model-invocation: true
---

# app-container

Print the path to VivaDicta's app container directory in the iOS Simulator.

## Instructions

Execute the following command and print ONLY the path result:

```bash
xcrun simctl get_app_container booted com.antonnovoselov.VivaDicta data
```

Do not provide any additional explanation or context - just output the path.
