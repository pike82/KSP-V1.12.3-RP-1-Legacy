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

local box_LAN is wndw:addhlayout().
	local LAN_label is box_LAN:addlabel("Desired LAN").
	local LANvalue is box_LAN:ADDTEXTFIELD("0").
	set LANvalue:style:width to 100.
	set LANvalue:style:height to 18.

local box_inc is wndw:addhlayout().
	local inc_label is box_inc:addlabel("Desired Inclination").
	local incvalue is box_inc:ADDTEXTFIELD("0").
	set incvalue:style:width to 100.
	set incvalue:style:height to 18.

local box_node is wndw:addhlayout().
	local node_label is box_node:addlabel("Towards AN").
	local nodevalue is box_node:ADDTEXTFIELD("True").
	set nodevalue:style:width to 100.
	set nodevalue:style:height to 18.

local box_pitch is wndw:addhlayout().
	local pitch_label is box_pitch:addlabel("Start Pitch").
	local pitchvalue is box_pitch:ADDTEXTFIELD("90").
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
		set val to LANvalue:text.
		set val to val:tonumber(0).
		set tgt_LAN to val.

		set val to incvalue:text.
		set val to val:tonumber(0).
		Global tgt_inc is val.

		set val to nodevalue:text.
		set To_AN to val.

		set val to pitchvalue:text.
		set val to val:tonumber(0).
		set sv_anglePitchover to val.

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

Print "Taget LAN: " + tgt_LAN.
Print "Inc: " + tgt_inc.
Print "to_an: " + to_an.
Print "Start Pitch: " + sv_anglePitchover. 
Print "AP at: " + tgt_ap + "m".
Print "PE turn at: " + tgt_pe + "m". 
Print "Target: " + L_TAR.
Print "Offset: " + L_OFF.
Print ship:GEOPOSITION:lat.

// Mission Values

Global lncwin is ff_launchwindow(tgt_inc, L_TAR, tgt_LAN, To_AN).//returns azimuth and time until launch
Print lncwin [0].
Print lncwin [1].
Global sv_intAzimith is lncwin [0]. 
Global EngineStartTime is lncwin [1].
Set EngineStartTime to TIME:SECONDS + EngineStartTime - (L_OFF).
Global sv_ClearanceHeight is 137. //tower clearance height


function ff_launchwindow{
Parameter tgt_inc is 0, tgt is Earth, tgt_LAN is 0, To_AN is true.
	local RetAzi is 90.
	local RetETA is 0.

//Work out Earth possibilities
	If tgt = Earth{
		If (tgt_inc = 0) and (tgt_LAN = 0) {
			Return list(RetAzi, RetETA).// launch east now
		} 
		
		If (tgt_inc = 0){
			Set RetETA to ff_ETAToPlane(BODY, tgt_LAN, 90, To_AN).
			Return list(RetAzi, RetETA).// launch Azi at eta

		}


		set ra to body:radius + tgt_ap. //full Ap
		set rp to body:radius + tgt_pe. //full pe
		local sma is (ra+rp)/2. //sma
		local ecc is (ra-rp)/(ra+rp). //eccentricity
		local V_p is sqrt((2*body:mu*ra)/(rp*2*sma)). // this is the target velocity at the periapsis

		if tgt_inc < abs(latitude) { //If the inclination of the target is less than the lattitude of the ship
			Set tgt_inc to abs(latitude).
			Print "Latitude unable to allow normal Launch to inclination, switching to nearest inclination!!!".
			wait 5.
			Set RetAzi to f_FlightAzimuth(tgt_inc, V_p).
			If To_AN <> true { Set RetAzi to 180 - RetAzi.}

			If tgt_LAN = 0{
				Return list(RetAzi, RetETA).// launch Azi now
			}
		}

		Set RetAzi to f_FlightAzimuth(tgt_inc, V_p).
		If tgt_LAN = 0{
				Return list(RetAzi, RetETA).// launch Azi now
		}
		Set RetETA to ff_ETAToPlane(BODY, tgt_LAN, tgt_inc, To_AN).
		Return list(RetAzi, RetETA).// launch Azi at eta
	}

	Set tgt_inc to tgt:orbit:inclination.// for craft and the moon and other planets
	Set tgt_LAN to tgt:OBT:LAN. // for craft and the moon and other planets

//Work out solar system possibilities

	set ra to body:radius + tgt_ap. //full Ap
	set rp to body:radius + tgt_pe. //full pe
	local sma is (ra+rp)/2. //sma
	local ecc is (ra-rp)/(ra+rp). //eccentricity
	local V_p is sqrt((2*body:mu*ra)/(rp*2*sma)). // this is the target velocity at the periapsis

	if tgt_inc < abs(latitude) { //If the inclination of the target is less than the lattitude of the ship
		Set tgt_inc to abs(latitude). //TODO for future with PEG dog legging.
		//Set incDiff to ship:orbit:inclination-tgt:orbit:inclination.
		Print "Latitude unable to allow normal Launch to inclination, switching to nearest inclination!!!".
		wait 1.
		Set RetETA to ff_ETAToPlane(BODY, tgt_LAN, tgt_inc, To_AN).
		Return list(90, RetETA).// launch west Azi at eta
	}

	Print "tgt_inc" + tgt_inc.
	Print "tgt_LAN" + tgt_LAN.
	Global tgt_inc is tgt_inc.
	Global tgt_LAN is tgt_LAN.

	Set RetAzi to f_FlightAzimuth(tgt_inc, V_p).
	Set RetETA to ff_ETAToPlane(BODY, tgt_LAN, tgt_inc, To_AN).
	Return list(RetAzi, RetETA).// launch Azi at eta

	Print vang(hf_normalvector(ship),hf_normalvector(tgt)).
	wait 5.
	return vang(hf_normalvector(ship),hf_normalvector(tgt)).
}

function f_FlightAzimuth {
	parameter inc, V_orb. // target inclination

	// project desired orbit onto surface heading
	Print "inc:"+ inc.
	Print tgt_inc.
	Print ship:latitude.
	Print cos(inc).
	Print cos(ship:latitude).
	local az_orb is arcsin ( cos(inc) / cos(ship:latitude)).
	if (inc < 0) {
		set az_orb to 180 - az_orb.
	}
	
	// create desired orbit velocity vector
	local V_star is heading(az_orb, 0)*v(0, 0, V_orb).

	// find horizontal component of current orbital velocity vector
	local V_ship_h is ship:velocity:orbit - vdot(ship:velocity:orbit, up:vector)*up:vector.
	
	// calculate difference between desired orbital vector and current (this is the direction we go)
	local V_corr is V_star - V_ship_h.
	
	// project the velocity correction vector onto north and east directions
	local vel_n is vdot(V_corr, ship:north:vector).
	local vel_e is vdot(V_corr, heading(90,0):vector).
	
	// calculate compass heading
	local az_corr is arctan2(vel_e, vel_n).
	return az_corr.

}// End of Function

function ff_ETAToPlane {
	PARAMETER tgt, orb_lan, 
  	i, is_AN is True, 
	  ship_lat is ship:latitude, 
	  ship_lng is Ship:Longitude.//South to North if ascending_node is TRUE, North to South if it is FALSE
	
	Print ship_lat.
	Print i.
	Print TAN(ship_lat).
	Print TAN(i).

	LOCAL rel_lng IS ARCSIN(TAN(ship_lat)/TAN(i)).
    IF NOT is_AN { SET rel_lng TO 180 - rel_lng. }
    LOCAL g_lan IS hf_mAngle(orb_lan + rel_lng - tgt:ROTATIONANGLE).
    LOCAL node_angle IS hf_mAngle(g_lan - ship_lng).
	SET r_eta TO (node_angle / 360) * tgt:ROTATIONPERIOD.
	//Print "ETA " + r_eta.
  	RETURN r_eta.
}

function hf_normalvector{
	parameter ves.
	Local vel is velocityat(ves,time:seconds):orbit.
	Local norm is vcrs(vel,ves:up:vector). 
	return norm:normalized.// gives vector pointing towards centre of body from ship
}

///////////////////////////Lift Off Start up /////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


//Pre IGM parameters
Global f10 is -22.6858.
Global f11 is 3.1212744023.
Global f12 is -0.1596859743.
Global f13 is 0.0034734047.
Global f14 is -0.0000303768.

Global f20 is -12.7889096425.
Global f21 is 1.1572357155.
Global f22 is -0.0370373199.
Global f23 is 0.0003100451.
Global f24 is -0.0000009124.

Global f30 is 267.8272438978.
Global f31 is -10.4559319501.
Global f32 is 0.1425603089.
Global f33 is -0.0009251725.
Global f34 is 0.0000022968.

Global f40 is -241.4732279128.
Global f41 is 7.4940917776.
Global f42 is -0.098022488.
Global f43 is 0.0005266595.
Global f44 is -0.0000010266.

Global tS1 is 35.0.
Global tS2 is 80.0.
Global tS3 is 115.0.
Global dtf is 0.

