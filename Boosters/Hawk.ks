//Early booster with PEG guidance second stage.

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
local box_ap is wndw:addhlayout().
  	local ap_label is box_ap:addlabel("AP (km)").
  	local apvalue is box_ap:ADDTEXTFIELD("160").
  	set apvalue:style:width to 100.
  	set apvalue:style:height to 18.
local box_pe is wndw:addhlayout().
  	local pe_label is box_pe:addlabel("PE (km)").
  	local pevalue is box_pe:ADDTEXTFIELD("160").
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
local val is azivalue:text.
	set val to val:tonumber(0).
	set gv_intAzimith to val.
set val to pitchvalue:text.
	set val to val:tonumber(0).
	set gv_anglePitchover to val.
set val to apvalue:text.
	set val to val:tonumber(0).
	set gv_ap to val.
set val to pevalue:text.
	set val to val:tonumber(0).
	set gv_pe to val.
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
ff_partslist(). //stand partslist create

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
	ff_GravityTurnAoA(gv_intAzimith, "RCS", 0.0, 0.995, 1).
	set runMode to 2.1.
	Print "MECO".
}	

if runMode = 2.1 { 
	Print "Run mode is:" + runMode.
	Wait 1. //allow engine to fully start up.
	ff_Orbit_Steer(
		1,//Stages
		gv_pe*1000,
		gv_ap*1000,
		gv_intAzimith,
		0,//Target true anomoly
		1, //shutdown stability lock parameters time.
		//Stage 3
		150, // stage three estimated burn length
		118, //estimated mass flow(kg/s)
		24500, //estimated start mass in kg
		3067, //estimated exhuast vel (thrust(N)/massflow(kg/s))
		150, ////(S-Ve/avg_acc(in m/s)) estimated effective time to burn all propellant.S-Ve = ISP*g0

		0,1,1,1,1,//T2 values
		0,0,1,1,//T1 values

		5, /// overburns by about 5m/s of average due to seperation thrusters
		{},
		{	
			if (SHIP:Q < 0.005) and (SteerLex["fairlock"] = false) {
				ff_Fairing().
				Print "Fairings Delpolyed: " + MISSIONTIME AT (0,1).
				set SteerLex["fairlock"] to true.
			}
		}
	).
 	set runMode to 3.1.
}	

if runMode = 3.1 { 
	Print "Run mode is:" + runMode.
	Stage. //payload release
	wait 1.
	if not Stage:NUMBER = 0{
		Stage. //additional if fairing relased was missed 
	}
	set runMode to 4.1.
}

if runMode = 4.1 { 
	Print "Run mode is:" + runMode.
	Wait 5.
	Shutdown.
}
