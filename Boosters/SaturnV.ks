//Prelaunch
CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
SET TERMINAL:HEIGHT TO 65.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:BRIGHTNESS TO 0.8.
SET TERMINAL:CHARHEIGHT TO 10.
// Get Mission Values

Set SHIP:CONTROL:PILOTMAINTHROTTLE to 0.

local wndw is gui(300).
set wndw:x to 700. //window start position
set wndw:y to 120.


local label is wndw:ADDLABEL("Enter Booster Values").
set label:STYLE:ALIGN TO "CENTER".
set label:STYLE:HSTRETCH TO True. // Fill horizontally

local box_inc is wndw:addhlayout().
	local inc_label is box_inc:addlabel("Heading").
	local incvalue is box_inc:ADDTEXTFIELD("93"). //93 at 4:00 prior seems to give best alignment.
	set incvalue:style:width to 100.
	set incvalue:style:height to 18.

local box_pitch is wndw:addhlayout().
	local pitch_label is box_pitch:addlabel("Start Pitch").
	local pitchvalue is box_pitch:ADDTEXTFIELD("87.75"). //Mk3 with LEM mass simulator J-2-230k: 87.5, Mk3 with J-2-230k:87.75
	set pitchvalue:style:width to 100.
	set pitchvalue:style:height to 18.

local box_APalt is wndw:addhlayout().
	local APalt_label is box_APalt:addlabel("End AP(km)").
	local APaltvalue is box_APalt:ADDTEXTFIELD("191.1").
	set APaltvalue:style:width to 100.
	set APaltvalue:style:height to 18.

local box_PEalt is wndw:addhlayout().
	local PEalt_label is box_PEalt:addlabel("End PE(km)").
	local PEaltvalue is box_PEalt:ADDTEXTFIELD("191.1").
	set PEaltvalue:style:width to 100.
	set PEaltvalue:style:height to 18.

local box_TAR is wndw:addhlayout().
	local TAR_label is box_TAR:addlabel("Launch Target").
	local TARvalue is box_TAR:ADDTEXTFIELD("Earth").
	set TARvalue:style:width to 100.
	set TARvalue:style:height to 18.

local box_OFF is wndw:addhlayout().
	local OFF_label is box_OFF:addlabel("Avg time to orbit (s)").
	local OFFvalue is box_OFF:ADDTEXTFIELD("360").
	set OFFvalue:style:width to 100.
	set OFFvalue:style:height to 18.

local box_Stg is wndw:addhlayout().
	local Stg_label is box_Stg:addlabel("PEG Stages").
	local Stgvalue is box_Stg:ADDTEXTFIELD("3").
	set Stgvalue:style:width to 100.
	set Stgvalue:style:height to 18.

local box_Res is wndw:addhlayout().
	local Res_label is box_Res:addlabel("Restart Location").
	local Resvalue is box_Res:ADDTEXTFIELD("0").
	set Resvalue:style:width to 100.
	set Resvalue:style:height to 18.

local somebutton is wndw:addbutton("Confirm").
set somebutton:onclick to Continue@.

// Show the GUI.
wndw:SHOW().
LOCAL isDone IS FALSE.
UNTIL isDone {
	WAIT 1.
}
Function Continue {

		set val to incvalue:text.
		set val to val:tonumber(0).
		Global gv_intAzimith is val.

		set val to pitchvalue:text.
		set val to val:tonumber(0).
		set gv_anglePitchover to val.

		set val to APaltvalue:text.
		set val to val:tonumber(0).
		Global tgt_ap is val*1000.

		set val to PEaltvalue:text.
		set val to val:tonumber(0).
		Global tgt_pe is val*1000.

		set val to TARvalue:text.
		set val to body(val).
		set L_TAR to val.

		set val to OFFvalue:text.
		set val to val:tonumber(0).
		set L_OFF to val.

		set val to Stgvalue:text.
		set val to val:tonumber(0).
		set Stg to val.

		set val to Resvalue:text.
		set val to val:tonumber(0).
		set runmode to val.

	wndw:hide().
  	set isDone to true.
}

