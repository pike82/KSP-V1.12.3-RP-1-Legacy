///// Download Dependant libraies


///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////
	// ff_Circ,
	// ff_adjper,
	// ff_adjapo,
	// ff_adjeccorbit,
	// ff_AdjOrbIncUp,
	// ff_AdjOrbIncDown,
	// ff_AdjOrbIncGeo,
	// "AdjPlaneInc", ff_AdjPlaneInc@
//TODO: Create a file function that seeks out both an optimum Apoapsis and Periapsis to define an eccentic orbit.
//TODO: look at the KOS-Stuff_master manu file for possible ideas on reducing and bettering the AN code and manervering code.
//TODO look at the hill climb stuff once a PEG ascent program is completed.		
////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////

//TODO: Change to work with negative inclinations.
Function ff_Circ {
Parameter APSIS is "per", EccTarget is 0.005, IncTar is 1000.
	Print "Creating Circularisation, checking to see if vessel is in space".
	until Ship:Altitude > (0.95 * ship:body:atm:height) {
		Wait 0.1. //ensure effectively above the atmosphere before creating the node
	}

	If APSIS="per" or obt:transition = "ESCAPE"{ // this either take the variable or overides the varible if the orbit is an escape trajectory to ensure it is performed at the periapsis
		if ship:orbit:semimajoraxis > 0 {
			set Cirdv to -1*(ff_EccOrbitVel(ship:orbit:periapsis, ship:orbit:semimajoraxis) - ff_CircOrbitVel(ship:orbit:periapsis)).
		}
		Else{
			Print "Escape Trajectory Detected".
			set Cirdv to ff_EccOrbitVel(ship:orbit:periapsis, ship:orbit:semimajoraxis) - ff_CircOrbitVel(ship:orbit:periapsis).
			If Cirdv > 0{
				set Cirdv to -Cirdv. //ensures that a capture dv is obtained regardless of approach.
			}
		}
		Print "Seeking Per Circ".
		Print "Min Dv Required:"+ Cirdv.
		If IncTar = 1000{ // don't try to change the inclination
			Set n to Node(time:seconds + ETA:PERIAPSIS,0,0,Cirdv).
			Add n.
		}
		Else{
		// use the following to also conduct a change of inclination at the same time
			hf_Seek_low(hf_freeze(time:seconds + ETA:PERIAPSIS), hf_freeze(0), 0, Cirdv, 
				{ 	parameter mnv. 
					return -mnv:orbit:eccentricity - (abs(IncTar-mnv:orbit:inclination)/2).
				}//needs to be changed to deal with negative inclinations
			).
		}//end else
	}
	IF APSIS="apo"{
		set Cirdv to ff_CircOrbitVel(ship:orbit:apoapsis) - ff_EccOrbitVel(ship:orbit:apoapsis, ship:orbit:semimajoraxis).
		Print "Seeking Apo Circ".
		Print "Min Dv Required:"+ Cirdv.
		If IncTar = 1000{ // don't try to change the inclination
			Set n to Node(time:seconds + ETA:APOAPSIS,0,0,Cirdv).
			Add n.
		}
		Else{
	// use the following in the future to also conduct a change of inclination at the same time
			hf_Seek_low(hf_freeze(time:seconds + ETA:APOAPSIS), hf_freeze(0), 0, Cirdv, 
				{ 	parameter mnv. 
					return -mnv:orbit:eccentricity - (abs(IncTar-mnv:orbit:inclination)/2).
				} //needs to be changed to deal with negative inclinations
			).
		}
	}
} /// End Function

///////////////////////////////////////////////////////////////////////////////////		

Function ff_adjper {
Parameter Target_Perapsis, Target_Tolerance is 500, IncTar is 1000, starttime is (time:seconds + ETA:PERIAPSIS).
	Print "Adusting Per".
	set newsma to (ship:orbit:apoapsis+(body:radius*2)+Target_Perapsis)/2.
	set Edv to ff_EccOrbitVel(ship:orbit:apoapsis, newsma)- ff_EccOrbitVel(ship:orbit:apoapsis).
	print "Estimated dv:"+ Edv.
	If IncTar = 1000{
		Set n to Node(starttime,0,0,Edv).
		Add n.
	}
	Else{
	// use the following in the future to also conduct a change of inclination at the same time
		hf_Seek_low(hf_freeze(starttime), hf_freeze(0), 0, Edv, 
			{ 	parameter mnv. 
				if ff_tol(mnv:orbit:periapsis, Target_Perapsis , Target_Tolerance) return 0. 
				return -(abs(Target_Perapsis-mnv:orbit:periapsis) / Target_Perapsis)- (abs(IncTar-mnv:orbit:inclination)/2). 
			}
		).
	}
}	/// End Function

