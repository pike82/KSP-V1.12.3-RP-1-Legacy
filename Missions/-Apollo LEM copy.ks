CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
SET TERMINAL:HEIGHT TO 65.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:BRIGHTNESS TO 0.8.
SET TERMINAL:CHARHEIGHT TO 10.
Local sv_ClearanceHeight is 10. 
// Get Mission Values
local wndw is gui(300).
set wndw:x to 700. //window start position
set wndw:y to 120.

local label is wndw:ADDLABEL("Enter LEM Mission Values").
set label:STYLE:ALIGN TO "CENTER".
set label:STYLE:HSTRETCH TO True. // Fill horizontally

local box_MoonEND is wndw:addhlayout().
	local MoonEND_label is box_MoonEND:addlabel("Moon PE km").
	local MoonENDvalue is box_MoonEND:ADDTEXTFIELD("15").
	set MoonENDvalue:style:width to 100.
	set MoonENDvalue:style:height to 18.

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

	set val to MoonENDvalue:text.
	set val to val:tonumber(0)*1000.
	set endPE to val.

	set val to Resvalue:text.
	set val to val:tonumber(0).
	set runmode to val.

	wndw:hide().
  	set isDone to true.
}

Global boosterCPU is "Atlas3".

Global gl_ISP is 311.
Global gl_Thrust is 45.
Global gl_Engines is 1.

//##############################################
If runmode = 0{
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
	Print "LEM active".
	ff_avionics_on().
	Panels on.
	Set SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
	SET SHIP:CONTROL:FORE TO 0.
	ff_COMMS().
	ff_avionics_off().
	wait 5.
	RCS off.
	Set runmode to 0.1.
}
If runmode = 0.1{
	Local counter is 0.
	Until counter > 5{
		Clearscreen.
		Print "Put node above landing location: " + (5-counter).
		wait 1.
		Set Counter to counter +1.
	}
	Global gl_TargetLatLng is Body:GEOPOSITIONOF(positionAT(ship, nextnode:eta)).
	//Global gl_TargetLatLng is LATLNG(0,11.8).
	Print gl_TargetLatLng.
	wait 5.
	remove nextnode.
	Set runmode to 0.5.
}
//Descent to height
If runmode = 0.5{
//work out when oppisite the landing site and conduct a burn to put PE at 50,000 feet (15,000 m)
	Global op_lng is gl_TargetLatLng:lng *-1.//180 used as usually want around 10 degrees before for moon
	Print "op_lng: "+op_lng.
	// if (op_lng > 360) {
	// 	set op_lng to op_lng - 180.
	// }
	// Print "op_lng2: "+op_lng.
	wait 5.
	Local start is time:seconds + 60.
	Local end is orbit:period + time:seconds + 60.
	local startSearchTime is hf_ternarySearch(
		hf_LngScore@,
		start, end, 1, false
	).
	local transfer is ff_seek(ff_freeze(startSearchTime), ff_freeze(0), ff_freeze(0), 10, hf_PEScore@, True).
	set runmode to 0.6.
}
If runmode = 0.6{
//conduct burn
	wait 10.
	Until ((nextnode:eta) < 120){
		Clearscreen.
		Print "Reduction burn in: " + (nextnode:eta - 120).
		wait 1.
	}
	Print "Orbit reduction Started".
	wait 1.
	lock steering to nextnode:burnvector.
	RCS on.
	until (nextnode:eta < 7){
		wait 1.
	}
	Print "Ullage Started".
	Local englist is List().
	LIST ENGINES IN engList. 
	FOR eng IN engList {  
		IF eng:TAG ="LEMD" { 
			eng:activate. 
			Print "Engine". 
		}
	}
	SET SHIP:CONTROL:FORE to 1.
	wait 1.
	until (nextnode:eta < 3){
		wait 0.01.
	}
	lock throttle to 1.
	SET SHIP:CONTROL:FORE to 0.
	Print "Starting Descent Burn".
	//Start main engines
	until hf_isManeuverComplete(nextnode) {
		wait 0.001.
	}
	FOR eng IN engList { 
		IF eng:TAG ="LEMD" { 
			eng:shutdown.
		}
	}
	lock throttle to 0.
	RCS off.
	remove nextnode.
	set runmode to 2.0.
}
//Auto Land Setup
If runmode = 1.0{
	Global gl_LandTime is 0.
	If gl_TargetLatLng <> "Null"{
		Set gl_LandTime to ff_LandingPointSetup(gl_TargetLatLng,1500, 10).
		Set gl_LandTime to gl_LandTime[0].
	} 
	set runmode to 2.0.
}

//Node based landing Setup
If runmode = 1.1{
	Local counter is 0.
	Until counter > 20{
		Clearscreen.
		Print "Refine Node to start descent burn before: " + (20-counter).
		wait 1.
		Set Counter to counter +1.
	}
	Set gl_LandTime to nextnode:ETA + TIME:SECONDS.
	set runmode to 2.0.
}

////Commence Landing routine (based on auto or manual node time from above)
If runmode = 2.0{
	Set gl_LandTime to eta:periapsis + TIME:SECONDS.
	Global gl_TargetLatLng is Body:GEOPOSITIONOF(positionAT(ship, eta:periapsis)).
	//this needs to be done first for the est profile land to run
	Local englist is List().
	LIST ENGINES IN engList. 
	FOR eng IN engList {  
		IF eng:TAG ="LEMD" { 
			eng:activate. 
			Print "Engine". 
		}
	}
	local p_time is ff_ESTProfileLand(gl_LandTime).
	Print gl_LandTime.
	local startTime is (gl_LandTime - (p_time/2)).
	Print "startTime: " + startTime. 
	Print (startTime - time:seconds).
	wait 10.
	Until ((startTime - time:seconds) - 120) < 0{
		Clearscreen.
		Print "Descent burn in: " + (startTime - time:seconds -120).
		Print hf_geoDistance (gl_TargetLatLng, SHIP:GEOPOSITION).
		wait 1.
	}
	Print "Power Descent Started".
	Set warp to 0.
	wait 1.
	ff_avionics_on().
	Lock steering to retrograde.
	RCS on.
	until ((startTime - time:seconds) - 7) < 0{
		wait 1.
	}
	Print "Ullage Started".
	SET SHIP:CONTROL:FORE to 1.
	wait 2.
	until time:seconds > (startTime){
		wait 0.01.
	}
	SET SHIP:CONTROL:FORE to 0.
	Print "Starting Descent Burn".
	//Start main engines
	Lock Throttle to 1.
	ff_ProfileLand(0.9, 250, p_time).
	Print "ProfileLand end".
	Set runmode to 3.0.
}
//commence hover Landing routine
If runmode = 3.0{
	Print "hover 750".
	Lock Throttle to 1.
	ff_hoverLand(250).//f_hoverLand(250, gl_TargetLatLng).
	Print "Shutdown routine".
	SET SHIP:CONTROL:FORE to 0.
	lock throttle to 0.
	RCS off.
	ff_Avionics_off().
	wait 40.
	Shutdown.
}

