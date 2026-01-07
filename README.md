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