///////////////////////////////////////////////////////////////////////////////////
	
Function ff_adjapo {
Parameter Target_Apoapsis, Target_Tolerance is 500, IncTar is 1000, starttime is (time:seconds + ETA:PERIAPSIS).
	Print "Adusting Apo".
	set newsma to (ship:orbit:periapsis+(body:radius*2)+Target_Apoapsis)/2.
	set Edv to ff_EccOrbitVel(ship:orbit:periapsis, newsma)- ff_EccOrbitVel(ship:orbit:periapsis).
	print "Estimated dv:" + Edv.
	If IncTar = 1000{
		Set n to Node(starttime,0,0,Edv).
		Add n.
	}
	Else{
	// use the following in the future to also conduct a change of inclination at the same time
		hf_Seek_low(hf_freeze(starttime), hf_freeze(0), 0, Edv, 
			{ 	parameter mnv. 
				if ff_tol(mnv:orbit:apoapsis, Target_Apoapsis , Target_Tolerance) return 0. 
				return -(abs(Target_Apoapsis-mnv:orbit:Apoapsis) / Target_Apoapsis)- (abs(IncTar-mnv:orbit:inclination)/2). 
			}
		).
	}
}	/// End Function

///////////////////////////////////////////////////////////////////////////////////

//TODO: Use Position at to make this more efficent and accurate by undertaking the burn when the ship will be at the new periapsis or apoapsis (depends on if more or less energy is required via SMA)
//TODO: Use the master Stuff manu file as an example to determine the perpendicualr vector at the burn point so the dV and node can be created without the hill climb.
// This will only get the correct orbit if teh ship is below the target apoapsis at the time of the burn, otherwise the apoapsis cannot be lowered enough.
	Function ff_adjeccorbit {
	Parameter Target_Apoapsis, Target_Perapsis, StartingTime is time:seconds + 300, Target_Tolerance is 500, int_Warp is false.
		Print "Adusting Eccentirc orbit". 
		Print Target_Apoapsis.
		Print Target_Perapsis.
		Print StartingTime.
		hf_Seek_low(
			hf_freeze(StartingTime), 0, hf_freeze(0), 0, { 
				parameter mnv. 
				if ff_tol(mnv:orbit:apoapsis, Target_Apoapsis , Target_Tolerance) 
				and ff_tol(mnv:orbit:periapsis, Target_Perapsis , Target_Tolerance)return 0. 
				return -(abs(Target_Apoapsis-mnv:orbit:Apoapsis))-(abs(Target_Perapsis-mnv:orbit:periapsis)). 
			}
		).
	}	/// End Function

///////////////////////////////////////////////////////////////////////////////////
	
Function ff_AdjOrbIncUP {
Parameter Target_Inc.
	Print "Increasing inc".
	hf_Seek_low(
		hf_freeze(time:seconds + ETA:APOAPSIS), 0, 0, 0, { 
			parameter mnv. return 	-(abs(mnv:orbit:inclination - Target_Inc)*1000000)						
									- abs(ship:orbit:apoapsis-mnv:orbit:apoapsis) 
									- abs(ship:orbit:periapsis - mnv:orbit:periapsis). 
		}
	).
}	/// End Function

///////////////////////////////////////////////////////////////////////////////////
//TODO: Make this better as at the moment it just conducts the change at 0 lattitude.
Function ff_AdjOrbIncDown {
Parameter Target_Inc.
	Print "Decreasing inc".
  	local LatTime is hf_ternarySearch(
    	hf_LatScore@,
    	time:seconds + 60, //start
    	orbit:period + time:seconds + 60, //end
    	1, false
  	).
	hf_Seek_low(
		hf_freeze(time:seconds + ETA:APOAPSIS), 0, 0, 0, { 
			parameter mnv. return 	-(abs(mnv:orbit:inclination - Target_Inc)*1000000)						
									- abs(ship:orbit:apoapsis-mnv:orbit:apoapsis) 
									- abs(ship:orbit:periapsis - mnv:orbit:periapsis). 
		}
	).
}	/// End Function