Print "Azi: " + gv_intAzimith.
Print "Start Pitch: " + gv_anglePitchover. 
Print "AP at: " + tgt_ap + "m".
Print "PE turn at: " + tgt_pe + "m". 
Print "Target: " + L_TAR.
Print "Offset: " + L_OFF.
Print ship:GEOPOSITION:lat.

// Mission Values

Global gv_ext is ".ks".
Local ClearanceHeight is 130. 

PRINT ("Initialising libraries").
//Initialise libraries first

FOR file IN LIST(
	"Launch_atm"+ gv_ext,
	"OrbMnvNode" + gv_ext,
	"Util_Vessel"+ gv_ext,
	"Util_Engine"+ gv_ext)
	{ 
		RUNONCEPATH("0:/Library/" + file).
		wait 0.001.	
	}
///////////////////////////Lift Off Start up /////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

If runmode = 0{
	Wait 1. //Alow Variables to be set and Stabilise pre launch
	Print "Mission start".
	Print Stage:number.
	Print ship:mass.
	Print ship:drymass.
	Set basetime to time:seconds + 18.
	ff_preLaunch().
	ff_liftoff(0.98, 10).
	Global liftoff is time:seconds.
	Print ship:mass.
	Print ship:drymass.
	ff_liftoffclimb(gv_anglePitchover, gv_intAzimith, ClearanceHeight).
	Global Base_alt is alt:radar.
 	ff_GravityTurnAoA(gv_intAzimith, "fuelnostage", 0.0, 0.15, 1).// operate until 15% fuel fraction then shut down engine	
	Print "CECO "+ (time:seconds - liftoff).//135s
	FOR eng IN engList { 
		IF eng:TAG ="F1-C"{ 
			eng:shutdown. 
		}
	}

	ff_GravityTurnAoA(gv_intAzimith, "fuelnostage", 0.0, 0.06, 1).// operate until 6% fuel fraction then tilt arrest	
	Print "Tilt Arrest Enabled "+ (time:seconds - liftoff).//153
	set tiltArrest to ship:facing:vector.
	LOCK STEERING TO tiltArrest. //maintain current alignment
	Set Endstage to false.
	Until Endstage {
		set Endstage to ff_Flameout("fuelnostage", 0.0, 0.012, 1).// MECO at 1.2% fuel fraction then shut down all engines
		Wait 0.01.
	}
	Lock Throttle to 1.
	Print "MECO:"+(time:seconds - liftoff).//161
	Print "Speed: " + SHIP:AIRSPEED.
	Print "Altitude: " + altitude.
	Print ship:mass.
	Print ship:drymass.
	FOR eng IN engList { 
		IF eng:TAG ="F1-4" or eng:TAG ="F1-2" or eng:TAG ="F1-1" or eng:TAG ="F1-3" or eng:TAG ="F1-C"{ 
			eng:shutdown. 
		}
	}
	Wait 0.05.
	// Ullage motors
	Stage.
	Wait 0.15.
	//release S-IC
	wait until stage:ready.
	Stage.
	//S-II engine start
	Wait 0.1.
	wait until stage:ready.
	Stage.
	Print "Second Stage Ignition".
	Print ship:mass.
	Print ship:drymass.
	Set runmode to 0.1.
}

