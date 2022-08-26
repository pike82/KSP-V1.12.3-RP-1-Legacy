CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
SET TERMINAL:HEIGHT TO 65.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:BRIGHTNESS TO 0.8.
SET TERMINAL:CHARHEIGHT TO 10.

Global RunMode is 0.0.

//Hawk values 86, 190, 190

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
local box_END is wndw:addhlayout().
	local END_label is box_END:addlabel("AP Transistion END (km)").
	local ENDvalue is box_END:ADDTEXTFIELD("180000").
	set ENDvalue:style:width to 100.
	set ENDvalue:style:height to 18.
local somebutton is wndw:addbutton("Confirm").
set somebutton:onclick to Continue@.

// Show the GUI.
wndw:SHOW().
LOCAL isDone IS FALSE.
UNTIL isDone {
	WAIT 1.
}
Function Continue {
local val is RunModevalue:text.
	set val to val:tonumber(0).
	set RunMode to val.

set val to ENDvalue:text.
	set val to ENDvalue:text.
	set val to val:tonumber(0).
	Global endheight is val*1000.

	wndw:hide().
	set isDone to true.
}

Global gv_ext is ".ks".

PRINT ("Initialising libraries").
//Initialise libraries first

FOR file IN LIST(
	"OrbMnvs" + gv_ext,
	"OrbMnvNode" + gv_ext,
	"Util_Orbit"+ gv_ext,
	"Util_Vessel"+ gv_ext,
	"Util_Engine"+ gv_ext)
	{ 
		RUNONCEPATH("0:/Library/" + file).
		wait 0.001.	
	}

Global boosterCPU is "Hawk".
ff_partslist(). //standard partslist create

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
Print "ZeusGeo active".
wait 0.25.

if runMode = 0.1 { 
	Print "Run mode is:" + runMode.
	ff_COMMS().
	ff_avionics_on().
	RCS on.
	SET SHIP:CONTROL:FORE to 1.0.
	wait 5. //move away from booster.
	RCS off.
	set runMode to 1.1.
}

if runMode = 1.1 { 
	Print "Run mode is:" + runMode.
	ff_AdjOrbGeo(0, endheight ,0 , 0 , 1 ,0).
	set runMode to 2.1.
}
if runMode = 2.1 { 
	Print "Run mode is:" + runMode.
	ff_node_time(180).
	set runMode to 3.1.
}
if runMode = 3.1 { 
	Print "Run mode is:" + runMode.
	Local Starttime is time:seconds + nextnode:eta - ff_burn_time(nextnode:burnvector:mag/2).
	Print "Start time is: " + Starttime.
	ff_Alarm(Starttime).
	Until Starttime < (time:seconds + 60){
		wait 1.
	}
	ff_avionics_on().
	ff_Node_exec(Starttime, 2).
	ff_avionics_off().
	set runMode to 4.1.
}
if runMode = 4.1 { 
	Print "Run mode is:" + runMode.
	ff_AdjOrbGeo(0, 0, 35793172, 800000, 0, 1).
	set runMode to 5.1.
}
if runMode = 5.1 { 
	Print "Run mode is:" + runMode.
	ff_node_time(180).
	set runMode to 6.1.
}
if runMode = 6.1 { 
	Print "Run mode is:" + runMode.
	Local Starttime is time:seconds + nextnode:eta - ff_burn_time(nextnode:burnvector:mag/2).
	Print "Start time is: " + Starttime.
	ff_Alarm(Starttime).
	Until Starttime < (time:seconds + 60){
		wait 1.
	}
	ff_avionics_on().
	ff_Node_exec(Starttime, 2).
	ff_avionics_off().
	set runMode to 7.1.
}
if runMode = 7.1 { 
	Print "Run mode is:" + runMode.
	ff_Circ().
	//ff_AdjOrbGeo(0, 35793172, 35793172, 1000).
	set runMode to 8.1.
}
if runMode = 8.1 { 
	Print "Run mode is:" + runMode.
	Local Starttime is time:seconds + nextnode:eta - ff_burn_time(nextnode:burnvector:mag/2).
	Print "Start time is: " + Starttime.
	ff_Alarm(Starttime).
	Until Starttime < (time:seconds + 60){
		wait 1.
	}
	ff_avionics_on().
	ff_Node_exec(Starttime, 2).
	ff_avionics_off().
	set runMode to 9.1.
}
if runMode = 9.1 { 
	Print "Run mode is:" + runMode.
	wait 10.
	set runMode to 10.1.
}
if runMode = 10.1 { 
	Print "Run mode is:" + runMode.
	wait 10.
	Shutdown.
}