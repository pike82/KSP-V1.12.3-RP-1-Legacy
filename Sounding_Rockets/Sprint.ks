@LAZYGLOBAL OFF.
CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
SET TERMINAL:HEIGHT TO 65.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:BRIGHTNESS TO 0.8.
SET TERMINAL:CHARHEIGHT TO 10.

Local sv_ClearanceHeight is 10. 
Global gv_ext is ".ks".
Global RunMode is 0.1.

PRINT ("Initialising libraries").
//Initialise libraries first

FOR file IN LIST(
	"Launch_atm"+ gv_ext,
	"Util_Vessel"+ gv_ext)
	{ 
		RUNONCEPATH("0:/Library/" + file).
		wait 0.001.	
	}

if runMode = 0.1 { 
	Print "Run mode is:" + runMode.
	ff_preLaunch().
	ff_liftoff(0.8).
	set runMode to 1.1.
}	

if runMode = 1.1 { 
	Print "Run mode is:" + runMode.
	Wait until Stage:Ready. 
	wait 1.1.
	Stage.//drop solid
	set runMode to 2.1.
}	

if runMode = 2.1 { 
	Print "Run mode is:" + runMode.
 	set runMode to 3.1.
}	

if runMode = 3.1 { 
	Print "Run mode is:" + runMode.
	Until ((ship:verticalspeed < 0) and (ship:altitude > 200)){
		wait 2.	
	}
	Lock Throttle to 0.
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
	Stage. // Decouple chutes if present
	ff_R_chutes(). //activate chutes
}
