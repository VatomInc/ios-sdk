# BlockV

[![Version](https://img.shields.io/cocoapods/v/BlockV.svg?style=flat)](http://cocoapods.org/pods/BlockV)
[![License](https://img.shields.io/cocoapods/l/BlockV.svg?style=flat)](http://cocoapods.org/pods/BlockV)
[![Platform](https://img.shields.io/cocoapods/p/BlockV.svg?style=flat)](http://cocoapods.org/pods/BlockV)

## Requirements

- iOS 10.0+
- Xcode 9.2+
- Swift 4+

## Installation

BlockV is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'BlockvSDK'
```

## Configuration

Within the `AppDelegate` be sure to set your App ID and the desired server environment.

```Swift
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Set appID
        Blockv.configure(appID: "your-app-id")
        // Set platform environment
        Blockv.setEnvironment(.development)
        // Check logged in state
        if Blockv.isLoggedIn {
            // show interesting ui
        } else {
            // show authentication ui
        }
        return true
    }
}
```

## Example

The example app lets you try out the BLOCKv SDK. It's a great place to start if you're getting up to speed on the platform. It demonstrates the following features:

- Authentication (registration & login)
- Profile management
- Fetching the user's inventory of vAtoms
- Fetching individual vAtoms by thier ID(s)
- Dispalying vAtoms in a collection view
- Searching for vAtom on the BLOCKv Platform

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Author

[BlockV](developer.blockv.io)

## License

BlockV is available under the <????> license. See the LICENSE file for more info.