If runmode = 0.1{

//Global function variables for PEG function
	Global pegbasetime is time:seconds.
	Global PEG_I is 0.
	Global HSL is 6. //8 including extra 2s margin
	Global T3 is 143. //J-2-225k/230k:143
	Global T2 is 56. //J-2-225k:120, J-2-230k:56 
	Global T1 is 321. //J-2-225k:321, J-2-230k:321
	Global tau_lock is false.
	Global s_acc is 0. //defind in PEG
	Global s_vx_offset is 0.
	Global s_vx is 0. //defind in PEG
	Global tgt_vx is 0. //defind in PEG
	Global tgt_pex is tgt_pe.

	ff_Orbit_Steer( //use the internal orbit steer function not the launch atm version
		Stg,//Stages
		tgt_pe,
		tgt_ap,
		gv_intAzimith,
		0,//Target true anomoly
		HSL, //end shutdown margin
	//Stage 3
		T3, // stage three estimated burn length
		214, //estimated mass flow(kg/s) J-2 - 187, J-2-230k:214
		166571, //estimated start mass in kg
		4205, //estimated exhuast vel (thrust(N)/massflow(kg/s)) J-2: 4106, J-2-230k:4205
		777, //(S-Ve/avg_acc) estimated effective time to burn all propellant S-Ve = ISP*g0
	//Stage 2 //
		T2, // stage two estimated burn length
		727, //estimated mass flow(kg/s) J-2: 660, J-2-230k:727
		254600, //estimated start mass in kg
		4198, //estimated exhuast vel (thrust(kN)/massflow(kg/s)) J-2:4121 , J-2-230k:4198
		347, //(S-Ve/avg_acc) estimated effective time to burn all propellant
	//Stage 1 //
		T1, // stage one estimated burn length
		1239, //estimated mass flow J-2:1080, J-2-230k:1239
		4169, //estimated exhuast vel (do not make 0) J-2:4100, J-2-230k:4169
		667, //(S-Ve/avg_acc) estimated effective time to burn all propellant
	// shutdown offset for engine thrusts
		s_vx_offset,
	// first function to do stuff before PEG
		first@,
	// Second function just inside PEG loop
		second@,
	// Third function before thrust check
		third@,
	// forth function before HSL
		forth@,//end of function
		
		-0.23, //A3 through to B1 intial values to make converge properly
		0.001, //B3
		-0.12, //B1
		0.001, //B2
		-0.12, //A1
		0.001 //B1
	). //end of ff_orbit_steer
	Set runmode to 1.
}

If runmode = 1{
	Local counter is 0.
	Until counter > 240{
		Clearscreen.
		Print "Refine moon transfer to start descent burn before: " + (240-counter).
		wait 1.
		Set Counter to counter +1.
	}
	Set runmode to 1.1.
}

If runmode = 1.1{
	LIST ENGINES IN engList. //Get List of Engines in the vessel
	FOR eng IN engList { 
		IF eng:TAG ="J-2F" { 
			eng:activate.
		}
	}
	ff_partslist("J-2F"). //stand partslist create for engines using node burns
	Local englist is List().
	Local Starttime is time:seconds + nextnode:eta - ff_burn_time(nextnode:burnvector:mag/2).
	Print "Start time is: " + Starttime.
	Print ff_burn_time(nextnode:burnvector:mag/2).
	ff_Alarm(Starttime).
	Until time:seconds > (startTime -120){
		wait 1.
	}
	lock steering to nextnode:burnvector.
	set SteeringManager:MAXSTOPPINGTIME to 10.
	Print "Mnv set up".
	RCS on.
	until time:seconds > (startTime -20){
		wait 1.
	}
	FOR eng IN engList { 
		IF eng:TAG ="J-2F" { 
			eng:shutdown.
		}
	}
	LIST ENGINES IN engList. //Get List of Engines in the vessel
	Print "Ullage Start".
	FOR eng IN engList { 
		IF eng:TAG ="APS" { 
			eng:activate.
		}
	}
	SET SHIP:CONTROL:FORE to 1.0.
	wait until time:seconds >= (starttime).
	lock Throttle to 1.
	Print "Engine Start".
	FOR eng IN engList { 
		IF eng:TAG ="APS" { 
			eng:shutdown.
		}
	}
	FOR eng IN engList { 
		IF eng:TAG ="J-2F" { 
			eng:activate.
		}
	}
	wait 0.1.
	SET SHIP:CONTROL:FORE to 0.
	Print "EMR setup".
	FOR eng IN engList { 
		IF eng:TAG ="J-2F" { 
			Local M is eng:GETMODULE("EMRController").
			Print M:GETFIELD("current EMR").
			M:SETFIELD("current EMR",4.5).
		}
	}

	//move MRS at 116 seconds in
	until time:seconds > (startTime +116){
		wait 1.
	}
	FOR eng IN engList { 
		IF eng:TAG ="J-2F" { 
			Local M is eng:GETMODULE("EMRController").
			Print M:GETFIELD("current EMR").
			M:SETFIELD("current EMR",5).
		}
	}
	//wait until mnv complete
	set originalVector to nextnode:burnvector.
	until hf_isManeuverComplete(originalVector, nextnode:burnvector) {
		wait 0.001.
	}
	lock throttle to 0.
	unlock steering.
	RCS off.
	FOR eng IN engList { 
		IF eng:TAG ="J-2F" { 
			eng:shutdown.
		}
	}
	Print "Burn complete".
	SteeringManager:RESETTODEFAULT().
	wait 30.
	Shutdown.
}