If runmode = 0{
	Wait 1. //Alow Variables to be set and Stabilise pre launch
	PRINT "Prelaunch.".
	warpto (EngineStartTime -25).
	Lock Throttle to f_f1_thrust().
	Set config:IPU to 1000.

	//SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 1.

	Print "Mission start".
	Print ship:mass.
	Print ship:drymass.

	// Apollo 11 72.058 azimuth heading
	//Set sv_intAzimith to 72.058. 
	Set basetime to time:seconds + 18.

	//Ignition starts 8.9 seconds prior to lift off.
	wait until Time:seconds > (basetime-8.9).   
	Print "Starting engines".
	Local MaxEngineThrust is 0. 
	Global englist is List().
	Local RO_Engine_offset is 0. //2.32 seconds for 1.3.1 to allow for RO engine startup delay compared to real engines

	LIST ENGINES IN engList. //Get List of Engines in the vessel
	//no5 -6.4
	wait until Time:seconds > (basetime-(6.4+RO_Engine_offset)).   
	FOR eng IN engList { 
	IF eng:TAG ="F1-C" { 
		eng:activate.
		SET MaxEngineThrust TO MaxEngineThrust + eng:MAXTHRUST. 
		Print "F1-C: Active".  
	}
	}
	//no1/3 -6.1
	wait until Time:seconds > (basetime-(6.1+RO_Engine_offset)). 
	FOR eng IN engList { 
	IF eng:TAG ="F1-1" or eng:TAG ="F1-3" { 
		eng:activate.
		SET MaxEngineThrust TO MaxEngineThrust + eng:MAXTHRUST. 
		Print "F1-1/3: Active".  
	}
	}
	//no4/2 -6.0/-5.9
	wait until Time:seconds > (basetime-(6.0+RO_Engine_offset)). 
	FOR eng IN engList { 
	IF eng:TAG ="F1-4" or eng:TAG ="F1-2" { 
		eng:activate.
		SET MaxEngineThrust TO MaxEngineThrust + eng:MAXTHRUST. 
		Print "F1-2/4: Active".  
	}
	}
	STAGE. // Engine stage as activate doesn't stage
	Print "Checking thrust ok".
	Print f_f1_thrust().
	Local CurrEngineThrust is 0.
	Local EngineStartFalied is False.
	Local EngineStartTime is TIME:SECONDS.
	until CurrEngineThrust > 0.95*MaxEngineThrust{ 
	Set CurrEngineThrust to 0.
	FOR eng IN engList { 
		IF eng:TAG ="F1-4" or eng:TAG ="F1-2" or eng:TAG ="F1-1" or eng:TAG ="F1-3" or eng:TAG ="F1-C"{ 
			SET CurrEngineThrust TO CurrEngineThrust + eng:THRUST. 
		}
	}
	//Print CurrEngineThrust.

	if Time:seconds > (basetime-0.0) {
		Print time:seconds.
		Lock Throttle to 0.
		Set SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
		Print "Engine Start up Failed...Making Safe".
		Shutdown. //ends the script
	}
	}
	//all thrust ok -1.6
	Print "Thrust ok: " + (basetime - time:seconds).
	Print f_f1_thrust().
	Print time:seconds.

	Global INU_Zero is r(up:pitch,up:yaw,facing:roll) + r(0,0,sv_intAzimith-90).
	Print INU_Zero.

	//LOCK STEERING TO r(up:pitch,up:yaw,facing:roll). 
	Global Base_alt is alt:radar.

	Wait until TIME:SECONDS > basetime.
	Global liftoff is time:seconds.
	Print "T0: " + liftoff.
	Print ship:mass.
	Print ship:drymass.
	//0.3 first lift off arms released
	wait until Time:seconds > (liftoff + 0.3). 
	STAGE. // Relase Clamps
	Print "Lift off!! " + (time:seconds - liftoff).
	Print ship:mass.
	Print ship:drymass.
	Print f_f1_thrust().
	//0.6 umbilical disconnect
	wait until Time:seconds > (liftoff + 0.6). 
	Print "Umbilical disconect " + (time:seconds - liftoff).

	f_Pre_IGM(sv_intAzimith).

	//tilt arrest occurs at the end of the loop (160 s for apollo)
	// Use the below if needed but the PRE IGT should hole the ptich at the last pitch position updated as it exits
	//Set sV to ship:facing:forevector.
	//lock steering to lookdirup( sV, ship:facing:topvector ).
	Print "Tilt Arrest Enabled "+ (time:seconds - liftoff).

	//MECO Staging 161.63
	Wait UNTIL (time:seconds > (liftoff + 161.63)).
	Lock Throttle to 1.
	FOR eng IN engList { 
		IF eng:TAG ="F1-4" or eng:TAG ="F1-2" or eng:TAG ="F1-1" or eng:TAG ="F1-3" or eng:TAG ="F1-C"{ 
			eng:shutdown. 
		}
	}
	Print "MECO:"+(TIME:SECONDS).
	Print "Speed: " + SHIP:AIRSPEED.
	Print "Altitude: " + altitude.
	Print ship:mass.
	Print ship:drymass.

	//162.1 Ullage motors
	Wait UNTIL time:seconds > (liftoff + 162.1).
	Stage.
	//162.3 retro motor fire (already build into MECO satge)
	Wait UNTIL time:seconds > (liftoff + 162.3).
	wait until stage:ready.
	Stage. // release S-IC
	//163.0 S-II engine start
	Wait UNTIL time:seconds > (liftoff + 163.0).
	wait until stage:ready.
	Stage.
	Print "Second Stage Ignition".
	Print ship:mass.
	Print ship:drymass.

	f_Orbit_Steer().
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
	Local englist is List().
	local startTime is time:seconds + nextnode:eta - (ff_Burn_Time(nextnode:deltaV:mag/2, 426, 880, 1)).
	Print (ff_Burn_Time(nextnode:deltaV:mag/2, 426, 880, 1)).
	wait 1.
	///wait for pre mnv setup
	until time:seconds > (startTime -120){
		wait 1.
	}
	Print "Mnv set up".
	RCS on.
	SAS on.
	unlock steering.
	wait 1.
	Set SASMODE to "MANEUVER".
	//wait for ullage
	until time:seconds > (startTime -20){
		wait 1.
	}
	Print "Ullage Start".
	FOR eng IN engList { 
		IF eng:TAG ="APS" { 
			eng:activate.
		}
	}
	lock Throttle to 1.
	SAS off.
	lock steering to nextnode:burnvector.
	///move to J2 and stop ullage
	until time:seconds > (startTime -10){
		wait 1.
	}
	Print "Engine Start".
	FOR eng IN engList { 
		IF eng:TAG ="APS" { 
			eng:shutdown.
		}
	}
	LIST ENGINES IN engList. //Get List of Engines in the vessel
	FOR eng IN engList { 
		IF eng:TAG ="J-2F" { 
			eng:activate.
		}
	}
	wait 0.1.
	Print "EMR setup".
	FOR eng IN engList { 
		IF eng:TAG ="J-2F" { 
			Local M is eng:GETMODULE("EMRController").
			Print M:GETFIELD("current EMR").
			M:SETFIELD("current EMR",4.5).
		}
	}
	///move MRS at 116 seconds in
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
	until hf_isManeuverComplete(nextnode) {
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
	wait 30.
	Shutdown.
}

wait 2.
Print "Stage Finshed".
Shutdown. //ends the script
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function f_Pre_IGM {
Parameter Az.

    Local Xy is 0.
    Local Xz is 0.
    Local Xx is 0.

	local t1 is 13.0.
	local t2 is 25.0.
	local t3 is 36.0.
	local t4 is 45.0.
	local t5 is 81.0.
	local t6 is 0.0.

	Local dTTf is 1.
	Local I is 0.
	Local Majorloop is 0.

	local tAR is 153.0.//153 for early version but 160 used for the tilt arrest on apollo 11 and onwards
	Print "Pre-IGM running".
	UNTIL time:seconds > (liftoff + tAR){ //until tilt arrest for the set path.
		Set tc to (time:seconds - liftoff).
		If (tc - Majorloop) > dTTf {
			Set Majorloop to tc.
			//Print "Major loop:" + (tc - Majorloop).
		}

		if 1.0 > tc and (I = 0){ 
			LOCK STEERING TO r(up:pitch,up:yaw,facing:roll). ///point stright up
			Set I to I+1.
		}
		If (tc < t1) or (alt:radar < (137 + Base_alt)){
				f_Yaw_Man(Tc).
		}
	// Clear tower yaw manuever // 1.7		
		If (time:seconds > (liftoff + 1.7)) and (I = 1){
			//LOCK STEERING TO HEADING(0, 88.75).//1.25 degree yaw at 1 degree per second
			Print "Yaw program start" + (time:seconds - liftoff).
			Print f_f1_thrust().
			Set I to I+1.
		}

	// end yaw program 9.7
		If (time:seconds > (liftoff + 9.7)) and (I = 2){
			Print "Yaw program end " + (time:seconds - liftoff).
			LOCK STEERING TO HEADING(0, 90).//ramped back to 0 degree yaw slowly
			///point in current direction
			// Set sV to ship:facing:forevector.
			// lock steering to lookdirup(sV, ship:facing:topvector).
			Set I to I+1.
		}

	// //Pitch and roll program commences at 13.2 seconds
		If (time:seconds > (liftoff + 13.2)) and (I = 3){
			Print "Pitch and roll program start" + (time:seconds - liftoff).
			Set I to I+1.
		}

	///Not used but should be to determine a flight profile for an engine out scenario
		If (tc <= t2){
			If (tc <= t6){
				//zero time locked at launch with engine out
			}
		}

	/// Actual pitch and roll program taking through to first stage seperation
		If (tc <= tAR)and (I > 3){ 
			f_Pre_IGM_Steer(tc).//set steering path
			//Or use the following version if just want to follow the prograde vector
			//lock pitch to 90 - VANG(SHIP:UP:VECTOR, SHIP:VELOCITY:SURFACE).
			//LOCK STEERING TO heading(sv_intAzimith, pitch) .
		}

	// ourboard engine CANT 20.6
		/// unable to code in KOS

	// end roll program 31.1
		If (time:seconds > (liftoff + 31.1)) and (I = 4){
			Print "End roll program " + (time:seconds - liftoff).
			SET STEERINGMANAGER:MAXSTOPPINGTIME TO 1.
			Set I to I+1.
		}
	//The following are checks against the reality	
		// mach 1 66.3
		If (time:seconds > (liftoff + 66.3)) and (I = 5){
			Print "Mach 1 " + (time:seconds - liftoff).
			Print "Speed: " + SHIP:AIRSPEED.
			Print "Altitude: " + altitude.
			Print f_f1_thrust().
			Set I to I+1.
		}
		// Max Q at 83
		If (time:seconds > (liftoff + 83)) and (I = 6){
			Print "Max Q " + (time:seconds - liftoff).
			Print "Max Q: " + SHIP:Q.
			Print "Speed: " + SHIP:AIRSPEED.
			Print "Altitude: " + altitude.
			Print ship:mass.
			Print ship:drymass.
			Print f_f1_thrust().
			Set I to I+1.
		}
		//inboard engine cutoff 135.2
		If (time:seconds > (liftoff + 135.2)) and (I = 7){
			FOR eng IN engList { 
				IF eng:TAG ="F1-C" { 
					eng:shutdown.
				}
			}
			Print "Centre shutdown " + (time:seconds - liftoff).
			Print "Speed: " + SHIP:AIRSPEED.
			Print "Altitude: " + altitude.
			Print ship:mass.
			Print ship:drymass.
			Print f_f1_thrust().
			Set I to I+1.
		}
		wait 0.1.
	} //end loop
}//End Pre-IGM phase


function f_Yaw_Man{
Parameter tc.
    if 1.0 > tc { LOCK STEERING to INU_Zero + r(0, 0, 90-sv_intAzimith). }.
    if (1.0 <= Tc) and (tc < 8.75) { 
		LOCK STEERING to (INU_Zero + r(1.25, 0, 90-sv_intAzimith)). 
		Set SteeringManager:MAXSTOPPINGTIME to 1.	
	}.
    if 8.75 <=tc { 
		LOCK STEERING to INU_Zero + r(0, 0, 90-sv_intAzimith). 
		Set SteeringManager:MAXSTOPPINGTIME to 1.
	}.
}

function f_Pre_IGM_Steer{
Parameter tc.
	local Xy is 0.
	//If dtf = 0 { Set dtf to tc.}//fix up for engine out freeze.
	Local dtcf is (tc-dtf).//tc is time from liftoff dtf is period of frozen Xy 

    If dTcf < ts1{ Set Xy to f_Pitch_Man(f10, f11, f12, f13, f14, dtcf).}
    If (ts1 <= dtcf) and (dtcf < ts2){ Set Xy to f_Pitch_Man(f20, f21, f22, f23, f24, dtcf).}
    If (ts2 <= dtcf) and (dtcf < ts3){ Set Xy to f_Pitch_Man(f30, f31, f32, f33, f34, dtcf).}
    If ts3 <= dtcf { Set Xy to f_Pitch_Man(f40, f41, f42, f43, f44, dtcf).}
	//LOCK STEERING to INU_Zero + r(0, Xy, 0).
	LOCK STEERING to Heading(sv_intAzimith, 90 + Xy).
	//Print "IGM: " + Xy.
	//Print "dtf:" + dtf.
	//Print "dtcf:" + dtcf.
}

function f_pitch_Man {
Parameter val0, val1, val2, val3, val4, dtcf.
    Return val0 + (val1*dtcf) + (val2*(dtcf^2))+(val3*(dtcf^3))+ (val4*(dtcf^4)).
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function f_Orbit_Steer{
//Used for second stage taking into account the third "end" stage
/////////////////////////////////////////////////////////////////////////////////////
// Credits: Own modifications to:
// http://www.orbiterwiki.org/wiki/Powered_Explicit_Guidance
//With Large assisstance and corrections from:
// https://github.com/Noiredd/PEGAS
// https://ntrs.nasa.gov/archive/nasa/casi.ntrs.nasa.gov/19660006073.pdf
// https://amyparent.com/post/automating-rocket-launches/

	//local tgt_pe is 191100. //target periapsis
	//local tgt_ap is 191100. //target apoapsis
	//local tgt_inc is 32.521. //target inclination

	local u is 0. //Target true anomoly
	local HSL is 8. // 8 was 15

	Local T3 is 143.
	local mass_flow3 is 214.
	local start_mass3 is 166571.
	local s_Ve3 is 4205.
	local tau3 is 777.//777.

	local T2 is 56. // add 8 for transition time //base 50
	local mass_flow2 is 727.
	local s_Ve2 is 4198.
	Local start_mass2 is (213888 + (mass_flow2*T2)). //213888
	local tau2 is 347.//347.
	local T2_end is 548.

	local T1 is 321. // add 20 for transition time //base 301
	local mass_flow1 is 1239.
	local s_Ve1 is 4169.23.
	local tau1 is 667.
	local T1_2 is 38. //base 38
	local T1_end is 498.

	local Thrust3 is s_Ve3 * mass_flow3.
	local Thrust2 is s_Ve2 * mass_flow2.

//starting peg variables
    local A1 is -0.3.//starting peg variable
    local B1 is 0. //starting peg variable
    local C1 is 0.1. //starting peg variable

    local A2 is -0.15. //starting peg variable
    local B2 is 0. //starting peg variable
    local C2 is 0.1. //starting peg variable

	local A3 is 0. //starting peg variable
    local B3 is 0. //starting peg variable
    local C3 is 0.1. //starting peg variable

    local converged is 1. // used by convergence checker
    local delta is 0. //time between peg loops
	local peg_step is 1.0.//time between each calcuation check
	local A is 0.
	local B is 0.
	local C is 0.
	local s_pitch is 20.

	local dA1 is 0.
	local dA2 is 0.
	local dB1 is 0.
	local dB2 is 0.

	//values setup
    set ra to body:radius + tgt_ap. //full Ap
    set rp to body:radius + tgt_pe. //full pe
    local sma is (ra+rp)/2. //sma
    local ecc is (ra-rp)/(ra+rp). //eccentricity
    local vp is sqrt((2*body:mu*ra)/(rp*2*sma)). // this is the target velocity at the periapsis
	if u = 0 {
    	set tgt_vy to 0. // this is the split of the target velocity at the point in time
    	set tgt_vx to vp. // this is the split of the target velocity at the point in time (should be zero for u = 0)
		set rc to rp. // this is the target radius based on the desire true anomoly
	}else{
		set rc to (sma*(1-ecc^2))/(1+ecc*cos(u)). // this is the target radius based on the desire true anomoly
    	local vc is sqrt((vp^2) + 2*body:mu*((1/rc)-(1/rp))). // this is the target velocity at the target radius (if u is zero this will equal vp)
    	local uc is 90 - arcsin((rp*vp)/(rc*vc)). // this is the direction vector of the target velocity
    	set tgt_vy to vc*sin(uc). // this is the split of the target velocity at the point in time
    	set tgt_vx to vc*cos(uc). // this is the split of the target velocity at the point in time (should be zero for u = 0)
	}

    // Define target position and velocities

	local tgt_r is rc.
    Local tgt_h is vcrs(v(tgt_r, 0, 0), v(tgt_vy, tgt_vx, 0)):mag. // target angular momentum. This is the velocity represented as energy at a point made up of the x and y components.
	Local tgt_w is sqrt((tgt_vx^2) + (tgt_vy^2)) / (tgt_r).

	Local I is 0.
	Local J is 0.
	local tau_lock is false.

	//192.3 seperate aft interstage
	UNTIL time:seconds > (liftoff + 192.3){
		wait 0.1.
	}
	Stage.
	Print "S-II aft interstage release".
	Print ship:mass.
	Print ship:drymass.
	//197.9 LET release
	UNTIL time:seconds > (liftoff + 197.9){
		wait 0.1.
	}
	Stage.
	Print "S-LET release".
	Print ship:mass.
	Print ship:drymass.
	SET STEERINGMANAGER:MAXSTOPPINGTIME TO 0.10.

    local rTcur is (time:seconds - liftoff).
	local last is (time:seconds - liftoff).
	local lastM is (time:seconds - liftoff).
    local s_r is ship:orbit:body:distance.
	local s_acc is ship:AVAILABLETHRUST/ship:mass.
	local s_vy is ship:verticalspeed.
	local s_vx is sqrt(ship:velocity:orbit:sqrmagnitude - ship:verticalspeed^2).
	local w is s_vx / s_r.
	local s_ve is f_Vel_Exhaust().
	local tau is s_ve/s_acc. //time to burn ship if all propellant
	local w_T1 is w*1.01. //first guess at tgt_w which is actually the current w plus 1%.
	local rT1 is s_r + ((tgt_r-s_r)*0.75). //first guess at rT1
	local w_T2 is w_T1*1.01. 
	local rT2 is s_r + ((tgt_r-s_r)*0.9). //first guess at rT2
	local w_T3 is w_T2*1.01. 
	local rT3 is tgt_r. //first guess at rT3
	local hT1 is tgt_h *0.98.
	local hT2 is tgt_h *0.99.
	local hT3 is tgt_h.

	Clearscreen.
	Print "IGM Phase 1" AT (0,1).
    Print "Mode: IGM Convergence loop" AT (0,2).
	local loop_break to false.
	//Loop through updating the parameters until the break condition is met
    until false {

		//Collect updated time periods
        set rTcur to (time:seconds - liftoff).
		Set DeltaM to rTcur - LastM. // time since last major (outside) calc loop
		set delta to rTcur - last. // time since last minor (inside) calculation loop
		set LastM to rTcur. // reset last major calculation
		set A to A + (B*DeltaM).

		// collect current ship parameters
        set s_r to ship:orbit:body:distance.
		set s_acc to ship:AVAILABLETHRUST/ship:mass.
		set s_vy to ship:verticalspeed.
		set s_vx to sqrt(ship:velocity:orbit:sqrmagnitude - ship:verticalspeed^2).
		set w to s_vx / s_r.
		Local h is vcrs(v(s_r, 0, 0), v(s_vy, s_vx, 0)):mag. 

		If tau_lock = false{
			set s_ve to f_Vel_Exhaust().
			Set tau to s_ve/s_acc.
		} else{
			Set tau to 300.
		}

		if T1> 0 and (tau_lock = false){
			Print "IGM Phase 1" AT (0,1).
			Set T1 to T1 - DeltaM.
			Set A1 to A1 + (B1 * DeltaM).
			if T1 < 3 { 
				Set tau_lock to true.
			}Else{
				set s_Ve1 to s_ve.
				set tau1 to tau.
			}
		}

		if (T2> 0) and (T1 = 0) and (tau_lock = false){
			Print "IGM Phase 2" AT (0,1).
			Set T2 to T2 - DeltaM.
			Set A2 to A2 + (B2 * DeltaM).
			if T2 < 3 {
				Set tau_lock to true.
			}Else{
				set s_Ve2 to s_ve.
				set tau2 to tau.
			}
		}

		if T3> 0 and (T2 = 0) and (tau_lock = false){
			Print "IGM Phase 3" AT (0,1).
			Set T3 to T3 - DeltaM.
			Set A3 to A3 + (B3 * DeltaM).
			set s_Ve3 to s_ve.
			set tau3 to tau.
		}
		//Print "Pitch hold enabled".
		//204.1 IGM phase 1 (Iterative guidance mode)
		until (time:seconds > (liftoff + 204.1)){
			// pitch hold until this time
			//set peg_step to 1.0.
			f_clearLine(4).			
			Print "Mode: Pitch hold enabled" AT (0,4).
			Print "Speed: " + SHIP:AIRSPEED AT (0,5).
			Print "Altitude: " + altitude AT (0,6).
			f_clearLine(7).
			Print "Mass: " +ship:mass AT (0,7).
			f_clearLine(8).
			Print "Dry Mass: " +ship:drymass AT (0,8).
			wait 0.01.
		}

		if (time:seconds < (liftoff + 460.6)) and (I = 0){
			f_clearLine(2).
			Print "Mode: Calculating" AT (0,2).
		}
		// if (time:seconds < (liftoff + 450)) and (time:seconds > (liftoff + 204.1)){
		// 	set peg_step to 2.
		// 	Print "Peg 2".
		// } 
		
		// if (time:seconds < (liftoff + 600)) and (time:seconds > (liftoff + 450)){
		// 	set peg_step to 1.
		// 	Print "Peg 3".
		// } 

		//460.6 Centre engine cutout
		if (time:seconds > (liftoff + 460.6)) and (I = 0){
			Local englist is List().
			LIST ENGINES IN engList.
			FOR eng IN engList { 
				IF eng:TAG ="J-2C" { 
					eng:shutdown.
				}
			}
			//Print "Centre shutdown " + (time:seconds - liftoff).
			Print "Action time:" + (time:seconds - liftoff) AT (0,3).
			f_clearLine(4).
			Print "Action: CECO" AT (0,4).
			Print "Speed: " + SHIP:AIRSPEED AT (0,5).
			Print "Altitude: " + altitude AT (0,6).
			f_clearLine(7).
			Print "Mass: " +ship:mass AT (0,7).
			f_clearLine(8).
			Print "Dry Mass: " +ship:drymass AT (0,8).
			Set I to I+1.
			Set T1 to T1_2.
			//Print "Peg 3".
			//Set T1_end to 494. //one off increase to allow for the centre engine shutdown
		}

		// 494.4 IGM phase 2 and tau mode
		if (time:seconds > (liftoff + 494.4)) and (I = 1){
			f_clearLine(2).
			Print "Mode: Tau Locked" AT (0,2).
			f_clearLine(4).			
			Print "Action: Tau locking" AT (0,4).
			Print "Speed: " + SHIP:AIRSPEED AT (0,5).
			Print "Altitude: " + altitude AT (0,6).
			f_clearLine(7).
			Print "Mass: " +ship:mass AT (0,7).
			f_clearLine(8).
			Print "Dry Mass: " +ship:drymass AT (0,8).
			Set tau_lock to true.
			Set I to I+1.
			Set T1 to 0. //end phase 1
		}

		//498 High(5.5) to low MRS(4.34) command 
		if (time:seconds > (liftoff + 498)) and (I = 2){
			LIST ENGINES IN engList.
			FOR eng IN engList { 
				IF eng:TAG ="J-2" { 
					Local M is eng:GETMODULE("EMRController").
					M:DOAction("change EMR mode", true).
				}
			}
			//Print "Mixture Ratio Shift" + (time:seconds - liftoff).
			//f_clearLine(2).
			Print "Action time:" + (time:seconds - liftoff) AT (0,3).
			f_clearLine(4).			
			Print "Action: MRS" AT (0,4).
			Print "Speed: " + SHIP:AIRSPEED AT (0,5).
			Print "Altitude: " + altitude AT (0,6).
			f_clearLine(7).
			Print "Mass: " +ship:mass AT (0,7).
			f_clearLine(8).
			Print "Dry Mass: " +ship:drymass AT (0,8).
			Set I to I+1.
		}
		// 504.2 end tau mode
		if (time:seconds > (liftoff + 504.2)) and (I = 3){
			//f_clearLine(1).
			//Print "IGM Phase 2" AT (0,1).
			f_clearLine(2).
			Print "Mode: Calculating" AT (0,2).
			f_clearLine(4).			
			Print "Action: Tau unlocking" AT (0,4).
			Print "Speed: " + SHIP:AIRSPEED AT (0,5).
			Print "Altitude: " + altitude AT (0,6).
			f_clearLine(7).
			Print "Mass: " +ship:mass AT (0,7).
			f_clearLine(8).
			Print "Dry Mass: " +ship:drymass AT (0,8).
			Set tau_lock to false.
			Set I to I+1.

		}

		// 548.22 engine cutout and IGM phase 3
		if (time:seconds > (liftoff + 548.22)) and (I = 4){
			Set T2 to 0. //end phase 2
			FOR eng IN engList { 
				IF eng:IGNITION ="true"{ 
					eng:shutdown. 
				}
			}
			Print "Action time:" + (time:seconds - liftoff) AT (0,3).
			f_clearLine(4).			
			Print "Action: SECO" AT (0,4).
			Print "Speed: " + SHIP:AIRSPEED AT (0,5).
			Print "Altitude: " + altitude AT (0,6).
			f_clearLine(7).
			Print "Mass: " +ship:mass AT (0,7).
			f_clearLine(8).
			Print "Dry Mass: " +ship:drymass AT (0,8).
			// 548.9 ullage motors
			Wait UNTIL time:seconds > (liftoff + 548.9).
			//Print "ullage".
			wait until stage:ready.
			Stage.
			//549.0 seperation
			Wait UNTIL time:seconds > (liftoff + 549.0).
			//Print "Seperation".
			wait until stage:ready.
			Stage.
			//549.2 engine start
			Wait UNTIL time:seconds > (liftoff + 549.2).
			//Print "Engine".
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
					M:SETFIELD("current EMR",4.93).
					M:DOEvent("Show EMR Controller").
				}
			}
			Set I to I+1.
			SET STEERINGMANAGER:MAXSTOPPINGTIME TO 1.
		}////

		//555.6 tau mode

		//561.0 ullage case jettison

		//562.4 end of tau mode

		//665.2 begin terminal guidance (chi-tilde mode, drops the altitude in A and rate term in B at this point and only works off C to counteract gravity)

		//691.6 begin chi freeze end Phase 3
		if (time:seconds > (liftoff + 691.6)) and (I = 5){
			//HSL active
			Print "Action time:" + (time:seconds - liftoff) AT (0,3).
			f_clearLine(4).
			Print "Action: Chi Freeze" AT (0,4).
			Print "Speed: " + SHIP:AIRSPEED AT (0,5).
			Print "Altitude: " + altitude AT (0,6).
			f_clearLine(7).
			Print "Mass: " +ship:mass AT (0,7).
			f_clearLine(8).
			Print "Dry Mass: " +ship:drymass AT (0,8).
			Set I to I+1.
		}

		//699.34 ECO command
		if ((time:seconds > (liftoff + 709.34)) or (ship:velocity:orbit:mag > (tgt_vx-1) ) )and (I = 6){
			FOR eng IN engList { 
				IF eng:TAG ="J-2F" { 
					eng:shutdown.
				}
			}
			Print "Action time:" + (time:seconds - liftoff) AT (0,3).
			f_clearLine(4).
			Print "Action: ECO" AT (0,4).
			Print "Speed: " + SHIP:AIRSPEED AT (0,5).
			Print "Altitude: " + altitude AT (0,6).
			f_clearLine(7).
			Print "Mass: " +ship:mass AT (0,7).
			f_clearLine(8).
			Print "Dry Mass: " +ship:drymass AT (0,8).
			Set I to I+1.
			set peg_step to 1000.
			wait 0.5.
		}

		//699.8 APS ullage command
		if (time:seconds > (liftoff + 699.34)) and (I = 7){
			f_clearLine(1).
			Print "APS Phase Time" AT (0,1).
			f_clearLine(2).
			Print "Orbit correction" AT (0,2).
			FOR eng IN engList { 
				IF eng:TAG ="APS" { 
					eng:activate.
				}
			}
			Set I to I+1.
		}
		//709.34 Orbit instertion

		//719.3 horitzontal move to
		if (time:seconds > (liftoff + 719.3)) and (I = 8){
			//786.5 ullage engine turn off
			//0.00021 was eccentricity
			until ship:orbit:eccentricity < 0.00021 or time:seconds > (liftoff + 796.5){
				f_clearLine(10).
				Print "Refine orbit" AT (0,10).
				Print time:seconds - liftoff AT (0,13).
				wait 0.001.
			}
			FOR eng IN engList { 
				IF eng:TAG ="APS" { 
					eng:shutdown.
				}
			}
			RCS off.
			lock Throttle to 0.
			f_clearLine(2).
			Print "Orbit Insertion" AT (0,2).
			break.
		}
		
		//speed based cutoff process
		if  (T3 < HSL) and (T2 = 0){ //and (tau_lock = true)
			f_clearLine(1).
			Print "APS Phase Speed" AT (0,1).
			f_clearLine(2).
			Print "Orbit correction" AT (0,2).
			Until false{
				set s_vx to sqrt(ship:velocity:orbit:sqrmagnitude - ship:verticalspeed^2).
				Print time:seconds - liftoff AT (0,13).
				if (tgt_vx -2) < s_vx{
					lock Throttle to 0.
					RCS on.
					FOR eng IN engList { 
						IF eng:TAG ="APS" { 
							eng:activate.
						}
					}		
					SET SHIP:CONTROL:FORE TO 1.0.
					Local track is time:seconds.
					until (ship:orbit:eccentricity < 0.0001) or (ship:periapsis > tgt_pe) or (tgt_vx < s_vx) or (time:seconds > track + 30){
						wait 0.01.
						set s_vx to sqrt(ship:velocity:orbit:sqrmagnitude - ship:verticalspeed^2).
						f_clearLine(10).
						Print "Refine orbit" AT (0,10).
					}
					SET SHIP:CONTROL:FORE TO 0.0.
					FOR eng IN engList { 
						IF eng:TAG ="APS" { 
							eng:shutdown.
						}
					}
					RCS off.
					f_clearLine(2).
					Print "Orbit Insertion" AT (0,2).
					Set loop_break to true.
					break.
				}
				Print tgt_vx.
				Print s_vx.
				wait 0.001.
			}
		}


		//////////PEG loop//////////////////////
    	If (delta >= peg_step) and (tau_lock = false) {  // this is used to ensure a minimum time step occurs before undertaking the next peg cycle calculations
			Set last to (time:seconds - liftoff).//reset last
			/// determine peg states
			local peg_solved is f_PEG(A1, B1, T1, rT1, hT1, w_T1, s_ve1, tau1, tgt_vy, tgt_vx, tgt_r, tgt_w, mass_flow1,  
										A2, B2, T2, rT2, hT2, w_T2, s_ve2, tau2, start_mass2, mass_flow2, Thrust2,
										A3, B3, T3, rT3, hT3, w_T3, s_ve3, tau3, start_mass3, mass_flow3, Thrust3,
										dA1, dA2, dB1, dB2).

			set A1 to peg_solved[0].
			set B1 to peg_solved[1].
			set T1_new to peg_solved[2].
			set rT1 to peg_solved[3].
			set hT1 to peg_solved[4].
			set w_T1_new to peg_solved[5].

			set A2 to peg_solved[6].
			set B2 to peg_solved[7].
			set T2_new to peg_solved[8].
			set rT2 to peg_solved[9].
			set hT2 to peg_solved[10].
			set w_T2_new to peg_solved[11].

			set A3 to peg_solved[12].
			set B3 to peg_solved[13].
			set T3_new to peg_solved[14].
			set rT3 to peg_solved[15].
			set hT3 to peg_solved[16].
			set w_T3_new to peg_solved[17].

			set dA1 to peg_solved[18].
			set dA2 to peg_solved[19].
			set dB1 to peg_solved[20].
			set dB2 to peg_solved[21].

			//local tgt_vy1 is 73.66.
			//local tgt_vx1 is 6918.6.
			//local tgt_r1 is 6559612.

		
			if T1 >0 {
				set w_T1 to w_T1_new.
				set w_T2 to w_T2_new.
				set w_T3 to w_T3_new.
				set T3 to T3_new.
				set A to A1.
				set B to B1.
				Print "Closed Loop Guidanace Enabled T1:" + T1 AT (0,10).
			} 

			if (T2> 0)  and (T1 = 0){
				set w_T2 to w_T2_new.
				set w_T3 to w_T3_new.
				set T3 to T3_new.
				set A to A2.
				set B to B2.
				Print "Closed Loop Guidanace Enabled T2:" + T2 AT (0,10).
			}
			if T3> 0 and (T2 = 0){

				if(T3_new <= HSL) { // HSL check time to go is above (8 seconds is apollo 11 e3 value see para 4.1.7), below this the solution starts to become very sensitive and A and B should not longer be re-calculated
					f_clearLine(10).
					Print "Terminal guidance enabled" AT (0,10). 
					set converged to -5.
					set T3_new to 0.
					Set peg_step to 1000.
				} Else{
					Print "Closed Loop Guidanace Enabled T3:" + T3 AT (0,10).
					set A to A3.
					set B to B3.
				}
				Set T3 to T3_new.
				set w_T3 to w_T3_new.
			}			
		}

		If loop_break = true {
			Break.// exit loop
		}
		set C to ((body:mu/(s_r^2)) - ((w^2)*s_r))/s_acc.	
		set s_pitch to A + C. //sin pitch at current time.
		set s_pitch to max(-0.707, min(s_pitch, 0.707)). // limit the pitch change to between -45 and 45 degress
		Set s_pitch to arcsin(s_pitch). //covert into degress

		//Print A.
		//Print B.
		//Print C.
		//Print w.
		//Print s_acc.
		//Print peg_step.

		if (converged = 1) and (time:seconds > (liftoff + 204.1)) and (time:seconds < (liftoff + 665)){
			//LOCK STEERING TO heading(f_FlightAzimuth(tgt_inc, tgt_vx), s_pitch).
			LOCK STEERING TO heading(sv_intAzimith, s_pitch).
		} 
		Print "S pitch: " + s_pitch AT (0,11).
		Print tgt_inc AT (0,12).
		Print time:seconds - liftoff AT (0,13).

	}//end of loop

} // end of function
	

