CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
SET TERMINAL:HEIGHT TO 65.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:BRIGHTNESS TO 0.8.
SET TERMINAL:CHARHEIGHT TO 10.
// Get Mission Values

Set SHIP:CONTROL:PILOTMAINTHROTTLE to 0.

Global runmode is 0.

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



Global gv_ext is ".ks".

PRINT ("Initialising libraries").
//Initialise libraries first

FOR file IN LIST(
	"OrbMnvNode" + gv_ext,
	"Util_Vessel"+ gv_ext,
	"Util_Orbit"+ gv_ext,
	"Util_Engine"+ gv_ext,
	"Util_Landing" + gv_ext,
	"Landing_vac" + gv_ext)
	{ 
		RUNONCEPATH("0:/Library/" + file).
		wait 0.001.	
	}

Global gl_ISP is 311.
Global gl_Thrust is 45.
Global gl_Engines is 1.

//##############################################
If runmode = 0.1{
	Local counter is 0.
	Until counter > 5{
		Clearscreen.
		Print "Put node above landing location: " + (5-counter).
		wait 1.
		Set Counter to counter +1.
	}
	Global gl_TargetLatLng is Body:GEOPOSITIONOF(positionAT(ship, nextnode:eta)).
	Print gl_TargetLatLng.
	wait 5.
	remove nextnode.
	Set runmode to 0.2.
}
//Descent to height
If runmode = 0.2{
//work out when oppisite the landing site and conduct a burn to put PE at 50,000 feet (15,000 m)
	Global op_lng is gl_TargetLatLng:lng *-1.//180 used as usually want around 10 degrees before for moon
	Print "op_lng: "+op_lng.
	Local start is time:seconds + 60.
	Local end is orbit:period + time:seconds + 60.
	local startSearchTime is hf_ternarySearch(
		hf_LngScore@,
		start, end, 1, false
	).
	local transfer is ff_seek(ff_freeze(startSearchTime), ff_freeze(0), ff_freeze(0), 10, hf_PEScore@, True).
	set runmode to 0.3.
}
If runmode = 0.3{
//conduct burn
	wait 10.
	Until ((nextnode:eta) < 120){
		Clearscreen.
		Print "Reduction burn in: " + (nextnode:eta - 120).
		wait 1.
	}
	Print "Orbit reduction Started".
	ff_partslist("LEMD"). //stand partslist create for engines using node burns
	Local Starttime is time:seconds + nextnode:eta - ff_burn_time(nextnode:burnvector:mag/2).
	Print "Start time is: " + Starttime.
	ff_Alarm(Starttime).
	Until Starttime < (time:seconds + 60){
		wait 1.
	}
	ff_Node_exec(Starttime, 2).
	lock throttle to 0.
	wait 1.
	Print "Finished Descent Burn".
	set runmode to 1.0.
}
////Commence Landing routine (based on auto or manual node time from above)
If runmode = 1.0{
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
	local p_time is Lexicon().
	local p_time is ff_ESTProfileLand(gl_LandTime).
	Print gl_LandTime.
	//local startTime is (gl_LandTime - (p_time["profiletime"]/3)).
	local startTime is (gl_LandTime - (p_time["profiletime"]/(p_time["acc"]))).// acc is 4.99
	//local startTime is (gl_LandTime - (p_time["dist"]/ship:velocity:surface:mag)).
	Set acc to (ship:availablethrust* 1000)/(ship:mass * 1000). //the acceleration of the ship in one second
	Set acc_time to p_time["VerVel"]/acc.
	Set StartTime  to StartTime + acc_time.
	Print "startTime: " + startTime. 
	Print (startTime - time:seconds).
	wait 10.
	//Pre for Landing
	Until ((startTime - time:seconds) - 180) < 0{
		Clearscreen.
		Print "Descent burn in: " + (startTime - time:seconds -120).
		Print hf_geoDistance (gl_TargetLatLng, SHIP:GEOPOSITION).
		wait 1.
	}
	Set warp to 0.
	Lock steering to retrograde.
	RCS on.
	///Wait until distance correct
	Until ((startTime - time:seconds) - 120) < 0{
	//Until hf_geoDistance (gl_TargetLatLng, SHIP:GEOPOSITION) < p_time["dist"] + (p_time["VerVel"]*acc_time) +(0.5*acc*acc_time^2){ ///s = vt + at^2/2, t = v/a
		Clearscreen.
		Print "Burn Start Distance: " + (p_time["dist"] + (p_time["VerVel"]*acc_time) +(0.5*acc*acc_time^2)).
		Print "Target Distance: " +hf_geoDistance (gl_TargetLatLng, SHIP:GEOPOSITION).
		wait 1.
	}
	Print "Power Descent Started".
	wait 1.
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
	ff_CAB(time:seconds, 10000, 750, -75, 15).
	ff_CAB(time:seconds, 5000, 400, -40, 25).
	ff_CAB(time:seconds, 1000, 100, -15, 45).
	ff_CAB(time:seconds, 100, 10, -5, 65).
	Print "CAB end".
	Set runmode to 2.0.
}