wait 2.
Print "Stage Finshed".
Shutdown. //ends the script

function first {
	UNTIL time:seconds > (pegbasetime + 30){ //163 engines start, this occors at 193 or 30 in reality
		wait 0.1.
	}
	Stage.
	Print "S-II aft interstage release".
	Print ship:mass.
	Print ship:drymass.
	//LET release
	UNTIL time:seconds > (pegbasetime + 35){ //198 or 35 in reality
		wait 0.1.
	}
	Stage.
	Print "S-LET release".
	Print ship:mass.
	Print ship:drymass.
	SET STEERINGMANAGER:MAXSTOPPINGTIME TO 0.10.
}

function second {
	// Move to IGM phase 2
	if (time:seconds > (pegbasetime + 335)) and (PEG_I = 1){ //495
		Set PEG_I to PEG_I+1.
		Print "Tau Locked" AT (0,3).
		Set SteerLex["tau_lock"] to true.
		Print "Moving to T2" AT (0,1).
		Set SteerLex["T1_lock"] to true.
	}
	// SECO and IGM phase 3
	if (PEG_I = 4) and ff_Flameout("fuelnostage", 0.0, 0.012, 1){ //548  		// SECO at 1.2% fuel fraction then shut down all engines
		Set SteerLex["tau_lock"] to true.
		FOR eng IN engList { 
			IF eng:IGNITION ="true"{ 
				eng:shutdown. 
			}
		}
		ff_PrintLine("SECO",1). 
		// ullage motors
		Wait 0.1.
		wait until stage:ready.
		Stage.
		//seperation
		Wait 0.1.
		wait until stage:ready.
		Stage.
		//engine start
		wait until stage:ready.
		Stage.
		RCS on.
		FOR eng IN engList { 
			IF eng:TAG ="APS" { 
				eng:shutdown.
			}
			IF eng:TAG ="J-2F" { 
				Local M is eng:GETMODULE("EMRController").
				Print M:GETFIELD("current EMR").
				M:SETFIELD("current EMR",4.93).//4.93
				M:DOEvent("Show EMR Controller").
			}
		}
		Set PEG_I to PEG_I+1.
		SET STEERINGMANAGER:MAXSTOPPINGTIME TO 1.
		wait 1. //allow engine to ignite
		Set SteerLex["tau_lock"] to false.
		Set SteerLex["T2_lock"] to true.
	}
}