function f_PEG {
    parameter A1.
    parameter B1.
    parameter T1.
	parameter rT1.
	parameter hT1.
	parameter w_T1. 
	parameter s_ve1.
	parameter tau1.
	parameter tgt_vy. // orbit "target" vertical velocity
	parameter tgt_vx. // orbit "target" horizontal velocity
	parameter tgt_r. // orbit "target" radius
	parameter tgt_w.
	parameter mass_flow1 is 0.

    parameter A2 is 0.
    parameter B2 is 0.
    parameter T2 is 0.
	parameter rT2 is 0.
	parameter hT2 is 0.
	parameter w_T2 is 0. 
	parameter s_ve2 is 0.
	parameter tau2 is 1.
	parameter start_mass2 is 0.
	parameter mass_flow2 is 0.
	parameter Thrust2 is 0.

	parameter A3 is 0.
    parameter B3 is 0.
    parameter T3 is 0.
	parameter rT3 is 0.
	parameter hT3 is 0.
	parameter w_T3 is 0. 
	parameter s_ve3 is 0.
	parameter tau3 is 1.
	parameter start_mass3 is 0.
	parameter mass_flow3 is 0.
	parameter Thrust3 is 0.

	parameter dA1 is 0.
	parameter dA2 is 0.
	parameter dB1 is 0.
	parameter dB2 is 0.

	// read current stage and position values

	local s_vy is ship:verticalspeed.
	local s_vx is sqrt(ship:velocity:orbit:sqrmagnitude - ship:verticalspeed^2).
	local s_r is ship:orbit:body:distance.
	local s_acc is ship:AVAILABLETHRUST/ship:mass. // current ship parameter
	local w is s_vx /s_r.
	//local w is sqrt((s_vx^2) + (s_vy^2)) / (s_r).
	local h0 is vcrs(v(s_r, 0, 0), v(s_vy, s_vx, 0)):mag. //current angular momentum
	Local tgt_h is vcrs(v(tgt_r, 0, 0), v(tgt_vy, tgt_vx, 0)):mag. //target angular momentum

	local s_acc_2 is 0.
	local s_acc_3 is 0.

	local s_acc_end_1 is 0.
	local s_acc_end_2 is 0.
	local s_acc_end_3 is 0.

	local rdotT2 is 0.
	local rdotT3 is 0.
	local A is 0.
	local B is 0.


	if T1 > 0{
		Set A to A1.
		Set B to B1.
	}
	if (T2 > 0) and (T1 = 0){
		Set A to A2.
		Set B to B2.
		Set rT1 to s_r.
	}
	if (T2 = 0) and (T1 = 0){
		Set A to A3.
		Set B to B3.
		Set rT2 to s_r.
	}

	/// determine bn and cn stages

	local L1 is f_bcn(s_ve1, tau1, T1).

	local bb01 is L1[0].
	local bb11 is L1[1].
	local bb21 is L1[2].
	local cc01 is L1[3].
	local cc11 is L1[4].
	local cc21 is L1[5].

	local L2 is f_bcn(s_ve2, tau2, T2).

	local bb02 is L2[0].
	local bb12 is L2[1].
	local bb22 is L2[2].
	local cc02 is L2[3].
	local cc12 is L2[4].
	local cc22 is L2[5].

	local L3 is f_bcn(s_ve3, tau3, T3).

	local bb03 is L3[0].
	local bb13 is L3[1].
	local bb23 is L3[2].
	local cc03 is L3[3].
	local cc13 is L3[4].
	local cc23 is L3[5].

	// Print "Checks check:".
	// Print "bb01: " + bb01.
	// Print "bb11: " + bb11.
	// Print "s_r: "+s_r.
	// Print "s_vy: " + s_vy.
	// Print "tgt_r: "+tgt_r.
	Print "T1: " + T1.
	Print "A1: " + A1.
	Print "B1: " + B1.
	Print "rT1: " + rT1.
	Print "dA1: " + dA1.
	Print "dB1: " + dB1.
	Print "T2: " + T2.
	Print "A2: " + A2.
	Print "B2: " + B2.
	Print "rT2: " + rT2.
	Print "dA2: " + dA2.
	Print "dB2: " + dB2.
	Print "T3: " + T3.
	Print "A3: " + A3.
	Print "B3: " + B3.
	Print "rT3: " + rT3.
	// Print "Height: "+ (rT1 - body:radius).
	// Print "(s_vy*T1)" + (s_vy*T1).
	// Print "(cc01 * A1)" + (cc01 * A1).
	// Print "(cc11*B1)" + (cc11*B1).
	// Print "combined: " + ((s_vy*T1)+(cc01 * A1)+(cc11*B1)).


	//get future stage parameters
	//T3 parameters
	set s_acc_3 to Thrust3/start_mass3.
	set s_acc_end_3 to Thrust3/ (start_mass3 -((mass_flow3)*T3)).

	//J= 4 l=3, k=2, i=1
	set rdotT3 to s_vy.
	set rdotT3 to rdotT3 + (bb03+bb02+bb01)*A.
	set rdotT3 to rdotT3 + ( (bb13 + (bb03*(T2+T1))) + (bb12 + (bb02*T1)) + (bb11 + (bb01*0)) )*B.   //vertical speed at staging
	set rdotT3 to rdotT3 + ((bb03*dA2) + (bb03*(T2)*dB1) + (bb13*dB2)) + ((bb02*dA1) + (bb02*T1*0) + (bb12*dB1)) + ((bb01*0) + (bb01*0*0) + (bb11*0)).
	// Print "Calc rdotT3 check " + rdotT3.
	set rdotT3 to tgt_vy.
	
	//J=4 l=3, k=2, i=1, m=0
	set rT3 to s_r + (s_vy*(T1+T2+T3)). 
	set rT3 to rT3 + ( (cc03 + (T3*(bb01+bb02))) + (cc02 + (T2*bb01)) + (cc01 + (T1*0)) )*A.
	set rT3 to rT3 + ( cc13 + cc12 + cc11 + (cc03*T2 + bb12*T3 + bb02*T3*T1) + (cc03*T1) + (bb11*T3) + ((bb01*T3)*0) + (cc02*T1 + bb11*T2 + bb01*T2*0) + (cc01*0 + 0*T1 + 0*T1*0)  )*B.
	set rT3 to rT3 + ((cc03*dA2) + (cc13*dB2) + (cc02*dA1) + (cc12*dB1)).
	set rT3 to rT3 + (bb02*T3*dA1 + bb02*T1*T3*0 + bb12*T3*dB1 + cc03*T2*dB1).
	set rT3 to rT3 + (bb01*T3*dA1) + (bb01*T1*T3*0) + (bb11*T3*dB1) + (cc03*T1*dB1).//l=3, k=1, i=1, m=0
	// Print "Calc RT3 check " + rT3.
	set rT3 to tgt_r.
	
	// Print "rdotT3: "+rdotT3.
	// Print "rT3: "+ rT3.

	//apply boundaries on results
	//if rT3 > tgt_r{ Set rT3 to tgt_r.}
	//if rT3 < rT2 {Set rT3 to rT2.}

	Local L6 is f_end_cond(w_T2, rT2, s_acc_3, w_T3, rT3, s_acc_end_3, T3, A3, B3). 
	local ft_3 is L6[0].
	local ftdot_3 is L6[1].
	local ftdd_3 is L6[2].
	//local dh_T3 to ((rT2 + rT3)/2)*( (ft_3*bb03) + (ftdot_3*bb13) + (ftdd_2*bb23) ).
	//Set hT3 to dh_T3 + hT2.
	local dh_T3 is tgt_h - hT2. //angular momentum to gain in final stage
	//Set hT3 to dh_T3 + hT2.
	Local hT3 is tgt_h.
	//local v0_T3 is hT3/rT3.
	local v0_T3 is tgt_vx.
	//Print L6.
	//print "v0_T3 " + v0_T3.
	local rT3 is tgt_r.
	//Print "rT3" + rT3.
	//Set w_T3 to sqrt((v0_T3^2) - (rdotT3^2))/rT3.
	Set w_T3 to tgt_w.

	set mean_r to (rT3 + rT2)/2.
	local dv_T3 is dh_T3/mean_r.
	if (dv_T3 < 5) and (T1 > 0) {Set dv_T3 to 5.}
	Set T3 to tau3*(1 - constant:e ^ (-dv_T3/s_ve3)).

	if T3 <0 {Set T3 to 2.}
	//Print "dv gain T2 to Orbit: " + dv_T3.

	//T2 parameters
	set s_acc_2 to Thrust2/start_mass2.
	set s_acc_end_2 to Thrust2/ (start_mass2 -((mass_flow2)*T2)).

	//J= 3 l=2, k=1, i=0
	set rdotT2 to s_vy.
	set rdotT2 to rdotT2 + (bb02+bb01)*A.
	set rdotT2 to rdotT2 + ( (bb12 + (bb02*T1)) + (bb11 + (bb01*0)) )*B.   //vertical speed at staging
	set rdotT2 to rdotT2 + ((bb02*dA1) + (bb02*T1*0) + (bb12*dB1)) + ((bb01*0) + (bb01*0*0) + (bb11*0)).
	//Print "Calc rdotT2 check " + rdotT2.
	
	//J=3 l=2, k=1, i=0
	set rT2 to s_r + (s_vy*(T1+T2)). 
	set rT2 to rT2 + ( (cc02 + (T2*bb01)) + (cc01 + (T1*0)) )*A.
	set rT2 to rT2 + ( cc12 + cc11 + (cc02*T1 + bb11*T2 + bb01*T2*0) + (cc01*0 + 0*T1 + 0*T1*0)  )*B.
	set rT2 to rT2 + ( (cc02*dA1) + (cc12*dB1) + (cc01*0) + (cc11*0)  ).
	set rT2 to rT2 + (bb01*T2*0 + bb01*0*T2*0 + bb11*T2*0 + cc02*T1*0).
	//Print "Calc RT2 check " + rT2.

	//apply boundaries on results
	//if rT2 > tgt_r{ Set rT2 to tgt_r.}
	//if rT2 < rT1 { Set rT2 to rT1.}

	Local L5 is f_end_cond(w_T1, rT1, s_acc_2, w_T2, rT2, s_acc_end_2, T2, A2, B2). 
	local ft_2 is L5[0].
	local ftdot_2 is L5[1].
	local ftdd_2 is L5[2].
	local dh_T2 to ((rT1 + rT2)/2)*( (ft_2*bb02) + (ftdot_2*bb12) + (ftdd_2*bb22) ).
	Set hT2 to dh_T2 + hT1.
	local v0_T2 is hT2/rT2.
	//contraint on V0_T1 to less than remaining stage dv
	//Print "v0_T2 (1): " + v0_T2.
	// if V0_T2 > (bb02 + V0_T1){
	// 	set V0_T2 to (bb02 + V0_T1).
	// 	set hT2 to V0_T2*rT2.
	// }
	// if V0_T2 < (V0_T1){
	// 	set V0_T2 to (V0_T1).
	// 	set hT2 to V0_T2*rT2.
	// }
	//Print L5.
	//print "v0_T2 " + v0_T2.
	//print "rT2" + rT2.
	Set w_T2 to sqrt((v0_T2^2) - (rdotT2^2))/rT2.

	set mean_r to (rT2 + rT1)/2.
	local dv_gain is dh_T2/mean_r.
	//Print "dv gain to T1 to T2: " + dv_gain.

	if T3 = 0{ // if only two stage to orbit
		Set T2 to tau2*(1 - constant:e ^ (-dv_gain/s_ve2)).
		//set T2 boundaries
		if T2 <0 {Set T2 to 2.}
	}

	//T1 parameters
	set s_acc_end_1 to ship:AVAILABLETHRUST/ (ship:mass - ((mass_flow1/1000)*T1)).// 1000 used here as mass returned in tonnes due to weight
	//Print s_acc_end_1.

	//J= 2 l=1, k=0, i=0
	set rdotT1 to s_vy.
	set rdotT1 to rdotT1 + (bb01)*A.
	set rdotT1 to rdotT1 + ( (bb11 + (bb01*0)) )*B.   //vertical speed at staging
	set rdotT1 to rdotT1 + ((bb01*0) + (bb01*0*0) + (bb11*0)).
	//Print "Calc rdotT1 check " + rdotT1.
	
	//J= 2 l=1, k=0, i=0
	set rT1 to s_r + (s_vy*(T1)). 
	set rT1 to rT1 + ( (cc01 + (T1*0)) )*A.
	set rT1 to rT1 + ( cc11 + (cc01*0 + 0*T1 + 0*T1*0)  )*B.
	set rT1 to rT1 + ( (cc01*0) + (cc11*0) ).
	// Print "Calc RT1 check " + rT1.
	// Print "Change rDot3: " + (bb03*A3 + bb13*B3).
	// Print "Change r3: " + (rdotT2*T3) + cc03*A3 + cc12*B3.
	// Print "Change rDot2: " + (bb02*A2 + bb12*B2).
	// Print "Change r2: " + (rdotT1*T2) + cc02*A2 + cc12*B2.
	// Print "Change rDot1: " + (bb01*A1 + bb11*B1).
	// Print "Change r1: " + (s_vy*T1) + cc01*A1 + cc11*B1.

	//apply boundaries on results
	//if rT1 > tgt_r {Set rT1 to tgt_r-30000.}
	//if rT1 < s_r {Set rT1 to s_r.}

	local L4 is f_end_cond(w, s_r, s_acc, w_T1, rT1, s_acc_end_1, T1, A1, B1). 
	local ft_1 is L4[0].
	local ftdot_1 is L4[1].
	local ftdd_1 is L4[2].
	local dh_T1 to ((s_r + rT1)/2)*( (ft_1*bb01) + (ftdot_1*bb11) + (ftdd_1*bb21) ).
	Set hT1 to dh_T1 + h0.
	local v0_T1 is hT1/rT1.
	//contraint on V0_T1 to less than remaining stage dv
	//Print "v0_T1 (1): " + v0_T1.
	//Print dh_T1 /rT1.
	// if V0_T1 > (bb01 + sqrt(s_vx^2 + s_vy^2)){
	// 	set V0_T1 to (bb01 + sqrt(s_vx^2 + s_vy^2)).
	// 	set hT1 to V0_T1*rT1.
	// }
	//Print tau1. 
	//Print "T1: " + T1.
	//Print L1.
	//Print L4.
	//Print "v0_T1: " + v0_T1.
	//Print "rT1: " + rT1.
	Set w_T1 to sqrt((v0_T1^2) - (rdotT1^2))/rT1.

	set mean_r to (s_r + rT1)/2.
	local dv_gain is dh_T1/mean_r.
	//Print "dv gain to T1: " + dv_gain.

	if T2 = 0 { // if only single stage to orbit
		Set T1 to tau1*(1 - constant:e ^ (-dv_gain/s_ve1)).
	}

	//Guidance staging discontinuities

	If (T2>0) and (T1>0){

		set dA1 to ( (body:mu/(rT1^2)) - ((w_T1^2)*rT1) ).
		set dA1 to dA1 * ( (1/s_acc_end_1) - (1/s_acc_2) ).

		set dB1 to - ( (body:mu/(rT1^2)) - ((w_T1^2)*rT1) ) * ( (1/s_ve1) - (1/s_ve2)  ). 
		set dB1 to dB1 + ( ( (3*(w_T1^2)) - ((2*body:mu)/(rT1^3)) ) *rdotT1* ( (1/s_acc_end_1) - (1/s_acc_2) )  ).

		/// Determine A2 and B2

		set A2 to A1 + (dA1 + (B1*T1)). //Aj = A1 + sum dA(l) + B1*T(l) + T(l)*sum(dB(l)) (from l=1 to j-1)
		set B2 to B1 + dB1. //Bj = B1 + sum dB(l) (from l=1 to j-1)
		
		If T3>0{

			set dA2 to ( (body:mu/(rT2^2)) - ((w_T2^2)*rT2) ).
			set dA2 to dA2 * ( (1/s_acc_end_2) - (1/s_acc_3) ).

			set dB2 to - ( (body:mu/(rT2^2)) - ((w_T2^2)*rT2) ) * ( (1/s_ve2) - (1/s_ve3)  ). 
			set dB2 to dB2 + ( ( (3*(w_T2^2)) - ((2*body:mu)/(rT2^3)) ) *rdotT2* ( (1/s_acc_end_2) - (1/s_acc_3) )  ).

			/// Determine A3 and B3

			set A3 to A1 + (dA1 + (B1*T1)) + (dA2 + (B1*T2)) + (T2*dB1). //Aj = A1 + sum dA(l) + B1*T(l) + T(l)*sum(dB(l)) (from l=1 to j-1)
			set B3 to B1 + dB1 + dB2. //Bj = B1 + sum dB(l) (from l=1 to j-1)
		
		}
	}

	If (T2>0) and (T1=0){
		Set dA1 to 0.
		Set dB1 to 0.

		set dA2 to ( (body:mu/(rT2^2)) - ((w_T2^2)*rT2) ).
		set dA2 to dA2 * ( (1/s_acc_end_2) - (1/s_acc_3) ).

		set dB2 to - ( (body:mu/(rT2^2)) - ((w_T2^2)*rT2) ) * ( (1/s_ve2) - (1/s_ve3)  ). 
		set dB2 to dB2 + ( ( (3*(w_T2^2)) - ((2*body:mu)/(rT2^3)) ) *rdotT2* ( (1/s_acc_end_2) - (1/s_acc) )  ).

		/// Determine A3 and B3

		set A3 to A2 + (dA2 + (B2*T2)). 
		set B3 to B3 + dB2.
		
	}

	If (T2=0) and (T1=0){
		Set dA1 to 0.
		Set dB1 to 0.

		Set dA2 to 0.
		Set dB2 to 0.
	}

	//set up matricies
	//for rDot A/////
	local mA11 is bb01 + bb02 + bb03. 

	//for rDot B////
	//l=3, k=2
	Local mA12 is bb13 + (bb03*(T1+T2)). 
	//l=2, k=1 
	set mA12 to mA12 + bb12 + (bb02*T1).
	//l=1
	set mA12 to mA12 + bb11.

	//for r A/////
	//l=3, k=2,1
	local mA21 is cc03 + ((bb02+bb01)*T3). 
	//l=2, k=1 
	set mA21 to mA21 + cc02 + (bb01*T2).
	//l=1, k=0 
	set mA21 to mA21 + cc01.

	//for r B/////
	//l=3, k=1 i=1 
	local mA22 is cc13 + (cc03*T2) + (bb12*T3) + ((bb02*T3)*T1).
	// sub l=3, k=1 i=0 
		set mA22 to mA22 + (cc03*T1) + (bb11*T3) + ((bb01*T3)*0).
	//l=2, k=1, i=0 
	set mA22 to mA22 + cc12 + (cc02*T1) + (bb11*T2) +((bb01*T2)*0).
	// sub l=2, k=0 i=0 
		set mA22 to mA22 + (cc02*0) + (0*T2) + ((0*T2)*0).
	//l=1, k=0, i=0 
	set mA22 to mA22 + cc11. 


	//for rdot final/////
	local mC1 is tgt_vy - s_vy. 
	//l=3, k=2 i=1
	set mC1 to mC1 - (bb03*dA2) - (bb03*(T2)*dB1) - (bb13*dB2). 
	//l=2, k=1, i=0
	set mC1 to mC1 - (bb02*dA1) - (bb02*T1*0) - (bb12*dB1). 
	//l=1, k=0, i=0
	set mC1 to mC1 - (bb01*0) - (bb01*0*0) - (bb11*0). 

	
	//for r final/////
	local mC2 is tgt_r - s_r - (s_vy*(T1+T2+T3)).
	//l=3, k=2, i=1, m=0
	set mC2 to mC2 - (cc03*dA2) - (cc13*dB2) - (bb02*T3*dA1) - (bb02*T1*T3*0) - (bb12*T3*dB1) - (cc03*T2*dB1).
	// Sub l=3, k=1, i=1, m=0
		set mC2 to mC2 - (bb01*T3*dA1) - (bb01*T1*T3*0) - (bb11*T3*dB1) - (cc03*T1*dB1).
	// Sub l=3, k=2, i=0, m=0
		set mC2 to mC2 - (bb02*T3*0) - (bb02*0*T3*0) - (bb12*T3*0) - (cc03*T2*0).
	//l=2, k=1, i=0, m=0
	set mC2 to mC2 - (cc02*dA1) - (cc12*dB1) - (bb01 *T2 *0) - (bb01*0*T2*0) - (bb11*T2*0) - (cc02*T1*0). 
	// Sub l=2, k=0, i=0, m=0
		set mC2 to mC2 - (0*T2*0) - (0*0*T2*0) - (0*T2*0) - (cc02*0*0).
	//l=1, k=0, i=0, m=0
	set mC2 to mC2 - (cc01*0) - (cc11*0) - 0. 

	local peg is f_peg_solve(mA11, mA12, mA21, mA22, mC1, mC2).

	if T1 > 0{
		Set A1 to peg[0].
		Set B1 to peg[1].
		// Print "A1 peg"+ A1. 
		// Print "B1 peg" + B1.
	}
	if (T2 > 0) and (T1 = 0){
		Set A2 to peg[0].
		Set B2 to peg[1].
		// Print "A2 peg"+ A2. 
		// Print "B2 peg" + B2.
	}
	if (T2 = 0) and (T1 = 0){
		Set A3 to peg[0].
		Set B3 to peg[1].
		// Print "A3 peg"+ A3. 
		// Print "B3 peg" + B3.
	}
	// Print "Accel " + s_acc.
	// Print s_acc_2.
	// Print s_acc_3.
	// Print s_acc_end_1.
	// Print s_acc_end_2.
	// Print s_acc_end_3.

	Return list(A1, B1,	T1, rT1, hT1, w_T1, A2, B2, T2, rT2, hT2, w_T2, A3, B3, T3, rT3, hT3, w_T3, dA1, dA2, dB1, dB2). 
}

