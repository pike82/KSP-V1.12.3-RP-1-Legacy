CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
SET TERMINAL:HEIGHT TO 65.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:BRIGHTNESS TO 0.8.
SET TERMINAL:CHARHEIGHT TO 10.
SET CONFIG:IPU to 150.

///preset trim values
global up_trim is -30. // m/s when to stick only upright on landing-30
global leg_trim is 200. // height to deploy legs
global stop_trim is 0. // target distance below surface to force landing (noramlly negative for underground but plus for drone ships).20
global dist_trim is 1000. // dist from landing to target margin in which can stop boost back.
Global radarOffset is -45.	 // The value of alt:radar when landed (on gear)
Global grndOffset is 0. //Distance above the ground of the landing spot (ie. bulding).
Global EngineStartTime is TIME:SECONDS.
Global Start_mass is ship:mass.
Print "Wet:" + ship:wetmass.

//Global gl_TargetLatLng is SHIP:GEOPOSITION.
//Print SHIP:GEOPOSITION.
//Print (90 - vectorangle(ship:up:forevector, ship:facing:forevector)).

//RTLS co-ords
//Global gl_TargetLatLng is latlng(28.52, -80.52). // Landing Pad Coords/
//Global gl_TargetLatLng is latlng(28.6083886236549, -80.5997508056089). // Exact Landing Pad Coords
// Global gl_TargetLatLng is latlng(28.6083886236549, -80.5982). // Next to Landing Pad Coords
//Global gl_TargetLatLng is latlng(28.6083895, -80.60527). // VAB Landing Pad Coords
Global gl_TargetLatLng is latlng(28.613, -80.60527). // VAB Landing Pad Coords(changed 608 to 619)


//Glide slope paths
lock mapDistH to ((ship:altitude^2)*0.000008)+(ship:altitude*0.1)+1000.
lock mapDistM to ((ship:altitude^2)*0.00002)+(ship:altitude*0.02)+100.
lock mapDistL to ((ship:altitude^2)*0.000005)+(ship:altitude*0.1)+0.

//AOA limits
Global gl_AOA_Low1 is 25. //RTLS low alt
Global gl_AOA_Low2 is 15. //ASDS low alt

//Target Offsets
Global RTLS_off is 5. //RTLS low alt
Global ASDS_off is 25. //ASDS low alt

// Get Booster Values
Print core:tag.
local wndw is gui(300).
set wndw:x to 400. //window start position
set wndw:y to 120.

Print "v1.0".
local label is wndw:ADDLABEL("Enter Booster Values").
set label:STYLE:ALIGN TO "CENTER".
set label:STYLE:HSTRETCH TO True. // Fill horizontally
Print gl_TargetLatLng.
				
local box_azi is wndw:addhlayout().
	local azi_label is box_azi:addlabel("Heading").
	local azivalue is box_azi:ADDTEXTFIELD("90").
	set azivalue:style:width to 100.
	set azivalue:style:height to 18.

local box_pitch is wndw:addhlayout().
	local pitch_label is box_pitch:addlabel("Start Pitch").
	local pitchvalue is box_pitch:ADDTEXTFIELD("87.5"). // For RTLS max as ASDS use 87.2
	set pitchvalue:style:width to 100.
	set pitchvalue:style:height to 18.

local box_RTLS is wndw:addhlayout().
	local RTLS_label is box_RTLS:addlabel("RTLS"). //NROL-76 and CRS 11 provides first stage RTLS telem
	local RTLSvalue is box_RTLS:ADDTEXTFIELD("True").
	set RTLSvalue:style:width to 100.
	set RTLSvalue:style:height to 18.

local box_RTLSMax is wndw:addhlayout().
	local RTLSMax_label is box_RTLSMax:addlabel("RTLSMax"). //NROL-76 and CRS 11 provides first stage RTLS telem
	local RTLSMaxvalue is box_RTLSMax:ADDTEXTFIELD("False").
	set RTLSMaxvalue:style:width to 100.
	set RTLSMaxvalue:style:height to 18.

local box_runmode is wndw:addhlayout().
	local runmode_label is box_runmode:addlabel("Runmode"). //NROL-76 and CRS 11 provides first stage RTLS telem
	local runmodevalue is box_runmode:ADDTEXTFIELD("0").
	set runmodevalue:style:width to 100.
	set runmodevalue:style:height to 18.

local somebutton is wndw:addbutton("Confirm").
set somebutton:onclick to Continue@.

// Show the GUI.
wndw:SHOW().
LOCAL isDone IS FALSE.
UNTIL isDone {
	WAIT 1.
}

////Main Code

Function Continue {
		set val to azivalue:text.
		set val to val:tonumber(0).
		Global sv_intAzimith is val.

		set val to pitchvalue:text.
		set val to val:tonumber(0).
		Global sv_anglePitchover is val.

		set val to RTLSvalue:text.
		Global sv_RTLS is val.
		
		set val to RTLSMaxvalue:text.
		Global sv_RTLSMax is val.

		set val to runmodevalue:text.
		set val to val:tonumber(0).
		Global Runmode is val.

	wndw:hide().
  	set isDone to true.
}
Print "Start Heading: " + sv_intAzimith.
Print "Start Pitch: " + sv_anglePitchover. 
Global sv_ClearanceHeight is 130. //tower clearance height

//Set up drone ship Co-ordinates
if sv_RTLS = true{
	// do nothing
}Else{
	SET TARGET TO "ASDS".
	Set gl_TargetLatLng to target:GEOPOSITION.
	Print "gl_TargetLatLng" + target:GEOPOSITION.
}
Print "Geo Targets".

Global gl_TargetLatLngSafe is ff_GeoConv(3,90,gl_TargetLatLng:lat,gl_TargetLatLng:lng). // Just short of landing pad for re entry burn
Global gl_TargetLatLngBoost is ff_GeoConv(9,90,gl_TargetLatLng:lat,gl_TargetLatLng:lng).// short of landing pad for boost back