///// Take off routine
If runmode = 4.0{
	Clearscreen.
	ff_Avionics_on().
	RCS on.
	lock throttle to 1.
	Print "lift off: "+ altitude.
	LOCK STEERING to HEADING(90,90). // Lock in upright posistion and fixed rotation
	until ALT:RADAR > 50{
		wait 1.
	}
	Print "Move to 45: "+ altitude.
	LOCK STEERING to HEADING(90,45).
	until ((ALT:RADAR > 5000) or (altitude > 10000)) and (SHIP:GROUNDSPEED > 150){
		wait 1.
	}
	Print "Move to 30: "+ altitude.
	LOCK STEERING to HEADING(90,30).
	until ((ALT:RADAR > 10000) or (altitude > 17000)) and (SHIP:GROUNDSPEED > 300) {
		wait 1.
	}
	Print "Move to 10: "+ altitude.
	LOCK STEERING to HEADING(90,10).
	until (Ship:apoapsis > endPE) and (SHIP:GROUNDSPEED > 1200){
		wait 1.
	}
	Print "Move to Circ: "+ altitude.
	lock throttle to 0.
	Set runmode to 5.0.
}

If runmode = 5.0{
	local Cirdv is ff_CircOrbitVel(ship:orbit:apoapsis) - ff_EccOrbitVel(ship:orbit:apoapsis, ship:orbit:semimajoraxis).
	Set n to Node(time:seconds + ETA:APOAPSIS,0,0,Cirdv).
	Add n.
	local startTime is time:seconds + nextnode:eta - (ff_Burn_Time(nextnode:deltaV:mag / 2, 296.1, 4, 1)).
	lock steering to nextnode:burnvector.
	wait until time:seconds > startTime.
	lock throttle to 1.
	wait 0.3.
	until hf_isManeuverComplete(nextnode) {
		wait 0.001.
	}
	lock throttle to 0.
	unlock steering.
	RCS off.
	wait 1.0.
	remove nextnode.
	ff_Avionics_off().
	Set runmode to 6.0.
}

If runmode = 6.0{
	Local counter is 0.
	Until counter > 180{
		Clearscreen.
		Print "Refine Node before: " + (180-counter).
		wait 1.
		Set Counter to counter +1.
	}
	local startTime is time:seconds + nextnode:eta - (ff_Burn_Time(nextnode:deltaV:mag / 2, 296.1, 4, 1)).
	ff_Avionics_on().
	wait until time:seconds > (startTime - 20).
	RCS on.
	lock steering to nextnode:burnvector.
	wait until time:seconds > startTime.
	lock throttle to 1.
	wait 1.
	until hf_isManeuverComplete(nextnode) {
		wait 0.001.
	}
	lock throttle to 0.
	unlock steering.
	RCS off.
	remove nextnode.
	ff_Avionics_off().
	Set runmode to 7.0.
}

If runmode = 7.0{
	Shutdown.
}
//##############################################
//##############################################
//##############################################
//Transfer Functions
//##############################################
//##############################################
//##############################################
// this function determines if the current orbit PE passes close to the target landing area or if a correction burn needs to be made
Function ff_LandingPointSetup{ 
	Parameter tgt_point, max_dist is 500, Max_Orbits is 100. // throttle start time is the time it take the throttle to 	
	
	Local Orbit_OK is hf_CheckInc(tgt_point:Lat, Ship:ORBIT:inclination).
	Print Orbit_OK.
	If NOT Orbit_ok {
	//Put code here to conduct a plane change so the orbit inclination is high enough to reach the lattitude
	
	}
	
	//Once the inclination is suitable, find the next orbit which passes near the landing spot.
	Local Landing_Param is hf_findNextPass(tgt_point, max_dist, max_orbits).
	Print Landing_Param[2].
	If not Landing_Param[2] { // no acceptable solution was found as found pass will be false
	// put code in here to adjust the orbit so it can be a suitable solution. noting we have the closest distance and its time returned in the array, which can help with the orbit adjustment. I suggest using a hill climb along with the find next path to find a suitable solution.
	
	
		// look into SHIP:ORBIT:BODY:ROTATIONPERIOD and the time from LAN to PE in an eliptical orbit. We know the time from LAN to PE will be constant so we will have a fixed rotation of the body to PE (during the transit of the argument of perioapsis) and there for know where PE will be for a given LAN. Therefore we will need to adjust the orbit so we have that we pass over a given LAN and therefore a given PE at the target.
	// //TODO: work out how to tell if the orbit is in the same direction as the body rotation.
	
	}
	//otherwise return the time, distance and confirmation of an acceptable pass.
	Print "Landing_Param " + Landing_Param.
	Return (Landing_Param).

} //End of Function

/////////////////////////////////////////
//Credit:https://github.com/ElWanderer/kOS_scripts 
FUNCTION hf_CheckInc{
PARAMETER lat,inc. // returns true is the inclination is high enough to pass the specified lattitude
  RETURN (inc > 0 AND MIN(inc,180-inc) >= ABS(lat)).
}

/// Returns the True anomolies where the orbit reaches a specific lattitude
FUNCTION hf_TAatLat{
PARAMETER lat.

  IF NOT hf_CheckInc(lat, ship:ORBIT:INCLINATION) { RETURN -1. } // double check the inclinations is ok
  
  LOCAL ArgPer IS hf_mAngle(Ship:ORBIT:ARGUMENTOFPERIAPSIS).
  Local Ang1 is hf_mAngle(ARCSIN((SIN(lat)/SIN(ship:ORBIT:INCLINATION))) - ArgPer).
  Print "ArgPer"+ArgPer.
  Print "Ang1"+Ang1.
  LOCAL ta_extreme_lat IS hf_mAngle(90 - ArgPer).
  Print "ta_extreme_lat" + ta_extreme_lat.
  IF lat < 0 { 
	SET ta_extreme_lat TO hf_mAngle(270 - ArgPer). 
  }
  Local Ang2 is hf_mAngle((2 * ta_extreme_lat) - Ang1).  
  Print "Ang2"+Ang2.
  RETURN list(Ang1, Ang2).
}