///////////////////////////////////////////////////////////////////////////////////
function f_bcn{
	parameter s_ve.
	parameter tau.
	parameter T.

	local bb0 is -s_ve*(LN(1-(T/tau))).
	//J1
	local bb1 is (bb0 * tau) - (s_ve*T).
	//P1
	local bb2 is (bb1 * tau) - ((s_ve*(T^2))/2).
	//S1
	local cc0 is (bb0*T)-bb1.
	//Q1
	local cc1 is (cc0*tau) - ((s_ve*(T^2))/2).
	//U1
	local cc2 is (cc1*tau) - ((s_ve*(T^3))/6).

	return list(bb0, bb1, bb2, cc0, cc1, cc2).
}
Function f_end_cond{
	parameter start_w.
	parameter start_r.
	parameter start_acc.
	parameter end_w.
	parameter end_r.
	parameter end_acc.
	parameter T_time.
	parameter A.
	parameter B. 

	if T_Time = 0{
		Set T_Time to 1. // prevent divide by zero error.
	}

	//Current pitch guidance for horizontal state
	Set C to ((body:mu/(start_r^2)) - ((start_w^2)*start_r))/start_acc. //start portion of vehicle acceleration used to counteract gravity
	local fr is A + C. //sin pitch at start
	local C_end is (body:mu/(end_r^2)) - ((end_w^2)*end_r). //Gravity and centrifugal force term at cutoff
	Set C_end to C_end /end_acc. 
	Set frT to A + (B*T_time) + C_end. //sin pitch at burnout. 
	local frdot is (frT-fr)/T_time. //approximate rate of sin pitch
	local ft is 1 - (frT^2)/2. //cos pitch
	local ftdot is -fr*frdot. //cos pitch speed
	local ftdd is -(frdot^2)/2. //cos pitch acceleration
	
	return list (ft, ftdot, ftdd). 
}
///////////////////////////////////////////////////////////////////////////////////
// Estimate, returns A and B coefficient for guidance
function f_peg_solve {
    parameter mA11.
	parameter mA12. 
	parameter mA21. 
	parameter mA22. 
	parameter mC1. 
	parameter mC2.

	//solve matrix
	local d is 1/((mA11*mA22) - (mA12*mA21)). // inverse coefficent
	//inverse matrix
	local dmA11 is d*mA22.
	local dmA12 is d*-1*mA12.
	local dmA21 is d*-1*mA21.
	local dmA22 is d*mA11.
	//Multiple inverse matrix by result matrix
	local A is dmA11*mC1 + dmA12*mC2.
	local B is dmA21*mC1 + dmA22*mC2.

    return list(A, B).
}