Until Runmode = 100 {

//Prelaunch
	if runmode = 0{
		Wait 1. //Alow Variables to be set and Stabilise pre launch
		PRINT "Prelaunch.".
		SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
		Lock Throttle to 1.
		LOCK STEERING TO r(up:pitch,up:yaw,facing:roll).
		wait 1.
		Set runmode to 1.
	}


//Liftoff
	if runmode = 1{
		STAGE. //Ignite main engines
		Print "Starting engines".
		wait 0.2.
		Set EngineStartTime to TIME:SECONDS.
		Local MaxEngineThrust is 0. 
		Local englist is List().
		//List Engines.
		LIST ENGINES IN engList. //Get List of Engines in the vessel
		FOR eng IN engList {  //Loops through Engines in the Vessel
			//Print "eng:STAGE:" + eng:STAGE.
			//Print STAGE:NUMBER.
			IF eng:STAGE >= STAGE:NUMBER { //Check to see if the engine is in the current Stage
				SET MaxEngineThrust TO MaxEngineThrust + eng:MAXTHRUST. 
				//Print "Stage Full Engine Thrust:" + MaxEngineThrust. 
			}
		}
		Print "Checking thrust ok".
		Local CurrEngineThrust is 0.
		Local EngineStartFalied is False.
		until CurrEngineThrust > 0.99*MaxEngineThrust{ 
			Set CurrEngineThrust to 0.
			FOR eng IN engList {  //Loops through Engines in the Vessel
				IF eng:STAGE >= STAGE:NUMBER { //Check to see if the engine is in the current Stage
					SET CurrEngineThrust TO CurrEngineThrust + eng:THRUST. //add thrust to overall thrust
				}
			}
			if (TIME:SECONDS - EngineStartTime) > 5 {
				Lock Throttle to 0.
				Set SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
				Print "Engine Start up Failed...Making Safe".
				Shutdown. //ends the script
			}
		}
		Print "Releasing Clamps".
		STAGE. // Relase Clamps
		Global LOtime is time:seconds.
		PRINT "Lift off!!".
		local LchAlt is ALT:RADAR.

		// Clear tower
		Wait UNTIL ALT:RADAR > sv_ClearanceHeight + LchAlt.
		Wait UNTIL SHIP:Q > 0.015. 

		//Pitchover
		LOCK STEERING TO HEADING(sv_intAzimith, sv_anglePitchover).
		Wait 20.//settle pitchover
		lock pitch to 90 - VANG(SHIP:UP:VECTOR, SHIP:VELOCITY:SURFACE).
		Set runmode to 2.
	}

//Gravity turn
	if runmode = 2{
		LOCK STEERING TO heading(sv_intAzimith, pitch) .
		wait 2.
		until SHIP:Q > 0.20 {
			wait 0.1.
		}
		Print "Throttle down: " + (TIME:SECONDS - LOtime).
		Local englist is List().
		FOR eng IN engList {  
			IF eng:TAG ="1DC" { 
				set eng:THRUSTLIMIT to 70. 
				Print "Engine". 
			}
		}
		wait 15.
		until SHIP:Q < 0.3 {
			wait 0.1.
		}
		Print "Throttleup: " + (TIME:SECONDS - LOtime).
		Local englist is List().
		FOR eng IN engList {  
			IF eng:TAG ="1DC" { 
				set eng:THRUSTLIMIT to 100.  
				Print "Engine". 
			}
		}
		// MECO Shutdown time
		Set lastdist to 100000000000.
		until ship:mass < 200{ //until (Start_mass - 362) and (TIME:SECONDS - LOtime) > 148 { //RTLS time Start_mass(570) - 362 = 208
				Wait 0.1. 
			}
			If sv_RTLS = True{
				//Skip
			} Else{
				until ship:mass < 185{ //until (Start_mass - 386) and (TIME:SECONDS - LOtime) > 158 { //Drone time Start_mass(576) - 386 =190   wetmass 570 - ship mass 186 = 384
					set impactData to impact_UTs().
					set impact to ground_track(impactData["time"]).
					Set Diff to hf_geoDistance(impact,gl_TargetLatLngBoost).
					if (diff < lastdist) and (diff > dist_trim){
						Set lastdist to Diff.
					} else{
						print "exit loop change".
						Print "Wet:" + ship:wetmass.
						wait 0.25.
						break.
					}
					Wait 0.1. 
					Print diff.
				}
			}
			Print "Wet:" + ship:wetmass.
			Lock Throttle to 0.
			Print "MECO and Release: " + (TIME:SECONDS - LOtime).
			Print "Mass:"+ ship:mass.//RTLS 208 tonnes, ASDS 190 tonnes
			SET NAVMODE TO "Orbit".
			Stage.//Release first stage
			If sv_RTLS = True{
				Set runmode to 3.
				Print "Boostback Phase".
			} Else{
				Set runmode to 4.
				Print "Droneship Phase".
				Set impactData to impact_UTs().
				Print ground_track(impactData["time"]).
				Set gl_TargetLatLng to target:GEOPOSITION. // Landing Pad Coords
				Set gl_TargetLatLngSafe to target:GEOPOSITION. // Short of landing pad
				Set gl_TargetLatLngBoost to target:GEOPOSITION. // Same as above and no need to provide extra safety
			}
		RCS on.
		Local englist is List().
		LIST ENGINES IN engList. 
		FOR eng IN engList {  
			IF eng:TAG ="1DC" { 
				eng:activate. 
				//Print "Engine". 
			}
			IF eng:TAG ="1DEC" { 
				eng:shutdown. 
				//Print "Engine". 
			}
			IF eng:TAG ="1DE" { 
				eng:shutdown. 
				//Print "Engine". 
			}
		}
	}

//Boostback Setup
	if runmode = 3{
		wait 3.
		Global boost_pitch is 0.
		If ship:apoapsis > 120000{ //limit the apoapsis on boost back to make more shallow
			lock boost_pitch to (120000 -ship:apoapsis)/750.
		}Else{
			Set boost_pitch to 0.
		}
		LOCK STEERING TO HEADING(hf_mAngle(hf_geoDir(gl_TargetLatLngBoost, SHIP:GEOPOSITION)), boost_pitch).
		Set SteeringManager:PITCHTORQUEADJUST to 150.
		Set SteeringManager:YAWTORQUEADJUST to 150.
		Print hf_geoDir(gl_TargetLatLngBoost, SHIP:GEOPOSITION).
		Print gl_TargetLatLng:HEADING.
		Print hf_geoDistance(gl_TargetLatLngBoost, SHIP:GEOPOSITION).
		Print Ship:heading.
		Print Ship:bearing.
		Wait 8.
		Lock Throttle to 1.
		//SteeringManager:RESETTODEFAULT().//reset to normal RCS control
		//SteeringManager:RESETPIDS().
		Set SteeringManager:PITCHTORQUEADJUST to -50.
		Set SteeringManager:YAWTORQUEADJUST to -50.
		//Set SteeringManager:ROLLTORQUEADJUST to -1.0.
		local burn_lnt is TIME:SECONDS.
		Print "Boostback: " + (TIME:SECONDS - EngineStartTime).
		local change is false.
		local lastdist is 1000000000.
		local calc_dist is 0.
		local diff is 0.
		Wait 5.// provide enough time for booster to start flip around before igniting next engines
		
		//increase to 3 engines
		ff_outter_engine_A().
		RCS off.
		
		// provide enough time for booster to settle in direction before measuring
		wait 10.
		lock impactData to impact_UTs().
		lock impact to ground_track(impactData["time"]).
		local freectrl is true.
		until change = True {
			If ship:apoapsis < 120000{ //limit the apoapsis on boost back to make more shallow
			unlock boost_pitch.
				Set STEERING TO getSteeringBoost(gl_TargetLatLngBoost, impact).//, boost_pitch).// * ANGLEAXIS(boost_pitch,SHIP:FACING:STARVECTOR).//* v(tan(boost_pitch),0,0). //+ R(boost_pitch,0,0).
			}
			local northPole is latlng(90,0).
			local head is mod(360 - northPole:bearing,360).
			Set ground to ground_track(impactData["time"]).
			Set Diff to hf_geoDistance(ground,gl_TargetLatLngBoost).
			Print "Diff:" + Diff.
			if (diff > (60000)){
				Set lastdist to 1000000.
			}
			if (diff < (150000)) and freectrl{
				Set STEERING TO getSteeringBoost(gl_TargetLatLngBoost, impact).
			}
			if (diff < (10000)) {
				Print "Triming shutdown".
				//reduce to one engine allow more accurate shutoff
				ff_outter_engine_S().
				set freectrl to false.
			}
			if (diff < lastdist) and (diff > dist_trim){
				Set lastdist to Diff.
			} else{
				Set change to true.
				print "exit loop change".
				break.
			}
			if (diff < (dist_trim)) {
				Set change to true.
				print "exit loop dist".
				break.
			}	
			
			//The following ensures the target spot is not will not be burnt passed.
			if (head > 315) and (head < 45){// check for north quarter
				if ground:lat > gl_TargetLatLngBoost:lat{
					print "exit loop lat".
					print ground:lat.
					print gl_TargetLatLngBoost:lat.
					Break.
				}
			}
			if (head > 45) and (head < 135){// check for east quarter
				if ground:lng > gl_TargetLatLngBoost:lng{
					print "exit loop lng".
					print ground:lng.
					print gl_TargetLatLngBoost:lng.
					Break.
				}
			}
			if (head > 135) and (head < 225){// check for south quarter
				if ground:lat < gl_TargetLatLngBoost:lat{
					print "exit loop lat".
					print ground:lat.
					print gl_TargetLatLngBoost:lat.
					Break.
				}
			}
			if (head > 225) and (head < 315){// check for west quarter
				if ground:lng < gl_TargetLatLngBoost:lng{
					Set change to true.
					print "exit loop lng".
					print ground:lng.
					print gl_TargetLatLngBoost:lng.
					break.
				}
			}
			Print head.
			Print ground:lng.
			Print gl_TargetLatLngBoost:lng.
			Print boost_pitch.
			wait 0.001.
			set vd2 to vecdraw(v(0,0,0), gl_TargetLatLngBoost:position:vec, blue, "Target", 1.0, true, 0.2).
			set vd3 to vecdraw(v(0,0,0), SHIP:GEOPOSITION:position:vec, green, "shadow", 1.0, true, 0.2).
		}
		Lock Throttle to 0.
		Set impactData to impact_UTs().
		Print ground_track(impactData["time"]).
		Print "Boostback End: " + (TIME:SECONDS - EngineStartTime).
		Print "Boost:" + hf_geoDistance(ground_track(impactData["time"]),gl_TargetLatLngBoost).
		Print "Target:" + hf_geoDistance(ground_track(impactData["time"]),gl_TargetLatLng).
		RCS on.
		wait 15.
		LOCK STEERING TO r(up:pitch,up:yaw,facing:roll).
		wait 5.
		Set runmode to 4.
	}

//Re-entry burn
	if runmode = 4{
		// Coast to re-entry
		//Big movements to orient in space
		Set SteeringManager:PITCHTORQUEADJUST to 50.
		Set SteeringManager:YAWTORQUEADJUST to 50.
		Set SteeringManager:ROLLTORQUEADJUST to 1.
		Print hf_mAngle(hf_geoDir(gl_TargetLatLngBoost, SHIP:GEOPOSITION)).
		Print gl_TargetLatLngBoost:HEADING.
		Print hf_geoDistance(gl_TargetLatLngBoost, SHIP:GEOPOSITION).
		Set impactData to impact_UTs().
		Print "Diff:" + hf_geoDistance(ground_track(impactData["time"]),gl_TargetLatLngBoost).
		//Lock movement
		set ster TO r(up:pitch,up:yaw,facing:roll).
		lock steering to ster.
		until ship:verticalspeed < -200 {
			wait 1.
		}
		Print "Re-entry prep and next safe landing point: " + (TIME:SECONDS - EngineStartTime).
		until (ship:altitude < 140000){
			wait 0.1.
		}
		Brakes on.
		Print hf_mAngle(hf_geoDir(gl_TargetLatLngSafe, SHIP:GEOPOSITION)).
		Print gl_TargetLatLngSafe:HEADING.
		Print hf_geoDistance(gl_TargetLatLngSafe, SHIP:GEOPOSITION).
		Set impactData to impact_UTs().
		Print "Safe Diff:" + hf_geoDistance(ground_track(impactData["time"]),gl_TargetLatLngSafe).
		
		//set up when the energy builds up enough to start slowing down for the entry burn, or altitude high enough to slow down and reach terminal velocity
		If sv_RTLS = True{
			set burn_stt to 0.008.//800Pa //CRS-11 50.2km and 1250 m/s at 06:10 mm:ss;
			set burn_alt to 50000.
			set burn_spd to 750.
		} Else{
			set burn_stt to 0.005. //500Pa 
			set burn_alt to 60000.
			set burn_spd to 1000.
		}
		Print "burn_stt: " + burn_stt.
		until (Ship:Q > burn_stt) or (ship:altitude < burn_alt){
			set impactData to impact_UTs().
			set impact to ground_track(impactData["time"]).
			set vd1 to vecdraw(v(0,0,0), impact:position:vec, green, "Landing", 1.0, true, 0.25).
			set vd2 to vecdraw(v(0,0,0), gl_TargetLatLngSafe:position:vec, blue, "Target", 1.0, true, 0.25).
			set impactData to impact_UTs().
			set impact to ground_track(impactData["time"]).
			lock ster to -ship:velocity:surface.
			wait 0.1.
		}
		Print ship:airspeed.
		Print ship:altitude.
		Set SteeringManager:PITCHTORQUEADJUST to 0.01. //was 1
		Set SteeringManager:YAWTORQUEADJUST to 0.01. //was 1
		Set SteeringManager:ROLLTORQUEADJUST to 0.001. //was 0.1
		set impactData to impact_UTs().
		set impact to ground_track(impactData["time"]).
		//lock ster to heading (hf_mAngle(hf_geoDir(gl_TargetLatLngBoost, SHIP:GEOPOSITION)-180), srfretrogradepitch()).//make pitch retrograde but allow heading to point to target
		Set impactData to impact_UTs().
		Print "Diff:" + hf_geoDistance(ground_track(impactData["time"]),gl_TargetLatLngSafe).
		Print "Booster entry burn:"+ (TIME:SECONDS - EngineStartTime).
		Print "Q:"+ Ship:Q.  // 0.00814 (800Pa)
		Lock Throttle to 1.
		set startburn to TIME:SECONDS.
		Print Ship:groundspeed.
		Print ship:airspeed.
		wait 3.
		
		//increase to 3 engines
		ff_outter_engine_A().
		//check for minimum conditions for stopping the entry burn
		If sv_RTLS = True and not sv_RTLSMax = True{
			set burn_stp to 34.//high as single engine burn
		} Else{
			set burn_stp to 31.5. //lower mass due to three engine stop
		}
		Until (ship:mass < burn_stp) or (ship:airspeed < burn_spd){ //check for max entry burn time, energy, or stop if not enough fuel left to land.
			set vd1 to vecdraw(v(0,0,0), impact:position:vec, green, "Landing", 1.0, true, 0.25).
			set vd2 to vecdraw(v(0,0,0), gl_TargetLatLngSafe:position:vec, blue, "Target", 1.0, true, 0.25).
			wait 0.1.
		}
		
		//reduce to one engine allow more accurate shutoff
		ff_outter_engine_S().
		wait 1.
		Print (((ship:airspeed)^3)/ship:altitude).
		Print ship:airspeed.
		Print ship:altitude.
		Print "Booster entry burn end:"+ (TIME:SECONDS - EngineStartTime).
		Print "Q:"+ Ship:Q. //0.025(2.5kPa)
		Lock throttle to 0.
		set impactData to impact_UTs().
		set impact to ground_track(impactData["time"]).
		If sv_RTLS = True{
			Set ster to getSteering(gl_AOA_Low1, gl_TargetLatLngSafe, impact).
		}else{
			Set ster to getSteering(gl_AOA_Low2, gl_TargetLatLngSafe, impact).			
		}
		lock steering to ster.
		Print gl_TargetLatLngSafe.
		Set runmode to 5.
		RCS off.
	}

//Landing Glide (no long target safe spot)
	if runmode = 5{
		SET CONFIG:IPU to 500.//increase computation
		Set SteeringManager:PITCHTORQUEADJUST to -2. //negative as we want to reduce the amount
		Set SteeringManager:YAWTORQUEADJUST to -2. //negative as we want to reduce the amount
		Set SteeringManager:ROLLTORQUEADJUST to -0.01. //negative as we want to reduce the amount
		SET aoalim to gl_AOA_Low2.
		If sv_RTLS = True and sv_RTLSMax <> True{
			Set ASDS_H to 0.
			//do nothing
		}
		Else If sv_RTLS = True and sv_RTLSMax = True{
			ff_outter_engine_A(). // set up three engine landing
		}
		Else{
			Set gl_TargetLatLng to target:GEOPOSITION. // Landing Pad Coords
			Print "gl_TargetLatLng" + target:GEOPOSITION.
			Print target.
			Set ASDS_H to gl_TargetLatLng:TERRAINHEIGHT.//Target altitude.
			Print ASDS_H.
		}

		//change to single engine landing burn
		ff_outter_engine_S().
		lock trueRadar to alt:radar + radarOffset.			// Offset radar to get distance from gear to ground
		lock g to constant:g * body:mass / body:radius^2.		// Gravity (m/s^2)
		lock pitch to 90 - vectorangle(ship:up:forevector, ship:facing:forevector).
		lock maxDecel to ((ship:availablethrust / ship:mass) - g)*(sin(pitch)).	// Maximum deceleration possible (m/s^2), the sin pitch is an offset for the current angle.
		lock stopDist to ship:verticalspeed^2 / (2 * maxDecel).		// The distance the burn will require
		lock idealThrottle to (stopDist / (trueRadar-Stop_trim)).	// Throttle required for perfect hoverslam, the stoptrim is because we want to actually land so need to target slightly under surface
		lock impactData to impact_UTs().
		lock L_impact to Last_impact(radarOffset).
		lock steering to ster.
		
		///First part of glide settings (earth rotation still counts)
		until (trueRadar < 15000) { //set at 15000 to ensure non earth rotation factor is low and seperate out big atmosphere presssure
			local mapGeo is ff_GeoConv (mapDistM/1000, sv_intAzimith, gl_TargetLatLng:lat, gl_TargetLatLng:lng). 
			If sv_RTLS = True{
				set aoalim to (1/Ship:Q)*6.//based on dynamic pressure 70 Kpa is 8.6, 20 Kpa is 30
				Set aoalim to min(hf_geoDistance(ground_track(impactData["time"]),gl_TargetLatLng)/25,aoalim).//bigger = smaller aoa
				//lock ster to getSteering(aoalim, mapGeo, SHIP:GEOPOSITION, (ship:altitude*0.95)).// new based on mappedset path adding altitude to geopostion reduce the angle.
				lock ster to getSteering(aoalim, gl_TargetLatLng, L_impact, (ship:altitude/RTLS_off)). //AOA, tgt, impact, offset height) //bigger smaller overshoot
			}Else{
				set aoalim to (1/Ship:Q)*6.//based on dynamic pressure 70 Kpa is 8.6, 20 Kpa is 30
				Set aoalim to min(hf_geoDistance(mapGeo, SHIP:GEOPOSITION)/25,aoalim).
				//lock ster to getSteering(aoalim, mapGeo, SHIP:GEOPOSITION, (ship:altitude*0.95)).// new based on mappedset path adding altitude to geopostion reduce the angle.
				lock ster to getSteering(aoalim, gl_TargetLatLng, L_impact, ((ship:altitude-ASDS_H)/ASDS_off)). //AOA, tgt, impact, offset height) //bigger smaller overshoot
			}


			Print "trueRadar: "+trueRadar.
			Print "maxDecel: "+maxDecel.
			Print ASDS_H.
			Print stopDist.
			Print idealThrottle.
			set vd1 to vecdraw(v(0,0,0), L_impact:position:vec, green, "Landing", 1.0, true, 0.2).
			set vd2 to vecdraw(v(0,0,0), gl_TargetLatLng:position:vec, blue, "Target", 1.0, true, 0.2).
			set vd3 to vecdraw(v(0,0,0), SHIP:GEOPOSITION:position:vec, green, "shadow", 1.0, true, 0.2).
			set vd4 to vecdraw(v(0,0,0), mapGeo:position:vec, green, "Map Geo", 1.0, true, 0.2).			
			//Print pitch.
			//Print sin(pitch).
			Print "aoalim:" + aoalim.
			LOG MISSIONTIME + "," + ship:altitude + "," + airSpeed + "," + Groundspeed + "," + verticalSpeed + "," + pitch + hf_geoDistance(SHIP:GEOPOSITION,gl_TargetLatLng) + "," + ship:mass + "," + ship:availableThrust TO "0:/dataoutput.csv".
			wait 0.1.
		}
		
		///Second part of glide settings (earth rotation still counts)
		until (trueRadar < 5000) { //set at 15000 to ensure non earth rotation factor is low and seperate out big atmosphere presssure
			//second glide settings just before engine ignitions	
			Set SteeringManager:PITCHTORQUEADJUST to 10. 
			Set SteeringManager:YAWTORQUEADJUST to 10. 
			Set SteeringManager:ROLLTORQUEADJUST to 1. 
			local mapGeo is ff_GeoConv (mapDistL/1000, sv_intAzimith, gl_TargetLatLng:lat, gl_TargetLatLng:lng). 
			If sv_RTLS = True{
				set aoalim to (1/Ship:Q)*6.//based on dynamic pressure 70 Kpa is 8.6, 20 Kpa is 30
				//set aoalim to sqrt(ship:altitude/1000)*5.//(ship:altitude/1000)*1.5.
				Set aoalim to min(hf_geoDistance(ground_track(impactData["time"]),gl_TargetLatLng)/25,aoalim).//bigger = smaller aoa
				//lock ster to getSteering(aoalim, mapGeo, SHIP:GEOPOSITION, (ship:altitude/2)).// new based on mappedset path adding altitude to geopostion reduce the angle.
				lock ster to getSteering(aoalim, gl_TargetLatLng, L_impact, (ship:altitude/RTLS_off)). //AOA, tgt, impact, offset height) //bigger smaller overshoot
			}Else{
				set aoalim to (1/Ship:Q)*6.//based on dynamic pressure 70 Kpa is 8.6, 20 Kpa is 30
				//set aoalim to sqrt(ship:altitude/1000)*6.//(ship:altitude/1000)*1.25.
				Set aoalim to min(hf_geoDistance(mapGeo, SHIP:GEOPOSITION)/25,aoalim).
				//lock ster to getSteering(aoalim, mapGeo, SHIP:GEOPOSITION, (ship:altitude/2)).// new based on mappedset path adding altitude to geopostion reduce the angle.
				lock ster to getSteering(aoalim, gl_TargetLatLng, L_impact, ((ship:altitude-ASDS_H)/ASDS_off)). //AOA, tgt, impact, offset height) //bigger smaller overshoot
			}
			Print "trueRadar: "+trueRadar.
			Print "maxDecel: "+maxDecel.
			Print stopDist.
			Print idealThrottle.
			set vd1 to vecdraw(v(0,0,0), L_impact:position:vec, green, "Landing", 1.0, true, 0.2).
			set vd2 to vecdraw(v(0,0,0), gl_TargetLatLng:position:vec, blue, "Target", 1.0, true, 0.2).
			set vd3 to vecdraw(v(0,0,0), SHIP:GEOPOSITION:position:vec, green, "shadow", 1.0, true, 0.2).
			set vd4 to vecdraw(v(0,0,0), mapGeo:position:vec, green, "Map Geo", 1.0, true, 0.2).			
			//Print pitch.
			//Print sin(pitch).
			Print "aoalim:" + aoalim.
			LOG MISSIONTIME + "," + ship:altitude + "," + airSpeed + "," + Groundspeed + "," + verticalSpeed + "," + pitch + hf_geoDistance(SHIP:GEOPOSITION,gl_TargetLatLng) + "," + ship:mass + "," + ship:availableThrust TO "0:/dataoutput.csv".
			wait 0.1.
		}
		//CRS-11 4.5km and 305 m/s at 07:10 mm:ss
		If sv_RTLS = True and sv_RTLSMax <> True{
			set AltstopDist to 1.20. //provide extra 20% for engine startup and control on RTLS as have extra fuel
		} Else {
			set AltstopDist to 0.7. //provide less 30% for engine startup with 3 engines
		}
		//final glide settings just before engine ignitions	
		Set SteeringManager:PITCHTORQUEADJUST to -1. //negative as we want to reduce the amount
		Set SteeringManager:YAWTORQUEADJUST to -1. //negative as we want to reduce the amount
		Set SteeringManager:ROLLTORQUEADJUST to -0.01. //negative as we want to reduce the amount
		until (trueRadar < stopDist * AltstopDist) and (airspeed < 450) and (trueRadar < 4500 ){ 
			local mapGeo is ff_GeoConv (mapDistL/1000, sv_intAzimith, gl_TargetLatLng:lat, gl_TargetLatLng:lng). 
			If sv_RTLS = True and sv_RTLSMax <> True{
				set aoalim to (1/Ship:Q)*6.//based on dynamic pressure 70 Kpa is 8.6, 20 Kpa is 30
				//set aoalim to sqrt(ship:altitude/1000)*5.//(ship:altitude/1000)*1.5.
				Set aoalim to min(hf_geoDistance(ground_track(impactData["time"]),gl_TargetLatLng)/25,aoalim).
				lock ster to getSteering(aoalim, gl_TargetLatLng, L_impact, (ship:altitude/RTLS_off)).//AOA, tgt, impact, offset height) //bigger smaller overshoot
				//lock ster to getSteering(aoalim, mapGeo, SHIP:GEOPOSITION, (ship:altitude/5)).// new based on mappedset path
			} Else{
				set aoalim to (1/Ship:Q)*6.//based on dynamic pressure 70 Kpa is 8.6, 20 Kpa is 30
				//set aoalim to sqrt(ship:altitude/1000)*6.//(ship:altitude/1000)*1.25.
				Set aoalim to min(hf_geoDistance(ground_track(impactData["time"]),gl_TargetLatLng)/25,aoalim).
				lock ster to getSteering(aoalim, gl_TargetLatLng, L_impact, ((ship:altitude-ASDS_H)/ASDS_off)).//AOA, tgt, impact, offset height) //bigger smaller overshoot
				//lock ster to getSteering(aoalim, mapGeo, SHIP:GEOPOSITION, (ship:altitude/5)).// new based on mappedset path
			}
			Print "trueRadar: "+trueRadar.
			Print "maxDecel: "+maxDecel.
			Print stopDist.
			Print Pitch.
			Print idealThrottle.
			Print "aoalim:" + aoalim.
			Print "Head" + gl_TargetLatLng:HEADING.
			Print hf_mAngleInv(gl_TargetLatLng:HEADING).
			set vd1 to vecdraw(v(0,0,0), L_impact:position:vec, green, "Landing", 1.0, true, 0.2).
			set vd2 to vecdraw(v(0,0,0), gl_TargetLatLng:position:vec, blue, "Target", 1.0, true, 0.2).
			set vd3 to vecdraw(v(0,0,0), SHIP:GEOPOSITION:position:vec, green, "shadow", 1.0, true, 0.2).	
			set vd4 to vecdraw(v(0,0,0), mapGeo:position:vec, green, "Map Geo", 1.0, true, 0.2).
			LOG MISSIONTIME + "," + ship:altitude + "," + airSpeed + "," + Groundspeed + "," + verticalSpeed + "," + pitch + hf_geoDistance(SHIP:GEOPOSITION,gl_TargetLatLng) + "," + ship:mass + "," + ship:availableThrust TO "0:/dataoutput.csv".	
			wait 0.01.
		}
		unlock impactData.
		Set runmode to 6.
	}

//Landing burn
	if runmode = 6{
		lock L_impact to Last_impact(radarOffset).
		Global throt_lim is 0.9.
		Print "Booster landing burn:"+ (TIME:SECONDS - EngineStartTime).
		If sv_RTLS = True and sv_RTLSMax <> True{
			} Else{
				//start outter engines
				ff_outter_engine_A().
				Print "outter engines start".
				ff_outter_engine_A().
				set throttle to 1. //needs to be one to start outter engines.
				wait 2.//ensures engines actually start
			}
		until (0 > trueRadar) or (Ship:Status = "LANDED") or (ship:verticalspeed > 0) {
			lock Throttle to min(max(0.1,idealThrottle),throt_lim).//ensure engine does not turn off
			local mapGeo is ff_GeoConv (mapDistL/1000, sv_intAzimith, gl_TargetLatLng:lat, gl_TargetLatLng:lng).
			If sv_RTLS = True{
				//do nothing
			}Else{
				set gl_TargetLatLng to target:GEOPOSITION. // Landing Pad Coords
			}

			If (trueRadar > (1000 + grndOffset)) or (ship:Q > 0.2) {
				local dist is hf_geoDistance(ground_track(impactData["time"]),gl_TargetLatLng).
				Print arctan(trueradar/dist).
				//lock ster to getSteeringTrans(20, gl_TargetLatLng, L_impact, Ship:Q/0.05, ((ship:altitude+grndOffset)/5)). //AOA, tgt, impact, ratio, offset height) //bigger ratio more atmosphere
				lock ster to getSteering(20, gl_TargetLatLng, L_impact, ((ship:altitude+grndOffset)/10)). //AOA, tgt, impact, offset height)		
				//lock ster to getSteeringTrans(20, mapGeo, SHIP:GEOPOSITION, Ship:Q/0.05,(ship:altitude/5)).// new based on mappedset path
				Set throt_lim to (idealThrottle*0.9).
				Print "Lift major".
			}
			If (trueRadar < (1000 + grndOffset)) or (ship:Q < 0.2) { // under 1000m
				lock ster to getSteeringTrans(20, gl_TargetLatLng, L_impact, Ship:Q/0.15, ((ship:altitude+grndOffset)/15)). //AOA, tgt, impact, ratio, offset height)
				Set throt_lim to (idealThrottle*0.95).
				Print "Lift medium".
			}
			If ship:Q < 0.125{ // 12.5kpa narrow AOA and make engine prime steering
				lock ster to getSteeringEngine(10, gl_TargetLatLng, L_impact,((ship:altitude+grndOffset)/50)). //AOA, tgt, impact, offest height. move to ship position instead of impact//15
				Set throt_lim to 1. //prior to this aero forces slow it down significantly so no need for full throttle
				Print "Engine Main".
			}
			If airspeed < 50 { // 50 m/s narrow AOA and keep engine prime
				lock ster to getSteeringEngine(10, gl_TargetLatLng, L_impact). //AOA, tgt, impact, offest height. move to ship position instead of impact
				Print "Engine 50".
			}
			if (ship:verticalspeed > (Up_trim/2)) or (Leg_trim > trueRadar){ ////CRS-11 0.3km and 70 m/s at 07:34 mm:ss
				Gear on.
			}
			if (trueRadar < (200 + grndOffset)) { //cancel out ground speed
				lock steering to getSteeringEngineStop (10).
				Print "Locked retro".
			}
			If trueRadar < 50 { // under 25m stop just point straight up.
				lock steering to lookdirup(up:vector, ship:facing:topvector).
				Print "Locked 50".
			}
			if idealThrottle < 0.2{
				ff_outter_engine_S().
				Print "outter shudown".
			}
			set vd1 to vecdraw(v(0,0,0), L_impact:position:vec, green, "Landing", 1.0, true, 0.2).
			set vd2 to vecdraw(v(0,0,0), gl_TargetLatLng:position:vec, blue, "Target", 1.0, true, 0.2).
			set vd3 to vecdraw(v(0,0,0), SHIP:GEOPOSITION:position:vec, green, "shadow", 1.0, true, 0.2).
			set vd4 to vecdraw(v(0,0,0), mapGeo:position:vec, green, "Map Geo", 1.0, true, 0.2).
			Print "trueRadar: "+trueRadar.
			Print "maxDecel: "+maxDecel.
			Print "stopDist "+stopDist.
			Print "Pitch " +Pitch.
			Print "thrott " +idealThrottle.
			Print "throt_lim "+throt_lim.
			local faltm is hf_Fall(radarOffset).
			Print "Impact: " + faltm["fallTime"].
			Print "Groundspeed" + Groundspeed.
			Print "Ground prop" +(verticalspeed / Groundspeed).
			LOG MISSIONTIME + "," + ship:altitude + "," + airSpeed + "," + Groundspeed + "," + verticalSpeed + "," + pitch + hf_geoDistance(SHIP:GEOPOSITION,gl_TargetLatLng) + "," + ship:mass + "," + ship:availableThrust TO "0:/dataoutput.csv".
			wait 0.01.
		}
		Lock throttle to 0.	
		Set runmode to 7.
	}
	wait 10.
	Print SHIP:GEOPOSITION.
	Print alt:radar.
	Shutdown. //ends the script
}

