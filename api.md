 <pre>
-[root](#root)
 |-[@Add_Device(deviceName, address, username, password)](#add_device)
 |-[DeviceNode](#devicenode)
 | |-[@Edit_Device(address, username, password)](#edit_device)
 | |-[@Remove_Device()](#remove_device)
 | |-[params](#params)
 | | |-[Motion](#motion)
 | | | |-[@Add_Window(Name, Top, Left, Bottom, Right, History, ObjectSize, Sensitivity, ImageSource, WindowType)](#add_window)
 | | | |-[MotionWindow](#motionwindow)
 | | | | |-[@Remove_Window()](#remove_window)
 | | |-[ParamValue](#paramvalue) - string
 | |-[mjpgUrl](#mjpgurl) - string
 | |-[events](#events)
 | | |-[instances](#instances)
 | | | |-[sources](#sources)
 | | | | |-[EventSource](#eventsource) - string
 | | | | | |-[channel](#channel) - string
 | | | | | |-[type](#type) - string
 | | | |-[data](#data)
 | | |-[alarms](#alarms)
 | | | |-[rules](#rules)
 | | | | |-[@Add_Rule(name, enabled, windowId, actionId)](#add_rule)
 | | | | |-[ActionRule](#actionrule) - string
 | | | | | |-[@Remove_Rule()](#remove_rule)
 | | | | | |-[enabled](#enabled) - bool
 | | | | | |-[primaryAction](#primaryaction) - string
 | | | | | |-[conditions](#conditions)
 | | | | | | |-[Condition](#condition)
 | | | | | | | |-[message](#message) - string
 | | | | | | | |-[topic](#topic) - string
 | | | |-[actions](#actions)
 | | | | |-[@Add_Action(name, message, continuousAlert, ipAddress, port)](#add_action)
 | | | | |-[ActionConfig](#actionconfig)
 | | | | | |-[@Remove_Config()](#remove_config)
 | | | | | |-[template](#template) - string
 | | | | | |-[parameters](#parameters)
 | | | | | | |-[Parameter](#parameter) - string
 |-[Notices](#notices)
 | |-[config](#config)
 | | |-[bindIp](#bindip) - string
 | | |-[port](#port) - number
 | |-[Notification](#notification) - number
 </pre>

---

### root  

Root node of the DsLink  

Type: Node   

---

### Add_Device  

Add a new Axis Communications device to the link.  

Type: Action   
$is: addDeviceAction   
Parent: [root](#root)  

Description:  
Adds a new Axis Communications device to the link. It will validate that it can communicate with the device based on the credentials provided. If Successful it will add a new device to the root of the link with the name provided.  

Params:  

Name | Type | Description
--- | --- | ---
deviceName | `string` | The name of the device to use in the node tree.
address | `string` | The IP address of the remote device
username | `string` | Username required to authenticate to the device.
password | `string` | Password required to authenticate to the device.

Return type: values   
Columns:  

Name | Type | Description
--- | --- | ---
success | `bool` | Success returns true on success. False on failure. 
message | `string` | Message returns Success! on success, otherwise it provides an error message. 

---

### DeviceNode  

Root node of a device.  

Type: Node   
$is: deviceNode   
Parent: [root](#root)  

Description:  
Device node will contain the configuration information required to access a device such as remote address and credentials. It will have the node name specified when being added.  


---

### Edit_Device  

Edit the device configuration.  

Type: Action   
$is: editDevice   
Parent: [DeviceNode](#devicenode)  

Description:  
Edit the device configuration. It will verify that the new configuration is valid.  

Params:  

Name | Type | Description
--- | --- | ---
address | `string` | The IP address of the remote device
username | `string` | Username required to authenticate to the device.
password | `string` | Password required to authenticate to the device.

Return type: value   
Columns:  

Name | Type | Description
--- | --- | ---
success | `bool` | Success returns true on success. False on failure. 
message | `string` | Message returns Success! on success, otherwise it provides an error message. 

---

### Remove_Device  

Removes the device from the link.  

Type: Action   
$is: removeDevice   
Parent: [DeviceNode](#devicenode)  

Description:  
Removes the device from the node tree, closing connection to remote server. This action should always succeed.  

Return type: value   
Columns:  

Name | Type | Description
--- | --- | ---
success | `bool` | Success returns true on success. False on failure. 
message | `bool` | Message returns "Success!" on success. 

---

### params  

Collection of ParamValues on the device. The link will automatically create a tree based on the configuration tree of the device.  

Type: Node   
Parent: [DeviceNode](#devicenode)  

---

### Motion  

Collection of Motion detection related parameters.  

Type: Node   
Parent: [params](#params)  

---

### Add_Window  

Add a motion detection window to the remote device.  

Type: Action   
$is: addWindow   
Parent: [Motion](#motion)  

Description:  
Add Window will attempt to add a motion detection window to the remote device with specified size, position and sensitivity.  

Params:  

Name | Type | Description
--- | --- | ---
Name | `string` | Name to reference the motion detection window internally.
Top | `number` | Top position of the window (between 0 and 9999)
Left | `number` | Left position of the window (between 0 and 9999)
Bottom | `number` | Bottom position of the window (between 0 and 9999)
Right | `number` | Right position of the window (between 0 and 9999)
History | `number` | History size to maintain.
ObjectSize | `number` | Size the object must be to trigger detection.
Sensitivity | `number` | Sensitivity of the motion detection.
ImageSource | `number` | Id of the image source.
WindowType | `enum[include,exclude]` | If the window detects everything inside the window, or everything outside of the window.

Return type: values   
Columns:  

Name | Type | Description
--- | --- | ---
success | `bool` | Success returns true on success. False on failure. 
message | `string` | Message returns Success! on success, otherwise it provides an error message. 

---

### MotionWindow  

Collection of ParamValues that make up the Motion Window.  

Type: Node   
Parent: [Motion](#motion)  

---

### Remove_Window  

Remove a motion window from the device.  

Type: Action   
$is: removeWindow   
Parent: [MotionWindow](#motionwindow)  

Description:  
Remove a motion window from the device. This will remove the associated Event source used in generating Event Actions and Rules.  

Return type: values   
Columns:  

Name | Type | Description
--- | --- | ---
success | `bool` | Success returns true on success. False on failure. 
message | `string` | Message returns Success! on success, otherwise it provides an error message. 

---

### ParamValue  

Parameter of the Device configuration.  

Type: Node   
Parent: [params](#params)  

Description:  
ParamValue is the value of a parameter within the Axis Camera. Parameters will automatically generate a tree based on the tree provided by the remote device. The path and name of the ParamValue will be that of the path in the device's configuration. The value is the value of that parameter.  

Value Type: `string`  
Writable: `write`  

---

### mjpgUrl  

MJPEG Url of the remote device.  

Type: Node   
Parent: [DeviceNode](#devicenode)  
Value Type: `string`  
Writable: `never`  

---

### events  

Collection of event related nodes for the device.  

Type: Node   
$is: eventsNode   
Parent: [DeviceNode](#devicenode)  

---

### instances  

Collection of event instances.  

Type: Node   
Parent: [events](#events)  

Description:  
event instances are the monitored areas that generate the alarms. Eg: a motion detection window.  


---

### sources  

Motion detection windows as identified by the event system.  

Type: Node   
Parent: [instances](#instances)  

---

### EventSource  

Event Source is the motion window which can trigger an event to occur.  

Type: Node   
$is: eventSourceNode   
Parent: [sources](#sources)  

Description:  
Event source provdies the details about the motion window which can be associated with an rule and action to form the event. The name and path of the event source are the names defined within the Motion window configuration. The value is the Event Source ID.  

Value Type: `string`  
Writable: `never`  

---

### channel  

Channel of the device that the event source uses.  

Type: Node   
Parent: [EventSource](#eventsource)  
Value Type: `string`  
Writable: `never`  

---

### type  

Type of event source. Should be window.  

Type: Node   
Parent: [EventSource](#eventsource)  
Value Type: `string`  
Writable: `never`  

---

### data  

Data sources. This should only be motion detection event.  

Type: Node   
Parent: [instances](#instances)  

---

### alarms  

Collection of alarm configurations. Includes trigger rules, and action to perform when triggered.  

Type: Node   
Parent: [events](#events)  

---

### rules  

Collection of rules that define when an action should be triggered.  

Type: Node   
Parent: [alarms](#alarms)  

---

### Add_Rule  

Adds an Action Rule to the Device.  

Type: Action   
$is: addActionRule   
Parent: [rules](#rules)  

Description:  
Add Action Rule accepts a rule name, and the ID of the Motion Window (Event source) and Primary action (Action Config). This is the test of the Events. When a motion occurs in the specified window, it will trigger the specified Action. On Success, this command will add an ActionRule to the alarms > rules node.  

Params:  

Name | Type | Description
--- | --- | ---
name | `string` | Name internally identify the rule.
enabled | `bool` | If the rule is enabled or disabled.
windowId | `number` | The ID (value) of the motion window (Event source) that should detect the motion for the associated alert.
actionId | `number` | The ID of the Action (Action Config) that should occur when motion is detected in the Window.

Return type: values   
Columns:  

Name | Type | Description
--- | --- | ---
success | `bool` | Success returns true on success. False on failure. 
message | `string` | Message returns Success! on success, otherwise it provides an error message. 

---

### ActionRule  

Action Rule as defined in the remote device.  

Type: Node   
$is: actionRuleNode   
Parent: [rules](#rules)  

Description:  
The configuration of the Action Rule as defined in the remote device. The ActionRule has the path name of the Rule ID, the display name of the internally defined name. The rule is what must be true for an event/alert to trigger.  

Value Type: `string`  
Writable: `never`  

---

### Remove_Rule  

Removes the Action Rule from the device.  

Type: Action   
$is: removeActionRule   
Parent: [ActionRule](#actionrule)  

Description:  
Remove Rule will request that the action rule be removed from the device. This must be removed before any Action Configurations that it depends on are removed.  

Return type: values   
Columns:  

Name | Type | Description
--- | --- | ---
success | `bool` | Success returns true on success. False on failure. 
message | `string` | Message returns Success! on success, otherwise it provides an error message. 

---

### enabled  

If the rule is enabled or not.  

Type: Node   
Parent: [ActionRule](#actionrule)  
Value Type: `bool`  
Writable: `never`  

---

### primaryAction  

The ID of the action to execute when the rule is met.  

Type: Node   
Parent: [ActionRule](#actionrule)  
Value Type: `string`  
Writable: `never`  

---

### conditions  

Collection of conditions which must be met to execute the action.  

Type: Node   
Parent: [ActionRule](#actionrule)  

---

### Condition  

A condition which contains message a topic for rule to be met.  

Type: Node   
Parent: [conditions](#conditions)  

---

### message  

Filter expression which must be true.  

Type: Node   
Parent: [Condition](#condition)  
Value Type: `string`  
Writable: `never`  

---

### topic  

The topic expression indications which topic the message is tested against. (Should be VideoAnalytics/MotionDetection)  

Type: Node   
Parent: [Condition](#condition)  
Value Type: `string`  
Writable: `never`  

---

### actions  

Collection of actions that define what happen when an event is triggered.  

Type: Node   
Parent: [alarms](#alarms)  

---

### Add_Action  

Adds an action to the device.  

Type: Action   
$is: addActionConfig   
Parent: [actions](#actions)  

Description:  
Add Action accepts an Alert name, message and remote TCP Server configuration and adds it to the Axis Camera. The only supported action is to send a message to remote TCP Server, generally the IP of the DSLink. On success, the action will add the ActionConfig to the alarms > action node  

Params:  

Name | Type | Description
--- | --- | ---
name | `string` | The name to give the action/alert to identify it internally.
message | `string` | The string to send to the TCP server when the action is triggered.
continuousAlert | `bool` | If the alert should continuously send notifications while something is detected. False means that only the first notification would be sent when detected.
ipAddress | `string` | IP Address of the remote TCP Server.
port | `number` | Port that the remote TCP server is running on.

Return type: values   
Columns:  

Name | Type | Description
--- | --- | ---
success | `bool` | Success returns true on success. False on failure. 
message | `string` | Message returns Success! on success, otherwise it provides an error message. 

---

### ActionConfig  

Definition of an Action Config, or Event, in the remote device.  

Type: Node   
$is: actionConfigNode   
Parent: [actions](#actions)  

Description:  
ActionConfig is the configuration of the Action, or Event, as defined in the remote device. It will have the path name of the Action Configuration ID, and the display name of the Action as specified internally. The value is also the action configuration ID.  


---

### Remove_Config  

Remove the Action from the remote device.  

Type: Action   
$is: removeActionConfig   
Parent: [ActionConfig](#actionconfig)  
Return type: values   
Columns:  

Name | Type | Description
--- | --- | ---
success | `bool` | Success returns true on success. False on failure. 
message | `string` | Message returns Success! on success, otherwise it provides an error message. 

---

### template  

The template applied to this configuration. Could be fixed or unlimited.  

Type: Node   
Parent: [ActionConfig](#actionconfig)  
Value Type: `string`  
Writable: `never`  

---

### parameters  

Collection of parameters specifying the configuration of the action.  

Type: Node   
Parent: [ActionConfig](#actionconfig)  

---

### Parameter  

Parameter name as path and display name, and value as the value.  

Type: Node   
Parent: [parameters](#parameters)  
Value Type: `string`  
Writable: `never`  

---

### Notices  

Notice Node is a collection of notifications received by the TCP server.  

Type: Node   
$is: noticeNode   
Parent: [root](#root)  

Description:  
Notice Node manages the internal TCP server configuration. The TCP Server receives notifications from the Axis Cameras and updates the corresponding notifications.  


---

### config  

config is a collection of Configuration values for the TCP Server.  

Type: Node   
Parent: [Notices](#notices)  

---

### bindIp  

bindIp is the IP address that the TCP Server is bound to.  

Type: Node   
Parent: [config](#config)  
Value Type: `string`  
Writable: `write`  

---

### port  

port is the Port number that the TCP Server is bound to.  

Type: Node   
Parent: [config](#config)  
Value Type: `number`  
Writable: `write`  

---

### Notification  

Notification received by the TCP Server.  

Type: Node   
$is: notificationNode   
Parent: [Notices](#notices)  

Description:  
The node name and path will be the string that was received by the TCP Server. The Value shows the number of times the notification has been received.  

Value Type: `number`  
Writable: `write`  

---

