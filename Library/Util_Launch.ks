
/////Dependant libraies

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////
	// local Util_Launch is lex(
		// ff_LaunchAzimuth,
		// ff_launchwindow,
		// ff_FlightAzimuth,
		//	ff_CheckAbort,
		// 	ff_Abort
	// ).
	
////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////

//TODO:	Add in a launch window calculator. look at the KOS-Stuff_master launch window file for inspiration, also a bit of code has been added below but has not been checked/reworked.
//// http://www.movable-type.co.uk/scripts/latlong.html is a good source for bearing information on goecords on sphere


////////////////////////////////////////////////////////////////
// Credit : http://www.orbiterwiki.org/wiki/Launch_Azimuth
//Calculates the Azimuth required at Launch to meet a specific inclination on a body
Function ff_LaunchAzimuth {

PARAMETER targetInclination, targetAltitude.

	PRINT "Finding Azimuth".

	SET launchLoc to SHIP:GEOPOSITION.
	SET initAzimuth TO arcsin(max(min(cos(targetInclination) / cos(launchLoc:LAT),1),-1)). //Sets the intital direction for launch to meet the required azimuth
	SET targetOrbitSpeed TO SQRT(SHIP:BODY:MU / (targetAltitude+SHIP:BODY:RADIUS)). // Sets the orbital speed based on the target altitude
	SET bodyRotSpeed TO (SHIP:BODY:RADIUS/SHIP:BODY:ROTATIONPERIOD). //Sets the rotational velocity at the equator
	SET rotvelx TO targetOrbitSpeed*sin(initAzimuth) - (bodyRotSpeed*cos(launchLoc:LAT)). //Sets the x vector required adjusted for launch site location away from the equator
	SET rotvely TO targetOrbitSpeed*cos(initAzimuth). //Sets the y Vector required
	SET azimuth TO (arctan(rotvelx / rotvely)). //Sets the adjusted inclinationation angle based on the rotation of the planet
	//SET azimuth TO -(arctan(rotvelx / rotvely))+180. //Sets the adjusted inclinationation angle based on the rotation of the planet // TODO: full check on what azimuths are acceptable to input
	IF targetInclination < 0 {
		SET azimuth TO 180-azimuth.
	} //Normalises to a launch in the direction of body rotation
	PRINT ("Launch Azimuth:" + azimuth).    
	RETURN azimuth.   
} // End of Function



/////////////////////////////////////////////////////////////////////////////////////

//Credits: // https://github.com/KK4TEE/kOSPrecisionLand
// This function calculates the direction a ship must travel to achieve the
// target inclination given the current ship's latitude and orbital velocity.
// Written by BriarAndRye <https://www.reddit.com/r/Kos/comments/3a5hjq>
// Modified to use the target insertion velocity to compute the inclination
// instead of the ideal circular orbit velocity - this allows insertion into
// elliptical orbits.