FUNCTION hf_findNextPass{
  // max_dist in metres
PARAMETER tgt_landing, max_dist, max_orbits is 100.

	LOCAL base_time IS TIME:SECONDS.
	LOCAL return_time IS 0. // the UC time returned when the vessel is at the closest distance
	LOCAL return_dist IS 1000000. // the distance value returned by this function, initially set very high to allow for smaller distances to overwrite it
	LOCAL orbit_count IS 0.
	LOCAL found_pass IS FALSE.
	LOCAL TA1_first IS TRUE. // Keeps track of which TA is next.
	
	LOCAL ship_period IS Ship:ORBIT:PERIOD.
	LOCAL max_orbits_time IS max_orbits * Ship:ORBIT:PERIOD.
	
	LOCAL ArgLATs is hf_TAatLat(tgt_landing:lat). // the TA's when the craft passes the latitude
	Print "ArgLATs "+ArgLATs.	
	LOCAL TA1 IS ArgLATs[0].
	LOCAL TA2 IS ArgLATs[1].
	LOCAL TA1_time IS base_time + ff_timeFromTA (TA1, ship:orbit:eccentricity). 
	LOCAL TA2_time IS base_time + ff_timeFromTA (TA2, ship:orbit:eccentricity).
	Wait 3.0.
	IF TA2_time < TA1_time { // check to see which TA we are passing first
		SET TA1_first TO FALSE. 
	}

	UNTIL found_pass OR orbit_count >= max_orbits { // loop until solition found or the max orbits has been reached
		SET orbit_count TO orbit_count + 1.

		LOCAL pass_count IS 0.
		
		UNTIL found_pass OR pass_count > 1 { // loop until a solution has been found or a full orbit has taken place.
			LOCAL pass_time IS 0.
			IF (pass_count = 0 AND ta1_first) OR
				(pass_count = 1 AND NOT ta1_first) { 
				SET pass_time TO ta1_time. 
			}
			ELSE { 
				SET pass_time TO ta2_time. 
			} // this section is used to determine which TA time to use

			Set Spot to hf_BodyPositionAt(pass_time). // Set the spot to the predicted Co-ords when the ship passes over.
			IF abs(hf_gs_distance(Spot, tgt_landing)) < (10*max_dist) {  // checks if within 10*max distance
				Local ShortDistTime_list is ff_optimize (
					list(pass_time), 
					{
						Parameter new_time_list. 
						Local new_time is new_time_list[0].
						Set new_pos to hf_BodyPositionAt(new_time).
						Set new_dist to hf_gs_distance(new_pos, tgt_landing). // Using gs_Distance as the distance is expected to be large.
						Return - new_dist.
					}, 
					0.5 // look in 0.5 second incriments arount the time it passess over the lattitude for the nearest distance
				).
				local ShortDistTime is ShortDistTime_list[0].
				local Short_pos is hf_BodyPositionAt(ShortDistTime).
				Local Short_dist is hf_gs_distance(new_pos, tgt_landing).// get the new lowest distance found
				If  Short_dist < return_dist { //update so even if a suitable pass is not found the closest pass is found.
					Set return_dist TO Short_dist.
					Print "Short_dist "+Short_dist.
					SET return_time TO ShortDistTime.
					Print "ShortDistTime " + ShortDistTime.
					Wait 0.1.
				}
				IF Short_dist < max_dist AND Short_dist >= 0 { // checks to see if with the max distance tolerance
				  SET found_pass TO TRUE.
				}
			}
			SET pass_count TO pass_count + 1.
			Print "Diff:" + ABS(spot:LNG - tgt_landing:LNG).
			Print hf_gs_distance(Spot, tgt_landing).
			Print (10*max_dist).
			Print abs(hf_gs_distance(Spot, tgt_landing)) < (10*max_dist).
			Print pass_time.
			Wait 1.
		}

		SET TA1_time TO TA1_time + ship_period. //moves onto the next orbit
		SET TA2_time TO TA2_time + ship_period. //moves onto the next orbit
	  }
	  RETURN list(return_time, return_dist, found_pass).
}

///////////////////////////////////////////////////////////////////////
//Returns the coordiates that the ship will be over at a given time accounting for planet rotation.
Function hf_BodyPositionAt{

//Credits:Own

Parameter Pass_time.
	LOCAL BodRotTime is Body:ROTATIONPERIOD.
	LOCAL spot is Body:GEOPOSITIONOF(POSITIONAT(ship,pass_time)). // Get Coordinates when passing lattitude point assuming no rotation
	LOCAL time_diff is MOD(pass_time - TIME:SECONDS, BodRotTime). // get the time until this point is reached
	LOCAL new_lng is hf_mAngle(spot:LNG - (time_diff * 360 / BodRotTime)). // find the rotation of the body during this time and what the longatude will be.
	Return LATlNG(spot:LAT,new_lng).
}