///////////////////////////////////////////////////////////////////////////////////
//TODO: Make this better as at the moment it just conducts the change at 0 lattitude.
Function ff_AdjOrbGeo {
Parameter Target_Inc is ship:Orbit:INCLINATION, tgtAp is ship:orbit:apoapsis, tgtPe is ship:orbit:periapsis, inc_mod is 1000000, ap_mod is 1, pe_mod is 1.// note you can make a parameter mod 0 if you don't want it to matter
	Print "GEO Adjusting".
  	local LatTime is hf_ternarySearch(
    	hf_LatScore@,
    	time:seconds + 60, //start
    	orbit:period + time:seconds + 60, //end
    	1, false
  	).
	hf_Seek(
		hf_freeze(LatTime), hf_freeze(0), 0, 0, { 
			parameter mnv. return 	-abs((mnv:orbit:inclination - Target_Inc)*inc_mod)						
									- abs((tgtAp-mnv:orbit:apoapsis)*ap_mod) 
									- abs((tgtpe - mnv:orbit:periapsis)*pe_mod). 
		}
	).
}	/// End Function

///////////////////////////////////////////////////////////////////////////////////

Function ff_AdjPlaneInc {
Parameter Target_Inc, target_Body, Target_Tolerance is 0.05.
	Print "Adusting inc plane".
	Local UT is ff_Find_AN_UT(target_Body).
	Wait 1.
	hf_Seek_low(
		hf_freeze(UT), 0, 0, 0, { 
			parameter mnv. 				
			if ff_tol((mnv:orbit:inclination - target_Body:orbit:inclination), Target_Inc, Target_Tolerance){
				return
				- (mnv:DELTAV:mag) 
				- abs(ship:orbit:apoapsis-mnv:orbit:apoapsis) 
				- abs(ship:orbit:periapsis - mnv:orbit:periapsis). 
			} 
			Else{
				return
				-(abs(Target_Inc - (mnv:orbit:inclination - target_Body:orbit:inclination))*1000000)
				- (mnv:DELTAV:mag) 
				- abs(ship:orbit:apoapsis-mnv:orbit:apoapsis) 
				- abs(ship:orbit:periapsis - mnv:orbit:periapsis).
			}
		}
		, True
	).
	wait 1.
	
	Print "tgt LAN " + target_Body:orbit:LAN.
	Print "Ship LAN " + Ship:orbit:LAN.
	Print "Check LAN Diff".
	Print mod(720 + target_Body:orbit:LAN + Ship:orbit:LAN,360).
	If mod(720 + target_Body:orbit:LAN + Ship:orbit:LAN,360) < 90 or mod(720 + target_Body:orbit:LAN + Ship:orbit:LAN,360) > 270{
		local oldnode is nextnode.
		local newnode is node(time:seconds + oldnode:ETA, oldnode:RADIALOUT, -oldnode:NORMAL, oldnode:PROGRADE).
		Print oldnode:NORMAL.
		Remove nextnode.
		Add newnode.
		Print "Normal Burn inversed".
	}
}	/// End Function

///////////////////////////////////////////////////////////////////////////////////
// Note: this assumes you are already roughly at the period desired, and only reqquires fine tuning via RCS thrusters. This fine tuning will be done at a specifed altitude (i.e Apoapsis) .
Function ff_FineAdjPeriod {
Parameter Target_Per, Tol.
	RCS on.
	
	Lock Steering to Ship:Prograde + R(0,90,0). //set to radial
	wait 10. //allow time for rotation.
	Local Curr_period is Ship:orbit:Period .
	Local Speed is min(1, max(-1, Curr_period - Target_Per)).
	local vec is V(0,0,Speed ).
	Print Speed.
	print vec.
	Until abs(Curr_period - Target_Per) < Tol{
		SET SHIP:CONTROL:TRANSLATION to (vec) .
		Clearscreen.
		Print "Target Period: " + Target_Per.
		Print "Current Period: " + Curr_period.
		Print "Period Diff: " + abs(Curr_period - Target_Per).
		Print "Speed : " + Speed.
		Set Curr_period to Ship:orbit:Period .
		Set Speed to min(1, max(-1, Curr_period - Target_Per)).
		Set vec to V(0,0,Speed ).
		Print vec.
		wait 0.01.
	}
	RCS off.
}	/// End Function
	