function hf_geoDistance { //Approx in meters using straight line. Good for flat surface approximatation and low computation. Does not take into accout curvature.
	parameter geo1.
	parameter geo2.
	return (geo1:POSITION - geo2:POSITION):MAG.
}

function hf_geoDir { //compass angle of direction to landing spot
	parameter geo1.
	parameter geo2.
	return ARCTAN2(geo1:LNG - geo2:LNG, geo1:LAT - geo2:LAT).
}

function hf_gs_bearing {
	parameter gs_p1, gs_p2. //(point1,point2). 
	//Need to ensure converted to radians 
	//TODO Test if this still works in degrees
	Set P1Lat to gs_p1:lat * constant:DegtoRad.
	Set P2Lat to gs_p2:lat * constant:DegtoRad.
	Set P1Lng to gs_p1:lng * constant:DegtoRad.
	Set P2Lng to gs_p2:lng * constant:DegtoRad.

	set resultA to (cos(P1Lat)*sin(P2Lat)) -(sin(P1Lat)*cos(P2Lat)*cos(P2Lng-P1Lng)).
	set resultB to sin(P2Lng-P1Lng)*cos(P2Lat).
	set result to  arctan2(resultA, resultB).// this is the intial bearing formula go to www.moveable-type.co.uk for more informationn


	// set resultA to (cos(gs_p1:lat)*sin(gs_p2:lat)) -(sin(gs_p1:lat)*cos(gs_p2:lat)*cos(gs_p2:lng-gs_p1:lng)).
	// set resultB to sin(gs_p2:lng-gs_p1:lng)*cos(gs_p2:lat).
	// set result to  arctan2(resultA, resultB).// this is the intial bearing formula go to www.moveable-type.co.uk for more information
return result.
}