Function hf_LandingPIDControlLoop{
Parameter lastdt, lastPos.
	set gl_shipLatLng to SHIP:GEOPOSITION. 
	Set lastdt to min(TIME:SECONDS-0.01, lastdt). //Ensures there is a time difference so there is no divide by zero
	Set DegDistance to (body:radius*2*constant:pi)/360.
	Set Tgt to LATLNG(sv_PIDLAT:Setpoint,sv_PIDLONG:Setpoint).
	
	Set LatDist to hf_geoDistance(LATLNG(gl_shipLatLng:Lat,tgt:Lng),tgt). // distance to tgt in Lat metres only
	Set LngDist to hf_geoDistance(LATLNG(tgt:Lat,gl_shipLatLng:Lng),tgt). // distance to tgt in Lng metres only
	
	SET ALTSpeed TO sv_PIDALT:UPDATE(TIME:SECONDS, alt:radar). //Get the PID on the AlT diff as desired vertical velocity
	Set LATSpeed to sv_PIDLAT:Update(TIME:SECONDS, gl_shipLatLng:Lat).//Get the PID on the Lat diff as desired lat in m/s
	Set LONGSpeed to sv_PIDLONG:UPDATE(TIME:SECONDS, gl_shipLatLng:Lng). //Get the PID on the Long diff as desired long in m/s

	Set sv_PIDThrott to PIDLOOP(0.1, 0.2, 0.005, 0.05, 1).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	Set sv_PIDThrott:SETPOINT to ALTSpeed. // Set the ALT diff PID as the desired vertical speed
	Set sv_PIDNorth to PIDLOOP(10000, 0, 0, -10, 10).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).
	Set sv_PIDNorth:SETPOINT to LATSpeed. // the new desired speed in m/s
	Set sv_PIDEast to PIDLOOP(10000, 0, 0, -10, 10).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).
	Set sv_PIDEast:SETPOINT to LONGSpeed. // the new desired speed in m/s
	
	Set NorthSpeed to (gl_shipLatLng:Lat - LastPos:Lat)/(TIME:SECONDS-lastdt).
	Set EastSpeed to (gl_shipLatLng:Lng - LastPos:Lng)/(TIME:SECONDS-lastdt).
	
	Set Splitarr to hf_geoVelSplit (gl_shipLatLng,LastPos).
	
	Set NorthSpeed1 to Splitarr[0]:mag.
	Set EastSpeed1 to Splitarr[1]:mag.

	global ThrottSetting is sv_PIDThrott:UPDATE(TIME:SECONDS, verticalspeed). // PID the vertical velocity with the new desired speed
	SET NorthDirection TO sv_PIDNorth:UPDATE(TIME:SECONDS, NorthSpeed). // PID the North velocity with the new desired speed
	SET EastDirection TO sv_PIDEast:UPDATE(TIME:SECONDS, EastSpeed). // PID the East velocity with the new desired speed
	
	lock throttle to ThrottSetting.
	
	Set SteerDirection to UP + r(NorthDirection,EastDirection,180). // r(pitch, yaw, roll) set roll to zero, this will allow pitch to equal Lat(North) direction required and Yaw(East) to equal Long direction required		
	//TODO: had negatives, this may only be north or south hemisphere specific.
	Set Flight_Arr to hf_fall(gl_ISP).	
	Print "===============================".
	Print "Target Lat: " + sv_PIDLAT:Setpoint.	
	Print "Current Lat: " + gl_shipLatLng:Lat.
	Print "Lat diff: " + (sv_PIDLAT:Setpoint - gl_shipLatLng:Lat).	
	Print "LATSpeed:"	+ LATSpeed.
	Print "NorthSpeed:" + NorthSpeed.
	Print "NorthSpeed1:" + NorthSpeed1.
	Print "NorthDirection:" + NorthDirection.
	Print "===============================".
	Print "Target Long: " + sv_PIDLONG:Setpoint.		
	Print "Current Long: " + gl_shipLatLng:Lng.
	Print "Long diff: " + (sv_PIDLONG:Setpoint - gl_shipLatLng:Lng).
	Print "LONGSpeed:"	+ LONGSpeed.
	Print "EastSpeed:" + EastSpeed.
	Print "EastSpeed1:" + EastSpeed1.
	Print "EastDirection:" + EastDirection.
	Print "===============================".
	Print "Calc tgt Dist:" + hf_geoDistance(gl_shipLatLng, tgt).	
	Print "===============================".	
	Print "ALT Kp: " + sv_PIDALT:Pterm.
	Print "ALT Ki: " + sv_PIDALT:Iterm.
	Print "ALT Kd: " + sv_PIDALT:Dterm.
	Print "ALT Out: " + sv_PIDALT:OUTPUT.
	Print "===============================".
	Print "Thrott Kp: " + sv_PIDThrott:Pterm.
	Print "Thrott Ki: " + sv_PIDThrott:Iterm.
	Print "Thrott Kd: " + sv_PIDThrott:Dterm.
	Print "Thrott Out: " + sv_PIDThrott:OUTPUT.
	Print "===============================".
	//Print "Delta throttle: "+ dThrot.
	Print "Throttle Setting: "+ ThrottSetting.
	Print "Current Alt" + ship:Altitude.
	Print "Ground Dist" + alt:radar.
	Print "tgt Bearing :" + tgt:bearing.
	Print "Calc tgt Bearing:" + hf_geoDir(gl_shipLatLng, tgt).
	Print "Calc True tgt Bearing: " + hf_gs_bearing(gl_shipLatLng,tgt).
	Print "tgt Heading :" + tgt:heading.
	Print "===============================".
	Print "Fall time: " + Flight_Arr["fallTime"].	
	Print "Fall vel: " + Flight_Arr["fallVel"].
	Print "===============================".
	
	Set lastPos to SHIP:GEOPOSITION.
	Set lastdt to TIME:SECONDS.
	
	Local Result is lexicon().
	
	Result:add("lastPos",lastPos).
	Result:add("lastdt",lastdt).
	
	Return Result.
}

//////////////////////////////////////////////////////////
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

function hf_geoDistance { //Approx in meters using straight line. Good for flat surface approximatation and low computation. Does not take into accout curvature.
	parameter geo1.
	parameter geo2.
	return (geo1:POSITION - geo2:POSITION):MAG.
}

