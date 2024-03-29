//Lander moon shot

CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
SET TERMINAL:HEIGHT TO 65.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:BRIGHTNESS TO 0.8.
SET TERMINAL:CHARHEIGHT TO 10.

Global RunMode is 0.0.

//Hawk values 86, 200, 200

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
	"Util_Orbit"+ gv_ext,
	"Util_Engine"+ gv_ext,
	"Landing_vac"+ gv_ext)
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
Print "Luna3 active".
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
	Stage. //Activate engine for mnv planning.
	set runMode to 2.1.
}
if runMode = 2.1 { 
	Print "Run mode is:" + runMode.
	ff_Hohmann(body("Moon"), gv_pe).
	set runMode to 3.1.
}
if runMode = 3.1 { 
	Print "Run mode is:" + runMode.
	ff_node_time(180).
	set runMode to 4.1.
}
if runMode = 4.1 { 
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
	set runMode to 5.1.
}
if runMode = 5.1 { 
	Print "Run mode is:" + runMode.
	ff_avionics_on().
	RCS on.
	Print "Pointing to Sun".
	lock steering to sun:position.//lock pointed towards the sun to maximise solar
	Wait 30.
	Print "spinning".
	set ship:control:roll to 1.//spin stabilise in orbit
	wait 10.
	ff_avionics_off().
	RCS off.
	set runMode to 6.1.
}
if runMode = 6.1 { 
	Print "Run mode is:" + runMode.
	ff_node_time(180). //set up node to go into the moon surface
	set runMode to 7.1.
}
if runMode = 7.1 { 
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
	set runMode to 8.1.
}
if runMode = 8.1 { 
	Print "Run mode is:" + runMode.
	until ALT:RADAR < 6000{
		wait 0.1.
	}
	ff_avionics_on().
	RCS on.
	ff_CAB(time:seconds-1, 5000, 1000, -150, 45).//BurnStartTime, EndHeight, EndSp, VertStp , maxpitch, ThrottelStartTime.
	ff_CAB(time:seconds-1, 1500, 500, -50, 60).//BurnStartTime, EndHeight, EndSp, VertStp , maxpitch, ThrottelStartTime.
	ff_CAB(time:seconds-1, 750, 10, -10, 60).//BurnStartTime, EndHeight, EndSp, VertStp , maxpitch, ThrottelStartTime.
	lock throttle to 0.
	wait 0.1.
	set runMode to 9.1.
}

if runMode = 9.1 { 
	Print "Run mode is:" + runMode.
	wait 1.0.
	Stage.
	Local engine_count is 0.
	Local thrust is 0.
	Local isp is 0.
	list engines in all_engines.
	for en in all_engines {
		if en:ignition and not en:flameout {
			set thrust to thrust + en:possiblethrust.
			set isp to isp + en:ISPAT(0).
			set engine_count to engine_count + 1.
		}
	}
	set isp to isp/engine_count. //assumes only one type of engine in cluster
	set thrust to thrust * 1000. // Engine Thrust (kg * m/s²)
	ff_SuBurn(isp, thrust, 0.1, 750).//Parameter EngISP, EngThrust, ThrottelStartUp is 0.1, SafeAlt is 5, EndVelocity is (-1.5). // end velocity must be negative
	ff_SuBurn(isp, thrust, 0.1, 50).//Parameter EngISP, EngThrust, ThrottelStartUp is 0.1, SafeAlt is 5, EndVelocity is (-1.5). // end velocity must be negative
	ff_SuBurn(isp, thrust).//Parameter EngISP, EngThrust, ThrottelStartUp is 0.1, SafeAlt is 5, EndVelocity is (-1.5). // end velocity must be negative
	set runMode to 10.1.
}
if runMode = 10.1 { 
	Print "Run mode is:" + runMode.
	Wait 15.
	ff_avionics_off().
	Wait 1.
	Shutdown.
}