function ff_FlightAzimuth {
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
	
/////////////////////////////////////////////////////////////////////////////////////

// Source: https://github.com/TheBassist95/Kos-Stuff (rearranged)

function ff_launchwindow{
Parameter target , ascendLongDiff is 0.2.
	local IncPoss is true.
	local incDiff is 0.
	Local offset is 0.
	
	//  Lock the angle difference to the solar prime  
	lock DeltaLAN to mod((360-target:orbit:lan) + body:rotationangle,360). // gets the modulas (remainder from integer division) to get the angle to the LAN
	
	// Obtain the ship Longitude in a 360 degree reference (default is -180 to 180)
	if longitude < 0{
		local shiplon is abs(longitude).
	}
	else {
		local shiplon is 360-longitude.
	}
	if target:orbit:inclination < abs(latitude) { //If the inclination of the target is less than the lattidue of the ship it will not pass over the site as the max latitude of its path is too low.
		Set IncPoss to False.
		Set incDiff to ship:orbit:inclination-target:orbit:inclination.
		Print "Latitude unable to allow normal Launch to inclination!!!".
		Print incDiff.
		Print ship:orbit:inclination.
		Print target:orbit:inclination.
		Print IncPoss.
		wait 5.
	}
	else {// A normal launch is possible with the target passing overhead.
		Local offset is hf_tricalc(target).
	}
	
	local diffPlaneAng is 1000. //Set higher than the max inclination so it enters the loop
	local newdiffPlaneAng is 1000.
	Print IncPoss.
	until diffPlaneAng < (incDiff + ascendLongDiff){
		if IncPoss = False {
			Set diffPlaneAng to vang(hf_normalvector(ship),hf_normalvector(target)).// finds the angle between the orbital planes
			Print "Relative Inclination:   " + diffPlaneAng.
			print "Minimum R. Inclination: " + incDiff.
		}
		else{
			//Set diffPlaneAng to vang(hf_normalvector(ship),hf_normalvector(target)).
			Set diffPlaneAng to abs((shiplon + offset) - DeltaLAN).
			print "Relative LAN to Target: " + diffPlaneAng.
		}
		if diffPlaneAng <(incDiff + ascendLongDiff) +0.4 and diffPlaneAng > (incDiff + ascendLongDiff) + 0.2{
			set warp to 1.
			Print 2.
		}
		else if diffPlaneAng <(incDiff + ascendLongDiff) +1 and diffPlaneAng > (incDiff + ascendLongDiff) + 0.4{
			set warp to 2.
			Print 3.
		}
		else if diffPlaneAng < 10 and diffPlaneAng > (incDiff + ascendLongDiff) + 1{
			set warp to 3.
			Print 4.
		}
		Else if diffPlaneAng > 10{
			set warp to 4.
			Print 5.
		}

		wait 1.
	}
	set warp to 0.
	wait 5.
	return vang(hf_normalvector(ship),hf_normalvector(target)).
}

////////////////////////////////////////////////////////////////

function ff_CheckAbort{
	Parameter abvert is 5, vert is 0.1, altsp is 500, airsp is 5, Qsp is 0.05, ang is 5.
	//Print "Checking low vs: " + (verticalspeed < vert). 
	//Print "Checking low alt: " + (alt:radar < altsp) . 
	//Print "Checking low airsp: " + (ship:airspeed > airsp). 

	If (verticalspeed < vert) and (alt:radar < altsp) and (ship:airspeed > airsp){ ///checks to see if the rocket is heading downwards at low altitudes
		Print"Low Airspeed and altitude abort".
		ff_Abort(abvert, altsp, Qsp).
	}
	//Print "Checking angle: " + ((SHIP:Q > Qsp) and (ship:airspeed > airsp)). 
	If (SHIP:Q > Qsp) and (ship:airspeed > airsp) {
		if vang(SHIP:FACING:FOREVECTOR, srfprograde:vector) > ang{
			Print"AoA abort".
			ff_Abort(abvert, altsp, Qsp).
		}
	}
	//Print "Checking engines: " + (ship:airspeed > airsp). 
	Local englist is List().
	LIST engines IN engList.
	FOR eng IN engList { 
		If eng:IGNITION and (ship:airspeed > airsp){
			if eng:THRUST < 0.95 * eng:AVAILABLETHRUST{
				Print"Engine Failure abort".
				ff_Abort(abvert, altsp, Qsp).
			}
		}
	}
}

////////////////////////////////////////////////////////////////

Function ff_Abort {
	Parameter vert is 5, altsp is 500, Qsp is 0.05.
	//if aborted = true {return.}
	Local CurrCPU is CORE:TAG.
	Print "Engine Shutdown!!!".
	lock throttle to 0.
	lock PILOTMAINTHROTTLE to 0.
	local PROCESSOR_List is list().
	LIST PROCESSORS IN PROCESSOR_List. // get a list of all connected cores
	for Processor in PROCESSOR_List {
		if NOT (Processor:TAG = CurrCPU){ //checks to see if another CPU is present to shutdown
			Processor:DEACTIVATE().
			Set aborted to True.
			Print "Craft Aborted".
		}
	}
	//Local englist is List().
	LIST engines IN engList.
	FOR eng IN engList { 
		If eng:IGNITION {
			eng:shutdown.
		}
	}
	wait 0.1.
	lock steering to Prograde.
	abort on.
	Print "Holding for seperation".
	wait 1.
	until (SHIP:Q < Qsp) and ((alt:radar > altsp) or (verticalspeed < vert )){
		wait 0.5.
	}
	Print "Brakes on".
	brakes on.
	wait 0.5.
	lock steering to Retrograde.
}


////////////////////////////////////////////////////////////////
//Helper Functions
////////////////////////////////////////////////////////////////

// Source: https://github.com/TheBassist95/Kos-Stuff


function hf_tricalc{
	Parameter target.
	local a is latitude.
	local alpha is target:orbit:inclination.
	local b is 0.
	local c is 0.
	local bell is 90.
	local gamma is 0.
	if sin(a)*sin(bell)/sin(alpha) >1 {
		set b to 90.
		}
	else{
		set b to arcsin(sin(a)*sin(bell)/sin(alpha)).
	}
	set c to 2*arctan(tan(.5*(a-b))*(sin(.5*(alpha+bell))/sin(.5*(alpha-bell)))).
	return c.
}

////////////////////////////////////////////////////////////////

// Source: https://github.com/TheBassist95/Kos-Stuff
function hf_normalvector{
	parameter ves.
	set vel to velocityat(ves,time:seconds):orbit.
	set norm to vcrs(vel,ves:up:vector). 
	return norm:normalized.// gives vector pointing towards centre of body from ship
}