function hf_gs_distance {

//use this distance for where larger distances are expected. 
// this is the "Haversine" formula go to www.moveable-type.co.uk for more information
parameter gs_p1, gs_p2. //(point1,point2). 
	//Need to ensure converted to radians 
	//TODO Test if this still works in degrees
	Set P1Lat to gs_p1:lat * constant:DegtoRad.
	Set P2Lat to gs_p2:lat * constant:DegtoRad.
	Set P1Lng to gs_p1:lng * constant:DegtoRad.
	Set P2Lng to gs_p2:lng * constant:DegtoRad.
	set resultA to 	sin((P1Lat-P2Lat)/2)^2 + 
					cos(P1Lat)*cos(P2Lat)*
					sin((P1Lng-P2Lng)/2)^2.
	set resultB to 2*arctan2(sqrt(resultA),sqrt(1-resultA)).
	set result to body:radius*resultB. // this is the "Haversine" formula go to www.moveable-type.co.uk for more information
	
return result.
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

function hf_ImpactEta {
    parameter acc, thrtl, g, vel, h.
    return ff_quadraticMinus((acc * thrtl - g), vel, h).
}

function hf_cardVel {
	//Convert velocity vectors relative to SOI into east and north.
	local vect IS SHIP:VELOCITY:SURFACE.
	local eastVect is VCRS(UP:VECTOR, NORTH:VECTOR).
	local eastComp IS scalarProj(vect, eastVect).
	local northComp IS scalarProj(vect, NORTH:VECTOR).
	local upComp IS scalarProj(vect, UP:VECTOR).
	RETURN V(eastComp, upComp, northComp).
}

function velPitch { //angle of ship velocity relative to horizon
	LOCAL cardVelFlat IS V(cardVelCached:X, 0, cardVelCached:Z).
	RETURN VANG(cardVelCached, cardVelFlat).
}
function velDir { //compass angle of velocity
	return ARCTAN2(cardVelCached:X, cardVelCached:Y).
}
function scalarProj { //Scalar projection of two vectors. Find component of a along b. a(dot)b/||b||
	parameter a.
	parameter b.
	if b:mag = 0 { PRINT "scalarProj: Tried to divide by 0. Returning 1". RETURN 1. } //error check
	RETURN VDOT(a, b) * (1/b:MAG).
}

function ff_timeFromTA {
//TODO: Check this code work for all positions and cases need to check if TA time from PE returns only in one direction or swaps times once 180 degrees has been reached.

	parameter TA, ecc. // True anomoly (must be in degrees), eccentricity.
	Local timetoTA is ff_TAtimeFromPE (TA, ecc).
	Print (ETA:periapsis + timetoTA).
	Print Ship:orbit:Period.
	Print (ETA:periapsis + timetoTA) - Ship:orbit:Period.
	If (ETA:periapsis + timetoTA) - Ship:orbit:Period > 0{ // we know we will get to the TA before the PE.
		Print "Not Else".
		return (ETA:periapsis + timetoTA) - Ship:orbit:Period.
	}
	Else {  // we know we will get to the PE before the TA.
		return  (ETA:periapsis + timetoTA). //TA time from PE in seconds (add time:seconds to get UT).
		Print "Else".
	}
}

function ff_TAtimeFromPE {
	parameter TA, ecc. // True anomoly (must be in degrees), eccentricity.
	local EA is ff_EccAnom(ecc, TA).
	Print "EA:" + EA.
	local MA is ff_MeanAnom(ecc, EA).
	Print "MA:" + MA.
	local TA_time is Ship:orbit:Period/360. //sec per degree
	Print "TA time intermediate: " + TA_time.
	Set TA_time to MA*TA_time.
	Print "TA Time From PE:" + TA_time.
	return TA_time. //TA time from PE in seconds, Range from 0 to Ship:Orbital period
}

function ff_EccAnom {
	parameter ecc, TA. // eccentricity, True Anomoly (in radians or degrees).
	Print ecc.
	Print TA.
	local E is arccos(  (ecc + cos(TA)) / (1 + (ecc * cos(TA)))  ).
	Print "EccAnom:" + E.	
	//Old version
	//Local E is arctan(sqrt(1-(ecc*ecc))*sin(TA) ) / ( ecc + cos(TA) ). // note this version is suitable for radians only
	//Print "Old EccAnom:" + E.
	return E. //Eccentric Anomoly in True anomoly input (radians or degrees)

}

function ff_MeanAnom {
	parameter ecc, EccAnom. // eccentricity, Eccentric Anomoly (in radians or degrees).
	local MA is EccAnom - (ecc * sin(EccAnom)).
	//Print "MeanAnom:" + MA.
	return MA. //Mean Anomoly in EccAnom input(radians or degrees)
}
//##############################################################################
//##############################################################################
//##############################################################################
//Landing Functions
//##############################################################################
//##############################################################################
//##############################################################################
Function ff_ESTProfileLand{ 
	//this estimate the burn time to no horizontal velocity based on a profile approach
	Parameter LandTime, EndHorzVel is 0. // throttle start time is the time it take the trottle to get up to full power TODO: have this also take into account the rotation of the body so it can target a specific landing spot.
	Print "Landing Burn Start Time: " + LandTime.
	Wait 5.
	Set PEVec to velocityat(Ship, LandTime):Surface.
	Set Horzvel to abs(PEVec:mag). // its known at PE the verVel is Zero so all velocity must in theory be horizontal	
	Set VerVel to 0.
	Set VerDist to 0.
	Set Dist to 0.
	local profiletime is 0.
	Set tgtPERad to Orbit:Periapsis+body:radius.
	Set StartMass to (ship:mass * 1000).

	until Horzvel <= EndHorzVel {//run the iteration until the ground velocity is 0 or another value if specified
		Set VerVelStart to VerVel.
		Set StartMass to StartMass - ff_mdot(gl_ISP, gl_Thrust,gl_Engines).
		Set acc to (ship:availablethrust* 1000)/(StartMass). //the acceleration of the ship in one second
		Set VertAccel to ((body:mu/((tgtPERad-VerDist)^2)) - ((Horzvel^2)/(tgtPERad-VerDist))). //portion of vehicle acceleration used to counteract gravity as per PEG ascent guidance formula in one second
		Set VerVel to VerVelStart - abs(VertAccel). // current vertical velocity.
		Set VerDist to VerDist - ((VerVelStart + VerVel)/2).
		Set Horzvel to Horzvel - abs(acc).
		Set dist to dist + Horzvel.
		Set profiletime to profiletime + 1.
		Clearscreen.
		Print "Acc:"+acc.
		Print "VAcc:"+VertAccel.
		Print "Hvel:"+Horzvel.
		Print "Vdist:"+VerDist.
		Print "Vvel:"+VerVel.
		Print "Dist:"+dist.
		Print "Time:"+profiletime. // note this is the worst case burn time if a CAB needs to be performed. //Ideally it will be shorter.
		wait 0.001.
	} // note this estimates based on a CAB which is the worst case senario, but in reality it should be able to burn for less time than estimated.
	
	Return profiletime.
}

Function ff_ProfileLand{ 
	//this landing tries to burn purely horizontal and uses a pid to determine the desired downwards velocity and cancel it out through a pitch change. It does not stop the throttle or point upwards, that is upto the user to code in or allow a transistion into another function.
	Parameter ThrottelStartTime is 0.1, SafeAlt is 250, profiletime is 0, EndHorzVel is 0. // throttle start time is the time it take the trottle to get up to full power TODO: have this also take into account the rotation of the body so it can target a specific landing spot.
	Set PIDVV to PIDLOOP(0.03, 0, 0.01, -0.03, 0.03).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	Set PIDVV:SETPOINT to 0. // we want the altitude to remain constant so no vertical velocity.
	Set highpitch to 0.
	
	Set PIDFALL to PIDLOOP((ship:availablethrust / (ship:mass*100)), 0, 0.1, -100, 0).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	Set PIDFALL:SETPOINT to 0. // we want zero fall speed when the difference between actuall height and fall height is zero.

	//lock steering to retrograde * r(-highPitch, 0, 0):vector.
	Lock Horizon to VXCL(UP:VECTOR, -VELOCITY:SURFACE). //negative makes it retrograde
	LOCK STEERING TO LOOKDIRUP(ANGLEAXIS(-highPitch,
                        VCRS(horizon,BODY:POSITION))*horizon,
						FACING:TOPVECTOR).//lock to retrograde at horizon
	
	local Flight_Arr is lexicon().
	set Flight_Arr to hf_fall(gl_ISP).
	Set Basetime to time:seconds.

		
	Set highpitch to 0.
	until (Basetime + (profiletime*1.1) ) - time:seconds < 0 OR SHIP:GROUNDSPEED < 2{ // Unil we should have stopped based on time or we have actually stopped TODO: Make it so the +10 is not hardcoded in.
		//lock throttle to 1.
		set Flight_Arr to hf_fall(gl_ISP).
		Set tgtFallheight to Flight_Arr["fallDist"] + SafeAlt + (ThrottelStartTime * abs(ship:verticalspeed)).
		Set FALLSpeed to PIDFALL:UPDATE(TIME:SECONDS, (ALT:RADAR - tgtFallheight)). //set the allowable fall speed to ensure we don't fall so fast we will crash
		Set PIDVV:SETPOINT to FALLSpeed.
		Set dpitch TO PIDVV:UPDATE(TIME:SECONDS, verticalspeed). //Get the PID on the AlT diff as desired vertical velocity
		Set highpitch to min(max(highpitch + dpitch,0),80). // Ensure the pitch does not go below zero as gravity will efficently lower the veritcal velocity if required or above 80.
		Clearscreen.
		Print "Limiting Descent Speed".
		Print "Ground Speed: " + SHIP:GROUNDSPEED.
		Print "SuicideFallheight:" + Flight_Arr["fallDist"].
		Print "Alt: " + ALT:RADAR.
		Print "Fall Clearance:" + (ALT:RADAR - tgtFallheight).
		Print "SuicideFallVel:" + Flight_Arr["fallVel"].
		Print "Vertical speed:" + verticalspeed.
		Print "Fall Vel Clearance:" + (Flight_Arr["fallVel"] - verticalspeed).
		Print "Fall time:" + Flight_Arr["fallTime"].		
		Print "Fall speed setting:" + Fallspeed.
		Print "Pitch: " + highpitch.
		Print "Burn Ending in : " + ((Basetime + profiletime) - time:seconds).
		wait 0.01.
	}
	Print "PID End".
	Unlock Steering.// unlocks for the hoverland function
} //End of Function

Function ff_hoverLand {	
Parameter Hover_alt is 50, BaseLoc is SHIP:GEOPOSITION. 
	//lock throttle to 1.
	set gl_DegDistance to (body:radius*2*constant:pi)/360.
	Set sv_PIDALT to PIDLOOP(0.9, 0.0, 0.0005, -50, 1).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).
	Set sv_PIDLAT to PIDLOOP(1.0, 0.0, 5.0, 5/gl_DegDistance, -5/gl_DegDistance).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).
	Set sv_PIDLONG to PIDLOOP(0.5, 0, 2.5, -5/gl_DegDistance, 5/gl_DegDistance).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).

	Set sv_PIDALT:SETPOINT to max(alt:radar/20,Hover_alt).
	Set sv_PIDLAT:Setpoint to BaseLoc:Lat.
	Set sv_PIDLONG:Setpoint to BaseLoc:Lng.
	Set SteerDirection to HEADING(90,90). // inital setup
	LOCK STEERING TO SteerDirection.
	
	Set distanceTol to 0.	
	local dtStore is lexicon().
	dtStore:add("lastdt", TIME:SECONDS).
	//dtStore:add("lastPos",LATLNG(0,0)).
	dtStore:add("lastPos",SHIP:GEOPOSITION).
	
	Until distanceTol > 3 or (ALT:RADAR < 1) or (Ship:Status = "LANDED") { // until the ship is hovering above the set down loaction for 3 seconds (to allow for PID stability before heading down)
		ClearScreen.
		Print "Moving to Landing Position".	
		Set dtStore to hf_LandingPIDControlLoop(dtStore["lastdt"], dtStore["lastPos"]).
		if hf_geoDistance(BaseLoc, SHIP:GEOPOSITION) < 0.5{ //0.5m error before descent. Using geoDistance as distance is expected to be small (less than 1km)
			Set distanceTol to distanceTol + 0.1.	
		}
		Else{
			Set distanceTol to 0.
		}

		Wait 0.1.
	}	
	//Set SteerDirection to HEADING(90,90). // TODO: This was in the old script, need to ensure this can be removed as it would be better if continual refinement can happen during the descent too.

	Set sv_PIDALT:SETPOINT to -0.25. // set just below the surface to ensure touchdown
	Until(ALT:RADAR < 1) or (Ship:Status = "LANDED"){
		ClearScreen.
		Print "Landing".
		Set dtStore to hf_LandingPIDControlLoop(dtStore["lastdt"], dtStore["lastPos"]).
		Wait 0.1.
	}
	Lock Throttle to 0.
	Unlock Throttle.
	Unlock Steering. // Note this was decided on as it will draw power/RCS otherwise and the user can make SAS active if they want to keep the active vessel upright
} //End of Function

