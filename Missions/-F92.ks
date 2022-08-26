CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
SET TERMINAL:HEIGHT TO 65.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:BRIGHTNESS TO 0.8.
SET TERMINAL:CHARHEIGHT TO 10.

// Get Booster Values
Print core:tag.
local wndw is gui(300).
set wndw:x to 400. //window start position
set wndw:y to 120.

//Liftoff

Global boosterCPU is "F91".

Print "Waiting for activation".
//wait for active
Local holdload is false. 
until holdload = true {
	Set holdload to true. //reset to true and rely on previous stage to turn false
	local PROCESSOR_List is list().
	LIST PROCESSORS IN PROCESSOR_List. // get a list of all connected cores
	for Processor in PROCESSOR_List {
		if Processor:TAG = boosterCPU{ //checks to see if previous stage is present
			Set holdload to false.
		}
	}
	wait 0.2.
}
Print "F92 active".
RCS on.
SAS on.
wait 5.
Lock Throttle to 0.2.
Wait 5.
Lock Throttle to 1.
//Stage.//start engine
until ship:periapsis > 240000{
	// if AVAILABLETHRUST < 0.1{
	// 	Stage.
	// }
	Wait 0.01.
}
lock throttle to 0.
rcs off.
wait 5.