function f_FlightAzimuth {
	parameter inc. // target inclination
    parameter V_orb. // target orbital speed
  
	// project desired orbit onto surface heading
	local az_orb is arcsin ( cos(inc) / cos(ship:latitude)).
	if (inc < 0) {
		set az_orb to 180 - az_orb.
	}
	
	// create desired orbit velocity vector
	local V_star is heading(az_orb, 0)*v(0, 0, V_orb).

	// find horizontal component of current orbital velocity vector
	local V_ship_h is ship:velocity:orbit - vdot(ship:velocity:orbit, up:vector)*up:vector.
	
	// calculate difference between desired orbital vector and current (this is the direction we go)
	local V_corr is V_star - V_ship_h.
	
	// project the velocity correction vector onto north and east directions
	local vel_n is vdot(V_corr, ship:north:vector).
	local vel_e is vdot(V_corr, heading(90,0):vector).
	
	// calculate compass heading
	local az_corr is arctan2(vel_e, vel_n).
	return az_corr.

}// End of Function

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function f_clearLine {
	parameter line.
	local i is 0.
	local s is "".
	until i = terminal:width {
		set s to " " + s.
		set i to i + 1.
	}
	print s at (0,line).
}

function f_f1_thrust {
	return 1.
	//return max(0.001,((ship:AVAILABLETHRUST/(ship:mass*9.81))-1.20)/1.8).//3.0 to 1.20 TWR range // was 2.6 to 1.2
}