//##############################################################################
//##############################################################################
//##############################################################################
//General Functions
//##############################################################################
//##############################################################################
//##############################################################################
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

Function ff_stage_delta_v {
Parameter RSS_partlist is list().
//Calculates the amount of delta v for the current stage    
local m is ship:mass * 1000. // Starting mass (kg)
local g is 9.80665.
local engine_count is 0.
local isp is 0. // Engine ISP (s)
local RSS is False.
local fuelmass is 0.
	// obtain ISP
	LIST engines IN engList.
	for en in engList 
	if en:ignition and not en:flameout {
	  set isp to isp + en:isp.
	  set engine_count to engine_count + 1.
	}
	set isp to isp / engine_count.
	
	// obtain RSS yes or no.
	for res IN Stage:Resources{
		if res:name = "HTP"{
			Set RSS to true.
		}
	}
	Print "RSS" + RSS.
	If RSS = true{
	//for real fuels 
		local fuels is list("LQDOXYGEN", "LQDHYDROGEN", "KEROSENE", "Aerozine50", "UDMH", "NTO", "MMH", 
			"HTP", "IRFNA-III", "NitrousOxide", "Aniline", "Ethanol75", "LQDAMMONIA", "LQDMETHANE", 
			"CLF3", "CLF5", "DIBORANE", "PENTABORANE", "ETHANE", "ETHYLENE", "OF2", "LQDFLUORINE", 
			"N2F4", "FurFuryl", "UH25", "TONKA250", "TONKA500", "FLOX30", "FLOX70", "", "FLOX88", 
			"IWFNA", "IRFNA-IV", "AK20", "AK27", "CaveaB", "MON1", "MON3", "MON10", "MON15", "MON20", "Hydyne", "TEATEB").
		for tankPart in RSS_partlist{
			for res in tankpart:RESOURCES{
				for f in fuels{
					if f = res:NAME{
						SET fuelMass TO fuelMass + ((res:DENSITY*res:AMOUNT)*1000).
						Print "fuel mass" + fuelmass.
					}
				}
			}
		}
	} Else {
	//for stock fuels
		local fuels is list("LiquidFuel", "Oxidizer", "SolidFuel", "MonoPropellant").
		for res in STAGE:RESOURCES{
			for f in fuels{
				if f = res:NAME{
					SET fuelMass TO fuelMass + res:DENSITY*res:AMOUNT.
				}
			}
		}
	}
	//TODO:Think about removing RCS components or making it an input term as this could be a significant proportion of the deltaV which is not used.
	return (isp * g * ln(m / (m - fuelMass))).
}./// End Function