function hf_geoVelSplit{
//Credits: https://www.reddit.com/r/Kos/comments/438e1o/converting_latitudelongitude_to_distance_in_meters/
Parameter LatLng1, LatLng2.
	Set pos1 to LatLng1:position.
	Set pos2 to LatLng2:position.
	set distance to (pos1-pos2):mag.

	set north_vector to heading(0,0):vector.
	set east_vector to heading(90,0):vector.

	set vel_lat to vxcl(vcrs(SHIP:UP:VECTOR,north_vector), SHIP:velocity:surface).
	set vel_lng to vxcl(vcrs(SHIP:UP:VECTOR,east_vector), SHIP:velocity:surface).
	
	Return list(vel_lat, vel_lng).
}

FUNCTION hf_mAngle{
PARAMETER a.
  UNTIL a >= 0 { SET a TO a + 360. }
  RETURN MOD(a,360).
  
}
FUNCTION hf_mAngleInv{
PARAMETER a.
  SET a TO a + 180.
  RETURN MOD(a,360).
  
}

function ff_quadraticPlus {
	parameter a, b, c.
	return (b - sqrt(max(b ^ 2 - 4 * a * c, 0))) / (2 * a).
}

FUNCTION impact_UTs {//returns the UTs of the ship's impact, NOTE: only works for non hyperbolic orbits
	PARAMETER minError IS 1.
	IF NOT (DEFINED impact_UTs_impactHeight) { GLOBAL impact_UTs_impactHeight IS 0. }
	LOCAL startTime IS TIME:SECONDS.
	LOCAL craftOrbit IS SHIP:ORBIT.
	LOCAL sma IS craftOrbit:SEMIMAJORAXIS.
	LOCAL ecc IS craftOrbit:ECCENTRICITY.
	LOCAL craftTA IS craftOrbit:TRUEANOMALY.
	LOCAL orbitPeriod IS craftOrbit:PERIOD.
	LOCAL ap IS craftOrbit:APOAPSIS.
	LOCAL pe IS craftOrbit:PERIAPSIS.
	LOCAL Alt_TA is alt_to_ta(sma,ecc,SHIP:BODY,MAX(MIN(impact_UTs_impactHeight,(ap - 1)),(pe + 1)))[1].
	LOCAL impactUTs IS startTime + time_betwene_two_ta(ecc,orbitPeriod,craftTA,Alt_TA).
	//Print "impactUTs:" + impactUTs.
	LOCAL newImpactHeight IS ground_track(impactUTs):TERRAINHEIGHT.
	SET impact_UTs_impactHeight TO (impact_UTs_impactHeight + newImpactHeight) / 2.
	RETURN LEX("time",impactUTs,//the UTs of the ship's impact
	"impactHeight",impact_UTs_impactHeight,//the aprox altitude of the ship's impact
	"converged",((ABS(impact_UTs_impactHeight - newImpactHeight) * 2) < minError)).//will be true when the change in impactHeight between runs is less than the minError
}

