
Script for managing two servers under DRBD. Monitors the state of virtual machines and the state of the network, in relation to this it controls the status of DRBD and also the state of virtual machines.
To monitor the work of the main script and also to make it easier to stop and start, an additional script, script_control, was written. You need to add it to startup
