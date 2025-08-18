# VivaDicta iOS Codebase

## Build Commands

Use the following commands to build, run and test the app:

- Build: `xcodebuild -scheme VivaDicta -configuration Debug -workspace ./VivaDicta.xcodeproj/project.xcworkspace -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -allowProvisioningUpdates build | xcbeautify`
- Run tests: `xcodebuild -scheme VivaDicta -configuration Debug -workspace ./VivaDicta.xcodeproj/project.xcworkspace -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -allowProvisioningUpdates test | xcbeautify`
- Run single test: `xcodebuild -scheme VivaDicta -configuration Debug -workspace ./VivaDicta.xcodeproj/project.xcworkspace -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -allowProvisioningUpdates test -only-testing:VivaDictaTests/TestClassName/testMethodName | xcbeautify`