FUNCTION alt_to_ta {//returns a list of the true anomalies of the 2 points where the craft's orbit passes the given altitude
	PARAMETER sma,ecc,bodyIn,altIn.
	LOCAL rad IS altIn + bodyIn:RADIUS.
	LOCAL taOfAlt IS ARCCOS((-sma * ecc^2 + sma - rad) / (ecc * rad)).
	RETURN LIST(taOfAlt,360-taOfAlt).//first true anomaly will be as orbit goes from PE to AP
}

FUNCTION time_betwene_two_ta {//returns the difference in time between 2 true anomalies, traveling from taDeg1 to taDeg2
	PARAMETER ecc,periodIn,taDeg1,taDeg2.
	
	LOCAL maDeg1 IS ta_to_ma(ecc,taDeg1).
	LOCAL maDeg2 IS ta_to_ma(ecc,taDeg2).
	
	LOCAL timeDiff IS periodIn * ((maDeg2 - maDeg1) / 360).
	
	RETURN MOD(timeDiff + periodIn, periodIn).
}

FUNCTION ta_to_ma {//converts a true anomaly(degrees) to the mean anomaly (degrees) NOTE: only works for non hyperbolic orbits
	PARAMETER ecc,taDeg.
	LOCAL eaDeg IS ARCTAN2(SQRT(1-ecc^2) * SIN(taDeg), ecc + COS(taDeg)).
	LOCAL maDeg IS eaDeg - (ecc * SIN(eaDeg) * CONSTANT:RADtoDEG).
	RETURN MOD(maDeg + 360,360).
}

