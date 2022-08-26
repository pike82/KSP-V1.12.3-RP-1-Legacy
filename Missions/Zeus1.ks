////upper stage for controlled probes with nodes manuvers

CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
SET TERMINAL:HEIGHT TO 65.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:BRIGHTNESS TO 0.8.
SET TERMINAL:CHARHEIGHT TO 10.

Global RunMode is 0.0.

//Hawk Mk3 values 86 , 250, 250 (light 3T) or 86,200,200 (heavy 3.5T)

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
local box_pe is wndw:addhlayout().
  	local pe_label is box_pe:addlabel("PE (km)").
  	local pevalue is box_pe:ADDTEXTFIELD("50").
  	set pevalue:style:width to 100.
  	set pevalue:style:height to 18.
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

set val to pevalue:text.
	set val to val:tonumber(0).
	set gv_pe to val.
	wndw:hide().
	set isDone to true.
}

Global gv_ext is ".ks".

PRINT ("Initialising libraries").
//Initialise libraries first

FOR file IN LIST(
	"OrbRv" + gv_ext,
	"OrbMnvNode" + gv_ext,
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
Print "Zeus1 active".
wait 0.25.
	Set SHIP:CONTROL:PILOTMAINTHROTTLE to 0.

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
	SET SHIP:CONTROL:FORE to 0.0.
	ff_avionics_off().
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
	Wait 5.
	Shutdown.
}