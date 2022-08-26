//Early booster with spin stab second stage at AP.

CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
SET TERMINAL:HEIGHT TO 65.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:BRIGHTNESS TO 0.8.
SET TERMINAL:CHARHEIGHT TO 10.

local wndw is gui(300).
set wndw:x to 400. //window start position
set wndw:y to 120.
local label is wndw:ADDLABEL("Enter Values").
  	set label:STYLE:ALIGN TO "CENTER".
  	set label:STYLE:HSTRETCH TO True. // Fill horizontally
local box_azi is wndw:addhlayout().
  	local azi_label is box_azi:addlabel("Heading").
  	local azivalue is box_azi:ADDTEXTFIELD("90").
  	set azivalue:style:width to 100.
  	set azivalue:style:height to 18.
local box_pitch is wndw:addhlayout().
  	local pitch_label is box_pitch:addlabel("Start Pitch").
  	local pitchvalue is box_pitch:ADDTEXTFIELD("87").
  	set pitchvalue:style:width to 100.
  	set pitchvalue:style:height to 18.
local box_pitch is wndw:addhlayout().
  	local apwait_label is box_pitch:addlabel("AP wait").
  	local apwaitvalue is box_pitch:ADDTEXTFIELD("125").
  	set apwaitvalue:style:width to 100.
  	set apwaitvalue:style:height to 18.
local somebutton is wndw:addbutton("Confirm").
set somebutton:onclick to Continue@.
// Show the GUI.
wndw:SHOW().
LOCAL isDone IS FALSE.
UNTIL isDone {
	WAIT 1.
}
Function Continue {
local val is azivalue:text.
	set val to val:tonumber(0).
	set gv_intAzimith to val.
set val to pitchvalue:text.
	set val to val:tonumber(0).
	set gv_anglePitchover to val.
set val to apwaitvalue:text.
	set val to val:tonumber(0).
	set gv_apwait to val.
	wndw:hide().
	set isDone to true.
}

Local ClearanceHeight is 90. 
Global gv_ext is ".ks".
Global RunMode is 0.1.

PRINT ("Initialising libraries").
//Initialise libraries first

FOR file IN LIST(
	"Launch_atm"+ gv_ext,
	"Util_Vessel"+ gv_ext,
	"Util_Engine"+ gv_ext)
	{ 
		RUNONCEPATH("0:/Library/" + file).
		wait 0.001.	
	}

if runMode = 0.1 { 
	Print "Run mode is:" + runMode.
	ff_preLaunch().
	ff_liftoff().
	ff_liftoffclimb(gv_anglePitchover, gv_intAzimith, ClearanceHeight).
	set runMode to 1.1.
}	

if runMode = 1.1 { 
	Print "Run mode is:" + runMode.
	Wait until Stage:Ready.
	ff_GravityTurnAoA(gv_intAzimith).
	set runMode to 2.1.
	Print "MECO".
}	

if runMode = 2.1 { 
	Print "Run mode is:" + runMode.
	ff_coastT(gv_apwait, gv_intAzimith).
 	set runMode to 3.1.
}	

if runMode = 3.1 { 
	Print "Run mode is:" + runMode.
	ff_COMMS().
	ff_SpinStab(gv_intAzimith, 0, 10).
	wait 30.
	set runMode to 4.1.
}

if runMode = 4.1 { 
	Print "Run mode is:" + runMode.
	LOCK Throttle to 1.
	Set SHIP:CONTROL:PILOTMAINTHROTTLE to 1.
	wait 15. //ullage
	Stage. //jettison avionics and start engine
	Print "Avionics Jettison".
	set runMode to 5.1.
}
if runMode = 5.1 { 
	Print "Run mode is:" + runMode.
	Local Endstage is false.
	Until Endstage {
		set Endstage to ff_FLAMEOUT("RCS", 0.01).
		Wait 0.05.
	}
	Print "SECO".
}