function ff_burn_time {
parameter dV, isp is 0, thrust is 0, engine_count is 0. // For RSS/RO engine values must be given unless they are actually burning.
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

FUNCTION hf_mAngle{
PARAMETER a.
  UNTIL a >= 0 { SET a TO a + 360. }
  RETURN MOD(a,360).
  
}
FUNCTION ff_COMMS {
	PARAMETER event is "activate", stagewait IS 0.1, ShipQtgt is 0.0045.
	// "deactivate"
	IF SHIP:Q < ShipQtgt {
		FOR antenna IN SHIP:MODULESNAMED("ModuleRTAntenna") {
			IF antenna:HASEVENT(event) {
				antenna:DOEVENT(event).
				PRINT event + " Antennas".
				WAIT stageWait.
			}	
		}.
	}
} // End of Function

function ff_mdot {
	parameter isp is 0, thrust is 0, engine_count is 0. // For RSS/RO engine values must be given unless they are actually burning.
	local g is 9.80665.  // Gravitational acceleration constant used in game for Isp Calculation (m/s²)
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
	If engine_count = 0{
		Set engine_count to 1. //return something to prevent error.
	}
	set isp to isp / engine_count.
	set thrust to thrust* 1000.// Engine Thrust (kg * m/s²)
	return (thrust/(g * isp)). //kg of change	
}/// End Function

function ff_Vel_Exhaust {
	parameter isp is 0, thrust is 0, engine_count is 0. // For RSS/RO engine values must be given unless they are actually burning.
	local g is 9.80665.  
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
	If engine_count = 0{
		Set engine_count to 1. //return something to prevent error.
	}
	set isp to isp / engine_count.
	return g *isp.///thrust).
}/// End Function

Function hf_Fall{
	Parameter s_ISP, s_thrust is ship:AVAILABLETHRUST.
//Fall Predictions and Variables
	local gl_Grav is ff_Gravity().
	local fallTime is ff_quadraticPlus(-gl_Grav["Avg"]/2, -ship:verticalspeed, ship:Altitude - SHIP:GEOPOSITION:TERRAINHEIGHT).//r = r0 + vt - 1/2at^2 ===> Quadratic equiation 1/2*at^2 + bt + c = 0 a= acceleration, b=velocity, c= distance
	local fallVel is abs(ship:verticalspeed) + (gl_Grav["Avg"]*fallTime).//v = u + at
	local mdot is ((s_thrust)/(9.80665 * s_ISP)). //Tonnes/s of change
	local fallAcc is s_thrust/(   ship:mass - (  (ff_burn_time( fallVel, s_ISP, s_thrust, 1) * mdot)/2  )   ). // note is is assumed this will be undertaken in a vaccum so the thrust and ISP will not change. Otherwise if undertaken in the atmosphere drag will require a variable thrust engine so small variations in ISP and thrust won't matter becasue the thrust can be adjusted to suit.
	//TODO make allowance for craft mass change during burn to get an average fallAcc. For the moment this will cause th craft to stop too soon.
	local fallDist is (fallVel^2)/ (2*(fallAcc)). // v^2 = u^2 + 2as ==> s = ((v^2) - (u^2))/2a 

	local arr is lexicon().
	arr:add ("fallTime", fallTime).
	arr:add ("fallVel", fallVel).
	arr:add ("fallAcc", fallAcc).
	arr:add ("fallDist", fallDist).
	
	Return(arr).
}

function ff_Gravity{
	Parameter Surface_Elevation is SHIP:GEOPOSITION:TERRAINHEIGHT.
	Set SEALEVELGRAVITY to body:mu / (body:radius)^2. // returns the sealevel gravity for any body that is being orbited.
	Set GRAVITY to body:mu / (ship:Altitude + body:radius)^2. //returns the current gravity experienced by the vessel	
	Set AvgGravity to sqrt(		(	(GRAVITY^2) +((body:mu / (Surface_Elevation + body:radius)^2 )^2)		)/2		).// using Root mean square function to find the average gravity between the current point and the surface which have a squares relationship.
	local arr is lexicon().
	arr:add ("SLG", SEALEVELGRAVITY).
	arr:add ("G", GRAVITY).
	arr:add ("AVG", AvgGravity).
	Return (arr).
}

function ff_quadraticPlus {
	parameter a, b, c.
	return (b - sqrt(max(b ^ 2 - 4 * a * c, 0))) / (2 * a).
}

Function ff_Avionics_off{
	Local partlist is List().
	LIST Parts IN partList. 
	FOR Part IN partList { 
		If PART:HASMODULE("ModuleProceduralAvionics"){
			Print "Proc Avionics" + PART:HASMODULE("ModuleProceduralAvionics").
			Local M is PART:GETMODULE("ModuleProceduralAvionics").
			If M:HasEVENT("Shutdown Avionics"){
				M:DOEVENT("Shutdown Avionics").
			}
		}
	}
}

Function ff_Avionics_on{
	Local partlist is List().
	LIST Parts IN partList. 
	FOR Part IN partList { 
		If PART:HASMODULE("ModuleProceduralAvionics"){
			Print "Proc Avionics" + PART:HASMODULE("ModuleProceduralAvionics").
			Local M is PART:GETMODULE("ModuleProceduralAvionics").
			If M:HasEVENT("Activate Avionics"){
				M:DOEVENT("Activate Avionics").
			}
		}
	}
}

function ff_EccOrbitVel{ //returns the eccentirc orbital velocity of the ship at a specific altitude and sma.
	parameter alt is ship:Altitude.
	parameter sma is ship:orbit:semimajoraxis.
	local vel is sqrt(Body:MU*((2/(alt+body:radius))-(1/sma))).
	return vel.
}
	
function ff_CircOrbitVel{ //returns the circular orbital velocity of the current ship at a specific altitude.
	parameter alt.
	return sqrt(Body:MU/(alt + body:radius)).
}

function hf_ternarySearch {
  parameter f, left, right, absolutePrecision, maxVal is true.
  until false {
    if abs(right - left) < absolutePrecision {
      return (left + right) / 2.
    }
    local leftThird is left + (right - left) / 3.
    local rightThird is right - (right - left) / 3.
    if maxval = true{
			if f(leftThird) < f(rightThird) {
				set left to leftThird.
			} else {
				set right to rightThird.
			}
		}
		if maxval = false{
			if f(leftThird) > f(rightThird) {
				set left to leftThird.
			} else {
				set right to rightThird.
			}
		}
  }
}

function ff_seek {
	parameter t, r, n, p, fitness, fine is False,
			  data is list(t, r, n, p),
			  fit is hf_orbit_fitness(fitness@).  // time, radial, normal, prograde, fitness are the parameters passed in for the node to be found. passes fitness through as a delegate to orbital fitness in this case { parameter mnv. return -mnv:orbit:eccentricity. } is passed through as a local function but any scorring evaluation can be passed through
	set data to ff_optimize(data, fit, 10). // search in 10m/s incriments
	Print "Seek 10".
	set data to ff_optimize(data, fit, 1). // search in 1m/s incriments
	Print "Seek 1".
	If Fine{
		set data to ff_optimize(data, fit, 0.1). // search in 0.1m/s incriments
		Print "Seek 0.1".
	}
	fit(data). //sets the final manuver node and returns its parameters
	wait 0. 
	return data. // returns the manevour node parameters to where the function was called
}/// End Function

function ff_optimize {
	parameter data, fitness, step_size,
	winning is list(fitness(data), data),
	improvement is hf_best_neighbor(winning, fitness, step_size). // collect current node info, the parameter to evaluate, and the incriment size(note: there was a comma here not a full stop if something goes wrong)// a list of the fitness score and the data, sets the first winning node to the original data passed through(note: there was a comma here not a full stop if something goes wrong)// calculates the first improvement node to make it through the until loop
	until improvement[0] <= winning[0] { // this loops until the imporvment fitness score is lower than the current winning value fitness score (top of the hill is reached)
	  set winning to improvement. // sets the winning node to the improvement node just found
	  set improvement to hf_best_neighbor(winning, fitness, step_size). // runs the best neighbour function to find a better node using the current node that is winning
	}
	return winning[1]. // returns the second column of the winning list "(data)", instead of "fitness(data)"
 }/// End Function

 function hf_orbit_fitness {
	parameter fitness. // the parameter used to evaluate fitness
	return {
		parameter data.
		until not hasnode { 
			remove nextnode. // Used to remove any existing nodes
			wait 0. 
		} 
		Print "orb fit create node".
		local new_node is node(
		hf_unfreeze(data[0]), hf_unfreeze(data[1]),
		hf_unfreeze(data[2]), hf_unfreeze(data[3])). //Collects Node parameters from the Frozen Lexicon, presented in time, radial, normal, prograde.
		add new_node. // produces new node in the game
		//Print new_node.
		wait 0.
		return fitness(new_node). // returns the manevour node parameters to where the function was called
	}.
}/// End Function

function hf_best_neighbor {
	parameter best, fitness, step_size. // best is the winning list and contains two coloumns
	for neighbor in hf_neighbors(best[1], step_size) { //send to neighbours function the node information and the step size to retune a list of the neighbours
		local score is fitness(neighbor). // Set up for the score to analyse what is returned by neigbour. This is what finds the fitness score by looking at the mnv node orbit eccentricity that was passed through as delegate into fitness
		if score > best[0] set best to list(score, neighbor). //if the eccentricity score of the neighbour is better save the mnv result to best
	}
	return best. //return the best result of all the neighbours
}/// End Function

function hf_neighbors {
parameter data, step_size, results is list().
for i in range(0, data:length) if not hf_frozen(data[i]) { // for each of the data points sent through check if the data is frozen (i.e. is a value that should not be changed). 
	local increment is data:copy.
	local decrement is data:copy.
	set increment[i] to increment[i] + step_size. //for each of the data points allowed to be changed increment up by the step size
	set decrement[i] to decrement[i] - step_size. //for each of the data points allowed to be changed increment up by the step size
	results:add(increment).
	results:add(decrement).
}
return results. // Return the list of neighbours for the data that can be changed (i.e. unfrozen)
}  /// End Function

function ff_freeze {
	parameter n. 
	return lex("frozen", n).
}/// End Function

	  // identifies if the paramter is frozen
function hf_frozen {
	parameter v. 
	return (v+""):indexof("frozen") <> -1.
}/// End Function

// Returns paramters from the frozen lexicon
function hf_unfreeze {
	parameter v. 
	if hf_frozen(v) return v["frozen"]. 
	else return v.
}/// End Function

function hf_LatScore{
  parameter t.
	Local result is abs(Body:GEOPOSITIONOF(positionAT(ship, t)):lat).
	Print "Lat: " +result.
  	return result.
}
function hf_LngScore{
  parameter t.
	Local result is abs(op_lng - Body:GEOPOSITIONOF(positionAT(ship, t)):lng).
	Print "Lat: " +result.
  	return result.
}
function hf_PEScore{
  parameter mnv.
	Local result is -abs(mnv:orbit:periapsis -endPE).
	Print result.
  return result.
}