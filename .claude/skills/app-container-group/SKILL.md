---
name: app-container-group
description: Print the path to VivaDicta's App Group container directory in the iOS Simulator
disable-model-invocation: true
---

# app-container-group

Print the path to VivaDicta's App Group container directory in the iOS Simulator.

## Instructions

Execute the following commands to find and print ONLY the App Group container path:

```bash
xcrun simctl listapps booted | grep -A 10 "com.antonnovoselov.VivaDicta" | grep "group.com.antonnovoselov.VivaDicta" | sed 's/.*"file:\/\/\(.*\)\/";/\1/'
```

Do not provide any additional explanation or context - just output the path.
