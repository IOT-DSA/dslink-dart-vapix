# dslink-dart-vapix

## Axis Camera VAPIX DSLink

A DSLink for Axis Cameras, interfacing with their VAPIX. This uses REST and
SOAP requests primarily to deal with Motion Detection windows, and the
corresponding events triggered by those windows. This link also enables you
to set any other Axis camera configuration values you would like on existing
properties, but current you cannot add new properties.

If you are interested in developing a DSLink which uses the API of this link,
see the [API](api.md) document.

### Background

An Axis Camera allows you to define multiple "windows" for motion detection.
A window is a full or partial area of the image, which can either detect motion
within that area, or detect motion for everything outside of that area. These
are also referred to as Event Sources.

Once a detection window is active, you can then add Action Rules, which will
indicate that when a motion is detected in a specified motion window, then a
specific Action (event) should take place.

A motion Action Configuration, or Event, is what should occur once an Action
Rule has been met. That is, once the motion Window detects motion, these are
what will happen. In this link, it means setting up a specific TCP message to be
sent to a specific location. You can configure the destination, message and 
if the message is sent only on first detection or if it is continually sent
until the detection is gone.

### Running the DsLink

Once the link is installed and started, you should see a root node of the
DSLink with the default name of Axis. Under *Axis* you will have *Notices* and
under that should be *Server Config*. First step would be to configure the
local TCP Server.

#### Configuring the Local TCP Server

Select the *Server Config* node. Once you do, you should see two values,
*Bind IP* and *Port Number*. Set the *Port Number* to be the port of your choice.
**Note:** Unless you are running DGLux as *root* you will not be able to use
any reserved ports such as Port 80, 23, etc. That's generally a bad idea anyways.

To set the port number, right click on *Port Number* and choose the `@set`
action. Enter your desired port. 

By default the TCP Server will bind to the address "0.0.0.0", which means that
any IP Address on the system will accept connections to that port number. If,
however, you have multiple IP Addresses on your server and want to restrict
the TCP Server to run on only one of those IPs, then you can right click on the
IP Address and select `@set` to specify which IP address the TCP Server will
be bound to.

#### Adding a Camera

First step to configuring a Camera is to first add the Camera to the link. You
can do this by right-clicking on the root node of the link (Default is named
`Axis`), and choose `Add Device`. Fill out the parameters and choose `Invoke`.
You can find a table with the description of parameters below:

| Parameter Name | Description |
| -------------- | ----------- |
| deviceName     | Device name will be the name displayed on the Node tree for this device. |
| address        | Full address, including http(s):// and ipAddress to the camera. |
| username       | Username required to log into the remote camera. |
| password       | Password required to log into the remote camera. |

After pressing invoke, the link will take a moment or two as it tries to connect
to the remote camera. If it is unable to authenticate with the provided 
information, an error will be returned to indicate that it was unsuccessful. If
the connection works as expected, then it will retrieve a list of parameter 
values set in the camera and the event configurations. The invoke command will
return as true, with a message of "Success!" and the specified camera name
will be added to the node tree.

#### Editing a Camera

Should you need to modify the configuration of a Camera, such as if you change
the IP or login credentials used to access it, then you can right-click on the
camera in the the Node tree and choose `Edit Device`. From here you can update
the address, username or password (see above for definitions). Once updated,
press the `Invoke` button to update the changes. The link will attempt to verify
that the new credentials are valid and work, and will provide an error if it
fails to access the camera. Otherwise it will return true with the message of
"Success!"

#### Removing a Camera

If at any point you no longer need to access a Camera from the DSLink, you can
right click on the camera node listed in the node tree, and select 
`Remove Device`. Once you press on `Invoke` it will remove the device from the
node tree. It will then return with true, and message of "Success!"

#### Adding a Motion Window

Once you've added a camera, the next step is to define a motion window for that
camera. The camera will detect movement within the window with the various
parameters and thresholds set. To add a motion window, we need to navigate the
node tree somewhat. First expand the node under the camera that says `params`
and scroll down until you find `Motion`. Right click on `Motion` and choose
`Add Window`.

All of the following parameters are required. See the table below for a
description.

| Parameter Name | Description |
| -------------- | ----------- |
| Name           | Descriptive name for the window to help identify it in other areas. |
| Top            | Number 0 - 9999. The top pixel of where the window box should be. 0 being the very top of the image and 9999 being the very bottom of the image |
| Left           | Number 0 - 9999. The left pixel of where the box window should be. 0 being the very left side of the image and 9999 being the very right side of the image |
| Bottom         | Number 0 - 9999. The bottom point of the window. 0 being the top of the image, 9999 being the very bottom of the image. |
| Right          | Number 0 - 9999. The right hand side of the window. 0 being the left side of the image, 9999 being the very right side of the image. |
| History        | Number 1 - 100. This number represents the duration an object is 'remembered' by the camera. At lower values the object will quickly be considered part of the stationary image. |
| ObjectSize     | Number 1 - 100. This number represents how large an object must be to trigger a motion detection event. The larger the value, the more of the window it must take up before an event is generated. |
| Sensitivity    | Number 1 - 100. How sensitive the camera will be to an object. At lower levels a high-contrast object must be visible (eg: black object on white background.) |
| ImageSource    | Number. Image source is the ID of the image source from the `params` > `ImageSource` that the window should be applied to. Defaults to 0. |
| WindowType     | Include/Exclude. Include window indicates that objects in this window are included in the motion detection. Exclude indicates that objects in the window are excluded from motion detection. |

If the `Add Window` action fails, it will return an error message. If it is
successful, it will return true with the message "Success!". It will also add
the motion window as a child with the name of M&lt;number&gt; where number is
the number determined by the camera. Eg: M0

