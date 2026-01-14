FamilyControls asks the user for permission and what to block. ManagedSettings sets up the actual block. DeviceActivity controls when that block is turned on and off.

##FamilyControls

Authorization: The mechanism to request permission from the user to manage their app and web activity.

- UI components (FamilyActivityPicker) to pick the apps

##ManagedSettings

This framework is the enforcer. ManagedSettings lets you define the actual rules. 

- Shield Apps & Websites: Prevent selected apps from being launched or shield specific web domains in Safari.

- Set App Time Limits: (Though not shown in our primary example code, ManagedSettings also enables setting time limits).


##DeviceActivityMonitor

The object that monitors scheduled device activity.

- This Target helps to know when a app is reaching a time limit. This Target runs in the background constantly checking if it meets the requirement set. 

- This framework determines when the rules defined in *ManagedSettings* should be active.

- Note: Shielding an app dims the app’s icon on the homescreen and applies an hourglass symbol. When the app launches, the system covers it with a view that your app can configure.


----

UserDefault is the way to store data locally on the device, more like localStorage in browser. There are 2 types.

1. Standard
2. Shared

It is a key value pair storage. The standard is normal way of storing but the shared is used when we have extensions and these needs to be shared across multiple extensions. We can do that by creating an AppGroup. 

AppGroup must be created by going to the apple developer account and go to identifiers and create a group. Once created, create capabilities in main app and select AppGroups and we can see this AppGroup created. 

```
    static var blockedAppsSelection: FamilyActivitySelection {
        get {
            guard let data = defaultsGroup?.data(forKey: Keys.blockedApps.key) else {
                return FamilyActivitySelection()
            }
            
            do {
                return try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            } catch {
                print("Failed to decode FamilyActivitySelection: \(error)")
                return FamilyActivitySelection()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaultsGroup?.set(data, forKey: Keys.blockedApps.key)
            } catch {
                print("Failed to encode FamilyActivitySelection: \(error)")
            }
        }
    }
```

In this, the data that is stored from the FamilyPicker is of type Codable, so we should encode it and then store it as data. Same way to get the data, we decode and get the data as JSON. 



The file @SharedData.swift has target membership for both main app and the extension. 



ManagedSettingsStore

This is implemented in ManagedSettings.swift. The ManagedSettingsStore defines what the restrictions are and applying and removing it. But it won't do the apply and removing though. 

let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("buytimeAppRestriction"))

We can apply shield by using the object store.shield.[app or web or category]

Once the ManagedSettingsStore is defined, we should monitor all these apps using the DeviceActivityCenter

-----

DeviceActivityCenter

let center = DeviceActivityCenter()

center.startMonitoring or center.stopMonitoring

We should start the monitoring whenever the user changes the blocked app selection and also start when app or system restarts. So it is also defined in BuyTimeApp.swift

-----

ShieldConfigurationExtension

This is the place where we have the custom shield configuration with different UI and have buttons and define function to apply and remove shield. 

ShieldConfigurationExtension only does the UI changes and nothing more. If you want to have actions implemented then we need to create a target for ShieldActionExtension.

----

ShieldActionExtension

class ShieldActionExtension: ShieldActionDelegate 

---

Big Changes INCOMING!!