///////////////////////////////////////////////////////////////////////////////////
// This return the orbital altitude of the missing APO or PER depending on what alt value you use .
Function ff_Obit_sync {
Parameter target_orbit_period, Num_Sat, alt.

	local Orbit_period is target_orbit_period - (target_orbit_period/Num_Sat).//ie. Target orbit period of 3000 secs with three sats will aim for an orbit of 2000 secs
	local sma is (  
					(
					(body:mu*(Orbit_period^2)) /
					(4*(constant():pi^2)  )
					)
					^ (1/3)
				).
	
	Return ((2*sma)-(alt+body:radius))-body:radius.
}	/// End Function

///////////////////////////////////////////////////////////////////////////////////
Function ff_Find_AN_INFO { // returns parameters related to the ascending node of the current vessel and a target vessel.
	parameter tgt.
	///Orbital vectors
	local ship_V is ship:obt:velocity:orbit.//:normalized * 9000000000.
	local tar_V is tgt:obt:velocity:orbit.//:normalized * 9000000000.

	///Position vectors
	Local ship_r is ship:position - body:position.
	Local tar_r is tgt:position - body:position.

	////plane normals also known as H or angular momentum
	local ship_N is vcrs(ship_V,ship_r).//:normalized * 9000000000.
	local tar_N is vcrs(tar_V,tar_r).//:normalized * 9000000000.

	/// AN vector which is perpendicular to the plane normals
	set AN to vcrs(ship_N,tar_N):normalized. // the magnitude is irrelavent as it is a combination of parralellograms which has not real meaning
	Set AN_inc to vang(ship_N,tar_N). // the inclination change angle

	local arr is lexicon().
	arr:add ("ship_V", ship_V).
	arr:add ("ship_r", ship_r).
	arr:add ("ship_N", ship_N).
	arr:add ("tar_V", tar_V).
	arr:add ("tar_r", tar_r).
	arr:add ("tar_N", tar_N).
	arr:add ("AN", AN).
	arr:add ("AN_inc", AN_inc).
	
	Return (arr).
	
}/// End Function
///////////////////////////////////////////////////////////////////////////////////

Function ff_Find_AN_UT { // Finds the time to the ascending node of the current vessel and a target vessel/moon.
//TODO: Remove redundant code relating to sector adjustment once fully tested.
//TODO: Remove redundant code relating to Ship TA and AN Eccetric anomoly and Mean anomoly once the time to PE code is fully tested.
//TODO: Remove redundant array call from AN info.
	parameter tgt.
	Print "Finding AN/DN..".		  
	//Conduct manever at the AN or DN to ensure inclination	is spot on and low dv.
	local arr is lexicon().
	Set arr to ff_Find_AN_INFO(tgt).
	// Set ship_V to arr ["ship_V"].
	// Set ship_r to arr ["ship_r"].
	// Set ship_N to arr ["ship_N"].
	// Set tar_V to arr ["tar_V"].
	// Set tar_r to arr ["tar_r"].
	// Set tar_N to arr ["tar_N"].
	Set AN to arr ["AN"].
	Set AN_inc to arr ["AN_inc"].

	//Current Ship Information.
	Set Ship_e to Ship:orbit:Eccentricity.
	Set Ship_Per to Ship:orbit:Period.
	Set ship_eta_apo to eta:apoapsis.
	Set ship_eta_PE to eta:periapsis.
	Set Ship_a to ship:orbit:SEMIMAJORAXIS.

	Set AN_True_Anom to Constant:DegtoRad*(ff_TAvec(AN)).
	Print "AN True Anom alt Rad" + AN_True_Anom.

	Set AN_Ecc_Anom to ff_EccAnom(Ship_e, AN_True_Anom).
	Print "AN Ecc Anom Rad" + AN_Ecc_Anom.
	
	Set AN_Mean_Anom to ff_MeanAnom (Ship_e, AN_Ecc_Anom).
	Print "AN Mean Anom Rad" + AN_Mean_Anom.

	Set AN_time_From_PE to ff_TAtimeFromPE(Constant:RadtoDeg*AN_True_Anom,Ship_e).
	Print "AN_time_From_PE: " + AN_time_From_PE.
	
	local AN_time is ship_eta_PE + AN_time_From_PE.
	Print "AN_time " + AN_time.	
	
	If (time:seconds + AN_time) < (time:seconds + 240){
		Set AN_time to time:seconds + AN_time + Ship_Per. //put on next orbit as its too close to calculate in time.
		Print "AN time too close Shifting Orbit".
	}
	Else {
		Set AN_time to time:seconds + AN_time.
	}
	
	Print "AN_time UT" + AN_time.
	//Refine the UT using hill climb
	hf_Seek_low(AN_time, hf_freeze(0), hf_freeze(0), hf_freeze(0), { 
		parameter mnv. 
		Set AN_time to time:seconds + mnv:ETA.
		return - vang ((positionat(ship, time:seconds + mnv:eta)-body:position),AN). // want the angle to be zero between the ship radial vector and the AN node.
		}
	).
	Set x to nextnode.
	Set AN_time to time:seconds + x:ETA.
	Remove nextnode.
	wait 0.1.
	If x:ETA < 240{
		Set AN_time to AN_time + Ship_Per. //put on next orbit as its too close to calculate in time.
		Print "AN time too close Shifting Orbit".
	}
	Print "Final AN time" + AN_time.
	Return AN_time.

}/// End Function

