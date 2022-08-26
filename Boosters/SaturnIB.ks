//Prelaunch
CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
SET TERMINAL:HEIGHT TO 65.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:BRIGHTNESS TO 0.8.
SET TERMINAL:CHARHEIGHT TO 10.
// Get Mission Values

local wndw is gui(300).
set wndw:x to 700. //window start position
set wndw:y to 120.


local label is wndw:ADDLABEL("Enter Booster Values").
set label:STYLE:ALIGN TO "CENTER".
set label:STYLE:HSTRETCH TO True. // Fill horizontally

local box_inc is wndw:addhlayout().
	local inc_label is box_inc:addlabel("Heading").
	local incvalue is box_inc:ADDTEXTFIELD("90").
	set incvalue:style:width to 100.
	set incvalue:style:height to 18.

local box_pitch is wndw:addhlayout().
	local pitch_label is box_pitch:addlabel("Start Pitch").
	local pitchvalue is box_pitch:ADDTEXTFIELD("88.0").// 88.75 for Mk0, 87.5 for Mk1, 88.0 for SaturnIV Explorer
	set pitchvalue:style:width to 100.
	set pitchvalue:style:height to 18.

local box_APalt is wndw:addhlayout().
	local APalt_label is box_APalt:addlabel("End AP(km)").
	local APaltvalue is box_APalt:ADDTEXTFIELD("190").//161.1 base, 190 for SaturnIV Explorer
	set APaltvalue:style:width to 100.
	set APaltvalue:style:height to 18.

local box_PEalt is wndw:addhlayout().
	local PEalt_label is box_PEalt:addlabel("End PE(km)").
	local PEaltvalue is box_PEalt:ADDTEXTFIELD("190").//161.1 base, 190 for SaturnIV Explorer
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
	local Stgvalue is box_Stg:ADDTEXTFIELD("1").
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
Local ClearanceHeight is 80. 

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
	ff_GravityTurnAoA(gv_intAzimith, "fuelnostage", 0.0, 0.06, 1).// operate until 6% fuel fraction then tilt arrest	
	Print "Tilt Arrest Enabled "+ (time:seconds - liftoff).
	set tiltArrest to ship:facing:vector.
	LOCK STEERING TO tiltArrest. //maintain current alignment
	Set Endstage to false.
	Until Endstage {
		set Endstage to ff_Flameout("fuelnostage", 0.0, 0.012, 1).// MECO at 1.2% fuel fraction then shut down all engines
		Wait 0.01.
	}
	Lock Throttle to 1.
	Print "MECO:"+(time:seconds - liftoff).//147
	Print "Speed: " + SHIP:AIRSPEED.
	Print "Altitude: " + altitude.
	Print ship:mass.
	Print ship:drymass.
	//release S-IB
	wait 0.1.
	Stage.
	wait until stage:ready.
	//S-IV engine start
	Wait 0.3.
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
	Global T3 is 143. 
	Global T2 is 0. 
	Global T1 is 0. 
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
		214, //estimated mass flow(kg/s) 
		166571, //estimated start mass in kg
		4106, //estimated exhuast vel (thrust(N)/massflow(kg/s)) 
		777, //(S-Ve/avg_acc) estimated effective time to burn all propellant S-Ve = ISP*g0
	//Stage 2 //
		T2, // stage two estimated burn length
		1, //estimated mass flow(kg/s) J-2: 660, J-2-230k:727
		1, //estimated start mass in kg
		1, //estimated exhuast vel (thrust(kN)/massflow(kg/s)) J-2:4121 , J-2-230k:4198
		1, //(S-Ve/avg_acc) estimated effective time to burn all propellant
	//Stage 1 //
		T1, // stage one estimated burn length
		1, //estimated mass flow J-2:1080, J-2-230k:1239
		1, //estimated exhuast vel (do not make 0) J-2:4100, J-2-230k:4169
		1, //(S-Ve/avg_acc) estimated effective time to burn all propellant
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

	Set runmode to 1.1.
}

If runmode = 1.1{

}

wait 2.
Print "Stage Finshed".
Shutdown. //ends the script

function first {
	UNTIL time:seconds > (pegbasetime + 10){ //143 engines start, this occurs at 154
		wait 0.1.
	}
	Stage.
	Print "S-IV aft interstage release".
	Print ship:mass.
	Print ship:drymass.
	//LET release
	UNTIL time:seconds > (pegbasetime + 20){ //165
		wait 0.1.
	}
	Stage.
	Print "S-LET release".
	Print ship:mass.
	Print ship:drymass.
	SET STEERINGMANAGER:MAXSTOPPINGTIME TO 0.10.

	FOR eng IN engList { 
		IF eng:TAG ="APS" { 
			eng:shutdown.
		}
	}
	RCS on.
}

function second {

}
function third{
	//High(5.5) to low MRS(4.34) command 
	if (time:seconds > (pegbasetime + 329)) and (PEG_I = 0){ //469
		LIST ENGINES IN engList.
		FOR eng IN engList { 
			IF eng:TAG ="J-2F" { 
				Local M is eng:GETMODULE("EMRController").
				//M:DOAction("change EMR mode", true).
			}
		}
		ff_PrintLine("Mixture Ratio Shift",1).
		Set PEG_I to PEG_I+1.
		wait 3. //this prevents staging due to the EMR shift
	}
}

function forth {
	//enter chi-tilde approximately (HSL *2) to stop using the A and B terms.
	if  (SteerLex["T3"] < (HSL*7)) and (PEG_I > 1){ //HSL*7 is around 42 seconds
		Set SteerLex["chiTilde"] to True.
		Print "chiTilde" AT (0,1).
	}
	//cutoff process
	if  (SteerLex["T3"] < (HSL+2)) and (PEG_I > 1){ //HSL+2 is to ensure this loop goes before the main PEG loop HSL
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