function ff_burn_time {
parameter dV, isp is 0, thrust is 0, engine_count is 0. // For RSS/RO engine values must be given unless they are actually burning.
lock throttle to 0.
Print "Burntime".
	local g is 9.80665.  // Gravitational acceleration constant used in game for Isp Calculation (m/s²)
	local m is ship:mass * 1000. // Starting mass (kg)
	local e is constant():e. // Base of natural log
	
	//TODO: look at comapring the dv with the ff_stage_delta_v. If less look at the engine in the next stage and determine the delta_v and time to burn until the dv has been meet.
	If engine_count = 0{ // only evaluate is figures not given
		list engines in all_engines.
		for en in all_engines {
			if en:ignition and not en:flameout {
				set thrust to thrust + en:availablethrust.
				set isp to isp + en:isp.
				set engine_count to engine_count + 1.
			}
		}
	}
	if engine_count = 0{
		return 1. //return something to prevent error.
	}
	set isp to isp / engine_count. //assumes only one type of engine in cluster
	set thrust to thrust * 1000. // Engine Thrust (kg * m/s²)
	Print isp.
	Print Thrust.
	return g * m * isp * (1 - e^(-dV/(g*isp))) / thrust.
}/// End Function

function f_Vel_Exhaust {
	local g is 9.80665.  // Gravitational acceleration constant used in game for Isp Calculation (m/s²)
	local engine_count is 0.
	local thrust is 0.
	local isp is 0. // Engine ISP (s)
	list engines in all_engines.
	for en in all_engines if en:ignition and not en:flameout {
	  set thrust to thrust + en:availablethrust.
	  set isp to isp + en:isp.
	  set engine_count to engine_count + 1.
	}
	set isp to isp / engine_count.
	return g *isp.///thrust). //
}/// End Function