function third{
	//Centre engine cutout
	if (time:seconds > (pegbasetime + 300)) and (PEG_I = 0){ //460 or 300 in reality
		Local englist is List().
		LIST ENGINES IN engList.
		FOR eng IN engList { 
			IF eng:TAG ="J-2C" { 
				eng:shutdown.
			}
		}
		ff_PrintLine("CECO",1).
		Set PEG_I to PEG_I+1.
		Set T1 to 38.//force a new base value
	}

	//High(5.5) to low MRS(4.34) command 
	if (time:seconds > (pegbasetime + 338)) and (PEG_I = 2){ //498 or 338 in reality
		LIST ENGINES IN engList.
		FOR eng IN engList { 
			IF eng:TAG ="J-2" { 
				Local M is eng:GETMODULE("EMRController").
				M:SETFIELD("current EMR", 4.34).//4.34
				M:DOEvent("Show EMR Controller").
				//M:DOAction("change EMR mode", true).
			}
		}
		ff_PrintLine("Mixture Ratio Shift",1).
		Set PEG_I to PEG_I+1.
		wait 3. //this prevents staging due to the EMR shift
	}

	// End tau mode
	if (time:seconds > (pegbasetime + 345)) and (PEG_I = 3){ //504
		Set SteerLex["tau_lock"] to false.
		Print "Tau unlocked" AT (0,3).
		Set PEG_I to PEG_I+1.
	}
	
	/// End tau mode
	if PEG_I = 5{
		Set tau_lock to false.
		Print "Tau unlocked" AT (0,3).
	}
}

function forth {
	//enter chi-tilde approximately (HSL *2) to stop using the A and B terms.
	if  (SteerLex["T3"] < (HSL*7)) and (PEG_I > 3){ //HSL*7 is around 42 seconds
		Set SteerLex["chiTilde"] to True.
		Print "chiTilde" AT (0,1).
	}
	//cutoff process
	if  (SteerLex["T3"] < (HSL+2)) and (PEG_I > 3){ //HSL+2 is to ensure this loop goes before the main PEG loop HSL
		ff_PrintLine("HSL Phase",1).
		set SteerLex["tau_lock"] to true.
		Until false{
			set s_vx to sqrt(ship:velocity:orbit:sqrmagnitude - ship:verticalspeed^2) + s_vx_offset.
			Local track is time:seconds.
			//Set up for ECO command
			until (ship:orbit:eccentricity < 0.0002) or (ship:periapsis > tgt_pe-500) or (s_vx > (tgt_vx-1)) or (time:seconds > track + HSL) {
				wait 0.5.
				set s_vx to sqrt(ship:velocity:orbit:sqrmagnitude - ship:verticalspeed^2) + s_vx_offset.
				Print tgt_vx AT (0,10). //DEBUG
				Print s_vx AT (0,11). //DEBUG
				Print ship:orbit:eccentricity AT (0,12). //DEBUG
				//KUniverse:PAUSE(). //DEBUG
			}
			//shutdown engine but keep throttle up for APS
			FOR eng IN engList { 
				IF eng:TAG ="J-2F" { 
					eng:shutdown.
				}
			}
			ff_PrintLine("ECO",1).
			ff_PrintLine("APS Phase",2).
			ff_PrintLine("Orbit Refining",3).
			set peg_step to 1000.
			//APS ullage command
			FOR eng IN engList { 
				IF eng:TAG ="APS" { 
					eng:activate.
				}
			}
			//Set up for APS shut off
			until (ship:orbit:eccentricity < 0.0001) or (ship:periapsis > tgt_pex) or (tgt_vx < s_vx) or (time:seconds > track + 30){
				set s_vx to sqrt(ship:velocity:orbit:sqrmagnitude - ship:verticalspeed^2) + s_vx_offset.
				//Print tgt_vx AT (0,10). //DEBUG
				//Print s_vx AT (0,11). //DEBUG
				//Print ship:orbit:eccentricity AT (0,12). //DEBUG
				//KUniverse:PAUSE(). //DEBUG
				wait 0.001.
			}
			//Shutdown APS
			FOR eng IN engList { 
				IF eng:TAG ="APS" { 
					eng:shutdown.
				}
			}
			Lock Throttle to 0.
			Set SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
			ff_PrintLine("Insertion: "+ (TIME:SECONDS),1).
			ff_PrintLine("Hold",2).
			RCS off.	
			Set SteerLex["loop_break"] to true.
			break.
		}
	}	
}