FUNCTION ground_track {	//returns the geocoordinates of the ship at a given time(UTs) adjusting for planetary rotation over time
	PARAMETER posTime.
	LOCAL pos IS POSITIONAT(SHIP,posTime).
	LOCAL localBody IS SHIP:BODY.
	LOCAL rotationalDir IS VDOT(localBody:NORTH:FOREVECTOR,localBody:ANGULARVEL). //the number of radians the body will rotate in one second (negative if rotating counter clockwise when viewed looking down on north
	LOCAL timeDif IS posTime - TIME:SECONDS.
	LOCAL posLATLNG IS localBody:GEOPOSITIONOF(pos).
	LOCAL longitudeShift IS rotationalDir * timeDif * CONSTANT:RADTODEG.
	LOCAL newLNG IS MOD(posLATLNG:LNG + longitudeShift ,360).
	IF newLNG < - 180 { SET newLNG TO newLNG + 360. }
	IF newLNG > 180 { SET newLNG TO newLNG - 360. }
	RETURN LATLNG(posLATLNG:LAT,newLNG).
}

function getSteeringBoost {
	Parameter tgt, impact.
    local errorVector is (impact:position - tgt:position).
    local velVector is -ship:velocity:surface.
    local result is ((velVector + errorVector) * -1).
	local result is  result + up:vector.// * pitch).
	
	//local pitchUp is ANGLEAXIS(pitch,ship:facing:starvector).
	//local result is pitchUp*result.
	//Print result.
	//local result is result + ANGLEAXIS(pitch,VCRS(VELOCITY:SURFACE,BODY:POSITION))*VELOCITY:SURFACE. //v(boost_pitch,0,0).
	//Print "pitch: " + boost_pitch.
	//Print result.
    return (lookDirUp(result, up:vector)).
}