A successful add window will also generate an event instance source. You can see
this source from the tree under _camera name_ > `events` > `instances` >
`sources`. You should see values with the descriptive name specified, followed
by the window ID as a value. This Window ID is used later to setup an
Action Rule.

#### Edit Motion Window

While you cannot edit all parameters of a motion window in one command, you can
edit the individual values. Open the Node tree to the particular Motion window
under the `params` tree. You can right-click any of the values, and used the
`@set` command to modify the value, then press `Invoke`. When the update
succeeds you will see the new value reflected, if the values fails to update
for some reason, then it will revert back to its previous value.

#### Remove Motion Window

To remove a motion window which has already been defined, you can right-click
on the Motion window ID under the `params` > `Motion` tree (eg: M0) and choose
the `Remove Window` action and press `Invoke`. This will send a request to the
camera to remove the window.

If the `Remove Window` action fails, it will provide an error message. If it
succeeds then it will return true an the message of "Success!", it will also
remove that Motion window from the node tree.

#### Add Alarm Actions

Once we've added a motion detection window to the camera, the next step is to
define an Alarm Action. The Alarm action is what will happen when an event is
triggered.

On the node tree, navigate to _camera name_ > `events` > `alarms` > `actions`. 
Right-click on `actions` and choose `Add Action`. Provide all of the required 
parameters and press `Invoke` to add the action. The parameter descriptions can 
be found in the table below. At this time, the only actions supported by this 
DSLink are to send a message to a TCP server at the specified IP and port.

| Parameter Name  | Description |
| --------------- | ----------- |
| Name            | Descriptive name to call the alert. Eg: Notify DSLink |
| Message         | The text string to send to the TCP Server when the alarm is activated (by a motion detection event) |
| continuousAlert | true/false. Setting this to true will mean the TCP Server will be sent the message every second until the camera no longer detects motion. Setting to false means the TCP Server will only receive a message once at the beginning of the motion detection event. |
| ipAddress       | IP Address of the TCP Server. This is usually set to the IP address of this DSLink |
| port            | Port number that the TCP server is running on. This should match the port number set when configuring the TCP Server (see earlier section). |

If the `Add Action` command fails, it will return an error message. If it
succeeds, then it will return true with a message of "Success!" It will also
add the specified action as a child value of the `actions` node. Next to the
descriptive name you provided will be an Action ID which is required (along
with the event source ID), to add an Action Rule.

**Note:** The API on the cameras does not current support editing an Alarm 
action. You must instead remove the action and add a new one.

#### Remove Alarm Action

To remove an existing Alarm Action, right click on the desired Action, and
choose `Remove Action`, then `Invoke`. If the remove action fails, it will
return an error message. If it succeeds, it will return true with the message
"Success!" and it will remove the Action from the node tree.

**Note:** If an alarm rule references this this Action ID, it must be removed
before the Action can be removed.

#### Add Alarm Rule

An Alarm rule ties the Motion Window (also know as event source) to a desired
Alarm Action. That is, the Alarm Rule will cause the specified Action ID to
be triggered when a motion detection event occurs in the specified Window ID.
To add an alarm rule, navigate in the node tree to *camera name* > `events` >
`alarms` > `rules`. Right-click on `rules` and choose `Add Rule`. Provide the
required parameters and click on `Invoke`. The parameter descriptions can be
found in the table below.

| Parameter Name  | Description |
| --------------- | ----------- |
| name            | Descriptive name for the Alarm Rule. |
| windowId        | The ID of the motion detection window to monitor for motion detection events. |
| actionId        | The ID of the Alarm Action to trigger when the motion is detected in the specified window. |

If the `Add Rule` action fails, it will return an error message. If it succeeds,
then it will return true and a message of "Success!" It will also add the
specified rule as a child value of the `rules` node.

**Note:** The API on the cameras does not support editing a Alarm Rule. You must
remove the rule and add a new one instead.

#### Remove Alarm Rule

To remove an existing Alarm Rule, right-click on the desired Rule and choose
`Remove Rule`, then `Invoke`. If the remove rule fails, it will return an
error message. If if succeeds, then it will return true with the message of
"Success!" and it will remove the Rule from the node tree.

**Note:** Any actionId that this rule depends on cannot be removed until the
Rules which reference it are removed first.

### Receiving Notifications

When an Alarm Action is triggered, it will cause the remote camera to send
a notification to the TCP Server running with the DSLink. This notification
will appear in the `Axis` > `Notices` node, as a value. The value name will
be the text which was provided with the Alarm Action, and the value itself will
be the number of times that notification has been received. The notifications 
will not appear under this node until after the first notification has been
received.

If the Alarm Action is of a continuous nature, then the notification value
should continue increasing once each second. If it is not a continuous notice,
then it will increase once each time a new motion is detected.

If you wish to reset the value of a notification, you can right-click on the
notification and choose `@set`. You can then set the value to whatever number
you would like (eg: 0).

### Configuring Notification Server

By default, the notification server runs on port `4444` and binds to `0.0.0.0`
which is to say it binds to all interfaces (addresses) associated with the
current machine. If you wish to force or limit binding to a specific IP address
or to change the port, you can do so under the `Axis` > `Notices` > `Server Config`
node. Under here you will find a value for `Bind IP`, `Port Number` and finally a
`status` value which indicates if the notification server is running or stopped.

You can use the `@set` action on either of the above values to change them. If
changing the server status to `running` and the value immediately reverts to 
`stopped` again, then the server is most likely encountering an error when trying
to start. Please check the log files for the link to look for any errors.