//manual land the craft
If runmode = 2.0{
	set Throttle to 0.1.
	unlock throttle.
	unlock steering. 
	SAS on.
	wait 0.5.
	Shutdown.
}

//commence hover Landing routine
If runmode = 3.0{
	Global gl_shipLatLng is ship:Geoposition.
	if NOT (defined gl_TargetLatLng){
		Global gl_TargetLatLng is ship:Geoposition.
	}
	Print "hover 750".
	Lock Throttle to 1.
	ff_hoverLand(750, gl_TargetLatLng).
	Print "Shutdown routine".
	SET SHIP:CONTROL:FORE to 0.
	lock throttle to 0.
	RCS off.
	wait 40.
	Shutdown.
}

///// Take off routine (wait for target to be approx 50 degree (40 mark on Nav ball) prior to being over head. 
If runmode = 4.0{ //CSM should be in a 100 x 100km orbit with an orbit of 1:57 hour:min. Launch when the MJ intercept time is plus 3 min. and it should take no more than 3 orbits to catch up after you have moved into a 100km x 80 km orbit to intercept
	unlock all.
	Set SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
	local tgt_az is ff_FlightAzimuth(target:orbit:inclination, 1650, -1).//-1 if clockwise from south pole, 1 if clockwise from north pole
	Print "tgt_az: " + tgt_az.
	set tgt_az to hf_mAngle(tgt_az).
	Print "tgt_az: " + tgt_az.
	wait 1.0.
	RCS on.
	Stage.
	lock throttle to 1.
	wait 0.1.
	Stage.
	wait 0.1.
	Stage.
	Print "lift off: "+ altitude.
	LOCK STEERING to HEADING(tgt_az,90). // Lock in upright posistion and fixed rotation
	until ALT:RADAR > 20{
		wait 1.
	}
	Print "Move to 45: "+ altitude.
	LOCK STEERING to HEADING(tgt_az,45).
	until ((ALT:RADAR > 4000) or (altitude > 8000)) and (SHIP:GROUNDSPEED > 150){
		wait 1.
	}
	Print "Move to 30: "+ altitude.
	LOCK STEERING to HEADING(tgt_az,30).
	until ((ALT:RADAR > 10000) or (altitude > 20000)) and (SHIP:GROUNDSPEED > 300) {
		wait 1.
	}
	Print "Move to 10: "+ altitude.
	LOCK STEERING to HEADING(tgt_az,10).
	until (Ship:apoapsis > 80000) and (SHIP:GROUNDSPEED > 1200){
		wait 0.1.
	}
	Print "Move to Transfer: "+ altitude.
	lock throttle to 0.
	Set SHIP:CONTROL:PILOTMAINTHROTTLE to 0.
	Set runmode to 5.0.
	RCS off.
}

If runmode = 5.0{
	local Cirdv is ff_CircOrbitVel(ship:orbit:apoapsis) - ff_EccOrbitVel(ship:orbit:apoapsis, ship:orbit:semimajoraxis).
	Set n to Node(time:seconds + ETA:APOAPSIS,0,0,Cirdv).
	Add n.
	Print "Run mode is:" + runMode.
	ff_partslist("LEMA"). //stand partslist create for engines using node burns
	Local Starttime is time:seconds + nextnode:eta - ff_burn_time(nextnode:burnvector:mag/2).
	Print "Start time is: " + Starttime.
	ff_Alarm(Starttime).
	Until Starttime < (time:seconds + 60){
		wait 1.
	}
	RCS on.
	ff_Node_exec(Starttime, 2).
	lock throttle to 0.
	unlock steering.
	RCS off.
	wait 1.0.
}

If runmode = 6.0{
	Local counter is 0.
	Until counter > 10{
		Clearscreen.
		Print "Refine Node before: " + (10-counter).
		wait 1.
		Set Counter to counter +1.
	}
	ff_partslist("LEMA"). //stand partslist create for engines using node burns
	Local Starttime is time:seconds + nextnode:eta - ff_burn_time(nextnode:burnvector:mag/2).
	Print "Start time is: " + Starttime.
	ff_Alarm(Starttime).
	Until Starttime < (time:seconds + 60){
		wait 1.
	}
	ff_Node_exec(Starttime, 1, 1).
	lock throttle to 0.
	unlock steering.
	RCS off.
	Set runmode to 7.0.
}

If runmode = 7.0{
	Shutdown.
}

//##############################################################################
//##############################################################################
//##############################################################################
//General Functions
//##############################################################################
//##############################################################################
//##############################################################################

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

function ff_FlightAzimuth {
	parameter inc, V_orb, dn is 1. // target inclination

	// project desired orbit onto surface heading
	Print "inc:"+ inc.
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
	local vel_n is vdot(V_corr, ship:north:vector)*dn.
	local vel_e is vdot(V_corr, heading(90,0):vector).
	
	// calculate compass heading
	local az_corr is arctan2(vel_e, vel_n).
	return az_corr.

}// End of Function