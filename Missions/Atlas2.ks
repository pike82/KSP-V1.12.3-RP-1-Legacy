//Gemini Capsule

CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
SET TERMINAL:HEIGHT TO 65.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:BRIGHTNESS TO 0.8.
SET TERMINAL:CHARHEIGHT TO 10.

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

on abort {
	set isDone to true.
	set runmode to 10.1.
	ff_Abort(). 

}

UNTIL isDone {
	ff_CheckAbort().
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

Global boosterCPU is "Hawk".

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
	wait 0.1.
	If alt:radar < 50000 { //check for automatic abort conditions during ascent below 50,000m, above this it can be manually activiated.
		ff_CheckAbort().
	}
}
Print "Atlas 2 active".
wait 0.25.
	Set SHIP:CONTROL:PILOTMAINTHROTTLE to 0.

if runMode = 0.1 { 
	Print "Run mode is:" + runMode.
	ff_COMMS().
	RCS off.
	set runMode to 1.1.
}

if runMode = 1.1 { 
	Print "Run mode is:" + runMode.
	//deorbit burn is 100m/s
	set runMode to 10.1.
}

if runmode = 2.1{
	//docking
	set targetVessel TO VESSEL("Hawk Mk3 - Zeus1-Target").
	set shipPort to Ship:PARTSDUBBEDPATTERN("DockGem").
	print shipPort.
	set shipPort to ShipPort[0].
	set TarDock to targetvessel:PARTSDUBBEDPATTERN("TarPort").
	Print TarDock.
	set TarDock to TarDock[0].

	ff_dok_dock(shipPort, TarDock, targetVessel, 20, 0.25).
}
if runmode = 3.1{
	//undocking
	//set targetVessel TO VESSEL("Hawk Mk3 - Zeus1-Target").
	set shipPort to Ship:PARTSDUBBEDPATTERN("DockGem").
	print shipPort.
	set shipPort to ShipPort[0].
	set TarDock to ship:PARTSDUBBEDPATTERN("TarPort").
	Print TarDock.
	set TarDock to TarDock[0].

	ff_undock( shipPort, TarDock, SHIP, 10).
}

///Final and abort runmode
if runMode = 10.1 { 
	Print "Run mode is:" + runMode.
	until alt:radar < 10000{ // deploy drogue at correct alt
		Wait 0.5.
	}
	//Drogue chute deploy
	AG2 on.
	until alt:radar < 3300{ // deploy main at correct alt
		Wait 0.5.
	}
	///use to main chute
	Print "cutaway and main chute".
	AG1 on.
	until alt:radar < 5{ // deploy recovery aids
		Wait 1.
	}
	AG3 on.
	Shutdown.
}