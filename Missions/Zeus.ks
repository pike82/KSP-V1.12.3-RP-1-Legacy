//upper stage for spin stabilised probes

CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
SET TERMINAL:HEIGHT TO 65.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:BRIGHTNESS TO 0.8.
SET TERMINAL:CHARHEIGHT TO 10.

Global gv_ext is ".ks".
Global RunMode is 0.1.

PRINT ("Initialising libraries").
//Initialise libraries first

FOR file IN LIST(
	"Util_Vessel"+ gv_ext,
	"Util_Engine"+ gv_ext)
	{ 
		RUNONCEPATH("0:/Library/" + file).
		wait 0.001.	
	}

Global boosterCPU is "Bluebird".
ff_partslist(). //stand partslist create

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
Print "Zeus active".
wait 0.25.

if runMode = 0.1 { 
	Print "Run mode is:" + runMode.
	Local Endstage is false.
	Until Endstage {
		set Endstage to ff_FLAMEOUT("RCS", 0.01).
		Wait 0.05.
	}
	set runMode to 1.1.
}

if runMode = 1.1 { 
	Print "Run mode is:" + runMode.
	wait 10.
	Shutdown.
}