function f_mdot {
	local g is 9.80665.  // Gravitational acceleration constant used in game for Isp Calculation (m/s²)
	local engine_count is 0.
	local thrust is 0.
	local isp is 0. // Engine ISP (s)
	list engines in all_engines.
	for en in all_engines if en:ignition and not en:flameout {
	  set thrust to thrust + en:availablethrust.
	  set isp to isp + en:isp.
	  set engine_count to engine_count + 1.
	}
	set isp to isp / engine_count.
	set thrust to thrust* 1000.// Engine Thrust (kg * m/s²)
	return (thrust/(g * isp)). //kg of change
}/// End Function

function f_Tol {
//Calculates if within tolerance and returns true or false
	PARAMETER a. //current value
	PARAMETER b.  /// Setpoint
	PARAMETER tol.

	RETURN (a - tol < b) AND (a + tol > b).
}
FUNCTION hf_mAngle{
PARAMETER a.
  UNTIL a >= 0 { SET a TO a + 360. }
  RETURN MOD(a,360).
  
}

function hf_isManeuverComplete {
	parameter mnv.
	if not(defined originalVector) or originalVector = -1 {
		declare global originalVector to mnv:burnvector.
	}
	if vang(originalVector, mnv:burnvector) > 45 {
		declare global originalVector to -1.
		return true.
	}
	return false.
}

// global backlog is list().
// function entry {
// 	parameter s.
// 	backlog:add(s).
// 	console_backlog().
// }
// function console_backlog {
	
// 	local emptyLine is "                                                  ".
// 	local maxLines is terminal:height - bd. //where bd is the line above where the log will appear in the UI
// 	local counter is 1.
// 	local i is backlog:length - 1.
// 	until counter > maxLines or counter > backlog:length {
// 		print emptyLine at (0,bd+counter+1). //clear the line
// 		print backlog[i] at (0,bd+counter+1).
// 		set counter to counter + 1.
// 		set i to i - 1.
// 	}
// }