function getSteeringTrans {
	Parameter aoa, tgt, impact, ratio, offset is 0.
    local errorVector is (impact:POSITION - tgt:ALTITUDEPOSITION(max(tgt:TERRAINHEIGHT + offset, 0))).
    local velVector is -ship:velocity:surface.
    local result1 is velVector + errorVector.
	local result2 is velVector - errorVector.

    if vang(result1, velVector) > aoa {
        set result1 to velVector:normalized + tan(aoa) * errorVector:normalized. //Atmosphere result
    }
	if vang(result2, velVector) > aoa {
        set result2 to velVector:normalized - tan(aoa) * errorVector:normalized.
    }

	local result is (result1*ratio) + (result2).

    return lookDirUp(result, facing:topvector).
}

function getSteeringEngine {
	Parameter aoa, tgt, impact, offset is 0.
    local errorVector is (impact:POSITION - tgt:ALTITUDEPOSITION(max(tgt:TERRAINHEIGHT + offset, 0))).
    local velVector is -ship:velocity:surface.
    local result is velVector - errorVector.

    if vang(result, velVector) > aoa {
        set result to velVector:normalized - tan(aoa) * errorVector:normalized.
    }
    return lookDirUp(result, facing:topvector).
}

function getSteering {
	Parameter aoa, tgt, impact, offset is 0, errormultiple is 1.
    local errorVector is (impact:POSITION - tgt:ALTITUDEPOSITION(max(tgt:TERRAINHEIGHT + offset, 0))).
    local velVector is -ship:velocity:surface.
    local result is velVector + (errorVector*errormultiple).

    if vang(result, velVector) > aoa {
        set result to velVector:normalized + tan(aoa) * errorVector:normalized.
    }
    return lookDirUp(result, facing:topvector).
}

