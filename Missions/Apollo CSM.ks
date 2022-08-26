 // Get Booster Values
CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
SET TERMINAL:HEIGHT TO 65.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:BRIGHTNESS TO 0.8.
SET TERMINAL:CHARHEIGHT TO 10.

Set SHIP:CONTROL:PILOTMAINTHROTTLE to 0.

Global RunMode is 0.0.

Global gv_ext is ".ks".

PRINT ("Initialising libraries").
//Initialise libraries first

FOR file IN LIST(
	"OrbRv" + gv_ext,
	"OrbMnvNode" + gv_ext,
	"Util_Launch"+ gv_ext,
	"Util_Vessel"+ gv_ext,
	"Util_Engine"+ gv_ext,
	"Docking" + gv_ext)
	{ 
		RUNONCEPATH("0:/Library/" + file).
		wait 0.001.	
	}
local wndw is gui(300).
set wndw:x to 400. //window start position
set wndw:y to 120.
local label is wndw:ADDLABEL("Enter Values").
  	set label:STYLE:ALIGN TO "CENTER".
  	set label:STYLE:HSTRETCH TO True. // Fill horizontally
local box_RunMode is wndw:addhlayout().
  	local RunMode_label is box_RunMode:addlabel("Runmode").
  	local RunModevalue is box_RunMode:ADDTEXTFIELD("0.1").
  	set RunModevalue:style:width to 100.
  	set RunModevalue:style:height to 18.
local somebutton is wndw:addbutton("Confirm").
set somebutton:onclick to Continue@.

// Show the GUI.
wndw:SHOW().
LOCAL isDone IS FALSE.

on abort {
	Print "on abort selected".
	set isDone to true.
	set runmode to 10.1.
	ff_Abort(). 
}

UNTIL isDone {
	WAIT 1.
}

Function Continue {
	Print "Continue".
	local val is RunModevalue:text.
	set val to val:tonumber(0).
	set RunMode to val.
	wndw:hide().
	set isDone to true.
	Print RunMode.
}

Global boosterCPU is "Hawk".
Global boosterCPU1 is "SaturnIB".
Global boosterCPU2 is "SaturnV".

Print "Waiting for activation".
//wait for active
if runMode = 0.1 { 
	Local holdload is false. 
	until holdload = true {
		Set holdload to true. //reset to true and rely on previous stage to turn false
		local PROCESSOR_List is list().
		LIST PROCESSORS IN PROCESSOR_List. // get a list of all connected cores
		for Processor in PROCESSOR_List {
			if (Processor:TAG = boosterCPU) or (Processor:TAG = boosterCPU1) or (Processor:TAG = boosterCPU2){ //checks to see if previous stage is present
				Set holdload to false.
			}
		}
		wait 0.1.
		If alt:radar < 50000 { //check for automatic abort conditions during ascent below 50,000m, above this it can be manually activiated.
			ff_CheckAbort().
		}
		//Print holdload.
	}
}

if runMode = 1.1 { 
	Print "Run mode is:" + runMode.
	ff_COMMS().
	RCS off.
	set runMode to 2.1.
}

if runmode = 2.1{
	Print "Run mode is:" + runMode.
	//docking
	// set shipPort to Ship:PARTSDUBBEDPATTERN("CSMDock").
	// print shipPort.//DEBUG
	// set shipPort to ShipPort[0].
	// Print shipPort:modules.//DEBUG
	// set targetVessel TO VESSEL("ApolloMk3 Lander").
	// set TarDock to targetvessel:PARTSDUBBEDPATTERN("LEMDock").
	// Print TarDock.//DEBUG
	// set TarDock to TarDock[0].
	// Print TarDock:modules.//DEBUG

	// wait 5.//debug

	// ff_dok_dock(shipPort, TarDock, targetVessel, 10, 0.25).
	// wait 1.
    // Shutdown. //ends the script
}
if runmode = 3.1{
	Print "Run mode is:" + runMode.
	ff_partslist("AJ10-137"). //stand partslist create for engines using node burns
	Local Starttime is time:seconds + nextnode:eta - ff_burn_time(nextnode:burnvector:mag/2).
	Print "Start time is: " + Starttime.
	ff_Alarm(Starttime).
	Until Starttime < (time:seconds + 60){
		wait 1.
	}
	ff_Node_exec(Starttime, 2, 5).
	lock throttle to 0.
	wait 1.
	Shutdown.
}

///Final and abort runmode. Return apoapsis should be 55km, 5km lower causes high G, 5km higher casuses to skip out without neutral lift (try to maintain AP at 60km).
if runMode = 10.1 { 
	Print "Run mode is:" + runMode.
	until alt:radar < 20000{ // Activate drogue and remove heatsheild cover
		Wait 0.5.
	}
	AG2 on.//Drogue chute deploy and remove top heat sheild
	until alt:radar < 3300{ // deploy main at correct alt
		Wait 0.5.
	}
	///use to main chute
	Print "cutaway and main chute".
	AG1 on.// cutaway droge an activate main
	until alt:radar < 5{ 
		Wait 1.
	}
	AG3 on.
	Shutdown.
}