////////////////////////////////////////////////////////////////
//Helper Functions
////////////////////////////////////////////////////////////////

function hf_ternarySearch { //used for simplle 2-d serach with a clear maximum.
  parameter f, left, right, absolutePrecision, maxVal is true. //function, left bound, right bound, pecision, function test for max or min score.
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

///////////////////////////////////////////////////////////////////////////////////		
	  
function hf_seek {
parameter t, r, n, p, fitness, fine is False,
			data is list(t, r, n, p),
			fit is hf_orbit_fitness(fitness@).  // time, radial, normal, prograde, fitness are the parameters passed in for the node to be found. passes fitness through as a delegate to orbital fitness in this case { parameter mnv. return -mnv:orbit:eccentricity. } is passed through as a local function but any scorring evaluation can be passed through
set data to hf_optimize(data, fit, 100). // search in 100m/s incriments
set data to hf_optimize(data, fit, 10). // search in 10m/s incriments
set data to hf_optimize(data, fit, 1). // search in 1m/s incriments
set data to hf_optimize(data, fit, 0.1). // search in 0.1m/s incriments
If Fine{
	set data to hf_optimize(data, fit, 0.01). // search in 0.01m/s incriments
}
fit(data). //sets the final manuver node and returns its parameters
wait 0. 
return data. // returns the manevour node parameters to where the function was called
}/// End Function

///////////////////////////////////////////////////////////////////////////////////		  
 
function hf_seek_low {
parameter t, r, n, p, fitness, fine is False,
			data is list(t, r, n, p),
			fit is hf_orbit_fitness(fitness@).  // time, radial, normal, prograde, fitness are the parameters passed in for the node to be found. passes fitness through as a delegate to orbital fitness in this case { parameter mnv. return -mnv:orbit:eccentricity. } is passed through as a local function but any scorring evaluation can be passed through
set data to hf_optimize(data, fit, 10). // search in 10m/s incriments
set data to hf_optimize(data, fit, 1). // search in 1m/s incriments
set data to hf_optimize(data, fit, 0.1). // search in 0.1m/s incriments
fit(data). //sets the final manuver node and returns its parameters
If Fine{
	set data to hf_optimize(data, fit, 0.01). // search in 0.01m/s incriments
}
wait 0. 
return data. // returns the manevour node parameters to where the function was called
}/// End Function


///////////////////////////////////////////////////////////////////////////////////		  

function hf_seek_verylow {
parameter t, r, n, p, fitness, fine is False,
			data is list(t, r, n, p),
			fit is hf_orbit_fitness(fitness@).  // time, radial, normal, prograde, fitness are the parameters passed in for the node to be found. passes fitness through as a delegate to orbital fitness in this case { parameter mnv. return -mnv:orbit:eccentricity. } is passed through as a local function but any scorring evaluation can be passed through
set data to hf_optimize(data, fit, 1). // search in 1m/s incriments
set data to hf_optimize(data, fit, 0.1). // search in 0.1m/s incriments
set data to hf_optimize(data, fit, 0.01). // search in 0.01m/s incriments
fit(data). //sets the final manuver node and returns its parameters
If Fine{
	set data to hf_optimize(data, fit, 0.001). // search in 0.01m/s incriments
}
wait 0. 
return data. // returns the manevour node parameters to where the function was called
}/// End Function

///////////////////////////////////////////////////////////////////////////////////		 

function hf_orbit_fitness {
	parameter fitness. // the parameter used to evaluate fitness
	return {
		parameter data.
		until not hasnode { 
			remove nextnode. // Used to remove any existing nodes
			wait 0. 
		} 
		local new_node is node(
		hf_unfreeze(data[0]), hf_unfreeze(data[1]),
		hf_unfreeze(data[2]), hf_unfreeze(data[3])). //Collects Node parameters from the Frozen Lexicon, presented in time, radial, normal, prograde.
		add new_node. // produces new node in the game
		//Print new_node.
		wait 0.
		return fitness(new_node). // returns the manevour node parameters to where the function was called
	}.
}/// End Function

///////////////////////////////////////////////////////////////////////////////////	

function hf_optimize {
parameter data, fitness, step_size,
winning is list(fitness(data), data),
improvement is hf_best_neighbor(winning, fitness, step_size). // collect current node info, the parameter to evaluate, and the incriment size(note: there was a comma here not a full stop if something goes wrong)// a list of the fitness score and the data, sets the first winning node to the original data passed through(note: there was a comma here not a full stop if something goes wrong)// calculates the first improvement node to make it through the until loop
until improvement[0] <= winning[0] { // this loops until the imporvment fitness score is lower than the current winning value fitness score (top of the hill is reached)
	set winning to improvement. // sets the winning node to the improvement node just found
	set improvement to hf_best_neighbor(winning, fitness, step_size). // runs the best neighbour function to find a better node using the current node that is winning
}
return winning[1]. // returns the second column of the winning list "(data)", instead of "fitness(data)"
}/// End Function

///////////////////////////////////////////////////////////////////////////////////		  
	  	  
function hf_best_neighbor {
	parameter best, fitness, step_size. // best is the winning list and contains two coloumns
	for neighbor in hf_neighbors(best[1], step_size) { //send to neighbours function the node information and the step size to retune a list of the neighbours
		local score is fitness(neighbor). // Set up for the score to analyse what is returned by neigbour. This is what finds the fitness score by looking at the mnv node orbit eccentricity that was passed through as delegate into fitness
		if score > best[0] set best to list(score, neighbor). //if the eccentricity score of the neighbour is better save the mnv result to best
	}
	return best. //return the best result of all the neighbours
}/// End Function

///////////////////////////////////////////////////////////////////////////////////		  
	  
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

///////////////////////////////////////////////////////////////
// Creates a lexicon of parameters which are stored and fixed for each evaluation as part of the evaluation and are therefore "frozen"
  function hf_freeze {
	parameter n. 
	return lex("frozen", n).
  }/// End Function

///////////////////////////////////////////////////////////////////////////////////	

// Returns paramters from the frozen lexicon
function hf_unfreeze {
	parameter v. 
	if hf_frozen(v) return v["frozen"]. 
	else return v.
}/// End Function
	
///////////////////////////////////////////////////////////////////////////////////		
	
// identifies if the paramter is frozen
function hf_frozen {
	parameter v. 
	return (v+""):indexof("frozen") <> -1.
}/// End Function

///////////////////////////////////////////////////////////////////////////////////	

function hf_altitudeAt {
  parameter t.
  return ship:body:altitudeOf(positionAt(ship, t)).
}
///////////////////////////////////////////////////////////////////////////////////	

function hf_incScore{
  parameter mnv.
	Local result is - (abs(0-mnv:orbit:inclination)*10000) .
	Print result.
  	return result.
}
///////////////////////////////////////////////////////////////////////////////////	
function hf_LatScore{
  parameter t.
	Local result is abs(Body:GEOPOSITIONOF(positionAT(ship, t)):lat).
	Print "Lat: " +result.
  	return result.
}