function getSteeringEngineStop {
	Parameter aoa.
    local errorVector is (ship:POSITION - SHIP:GEOPOSITION:ALTITUDEPOSITION(max(SHIP:GEOPOSITION:TERRAINHEIGHT, 0))).
	set horizontalVel to vxcl(up:vector, velocity:surface).
    local velVector is -ship:velocity:surface - (horizontalVel*1.5).//1.25
    local result is velVector + (errorVector).
	
    if vang(result, velVector) > aoa {
        set result to velVector:normalized + tan(aoa) * errorVector:normalized.
    }
    return lookDirUp(result, facing:topvector).
}

function srfretrogradepitch {
	set progradepitch to 90 - vectorangle(ship:up:vector, ship:velocity:surface).
	return -progradepitch.
}

function Last_impact {
	Parameter offset is 0, rel_position is ship:position-ship:body:position.
	local falling is hf_Fall(offset).
	local impact_position is ship:velocity:surface * falling["falltime"] + rel_position.
	local impact is convertPosvecToGeocoord(impact_position).
    return impact.
}

function convertPosvecToGeocoord {
	parameter posvec.
	//sphere coordinates relative to xyz-coordinates
	local lat is 90 - vang(v(0,1,0), posvec).
	//circle coordinates relative to xz-coordinates
	local equatvec is v(posvec:x, 0, posvec:z).
	local phi is vang(v(1,0,0), equatvec).
	if equatvec:z < 0 {
		set phi to 360 - phi.
	}
	//angle between x-axis and geocoordinates
	local alpha is vang(v(1,0,0), latlng(0,0):position - ship:body:position).
	if (latlng(0,0):position - ship:body:position):z >= 0 {
		set alpha to 360 - alpha.
	}
	return latlng(lat, phi + alpha).
}

Function hf_Fall{
	parameter offset is 0.
//Fall Predictions and Variables
	local Grav is body:mu / (ship:Altitude + body:radius)^2.
	local fallTime is ff_quadraticPlus(-Grav/2, -ship:verticalspeed, (alt:radar + offset) - SHIP:GEOPOSITION:TERRAINHEIGHT).//r = r0 + vt - 1/2at^2 ===> Quadratic equiation 1/2*at^2 + bt + c = 0 a= acceleration, b=velocity, c= distance
	local fallVel is abs(ship:verticalspeed) + (Grav*fallTime).//v = u + at
	local disthorz is falltime*ship:velocity:surface.

	local arr is lexicon().
	arr:add ("fallTime", fallTime).
	arr:add ("fallVel", fallVel).
	arr:add ("disthorz", disthorz).
	
	Return(arr).
}

function ff_quadraticPlus {
	parameter a, b, c.
	return (b - sqrt(max(b ^ 2 - 4 * a * c, 0))) / (2 * a).
}

function ff_centre_engine_A{
	Local englist is List().
	LIST ENGINES IN engList. 
	FOR eng IN engList { 
		IF eng:TAG ="1DC" { 
			if eng:ALLOWRESTART{
				eng:activate. 
				//Print "Engine". 
			}
		}
	}
}

function ff_outter_engine_A{
	Local englist is List().
	LIST ENGINES IN engList. 
	FOR eng IN engList { 
		IF eng:TAG ="1DEC" { 
			if eng:ALLOWRESTART{
				eng:activate. 
				Print "Engine On". 
			}
		}
	}
}
function ff_outter_engine_S{
	Local englist is List().
	LIST ENGINES IN engList. 
	FOR eng IN engList { 
		IF eng:TAG ="1DEC" { 
			if eng:ALLOWSHUTDOWN{
				eng:shutdown. 
				//Print "Engine off".
			} 
		}
	}
}
function ff_GeoConv{
	parameter dist, brng, lat1, long1.//km, deg 0-360, deg-180+180, deg-90+90
	Print dist. 
	//Set brng to brng * constant:DegToRad.
	Print brng.
	Set lat1 to lat1 * constant:DegToRad.
	Print lat1.
	Set long1 to long1 * constant:DegToRad.
	Print long1.
	local lat2 is arcSin((sin(lat1) * cos(dist/6372)) + (cos(lat1) * sin(dist/6372) * cos(brng))).
	Print Lat2 * constant:RadToDeg.
	local long2 is long1 + arcTan2(sin(brng) * sin(dist/6372) * cos(lat1), cos(dist/6372) - (sin(lat1) * sin(lat2))).
	Print sin(brng) * sin(dist/6372) * cos(lat1).
	Print cos(dist/6372) - (sin(lat1) * sin(lat2)).
	Print arcTan2(sin(brng) * sin(dist/63872) * cos(lat1), cos(dist/6372) - (sin(lat1) * sin(lat2))).
	Print Long2 * constant:RadToDeg. 
	return latlng(lat2 * constant:RadToDeg, long2 * constant:RadToDeg).
}
