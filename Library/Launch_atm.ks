
///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////
	// "preLaunch" // Conducts Pre-launch checks pre-ignition
	// "liftoff" // Conducts ignition checks and releases
	// "liftoffclimb" // Conducts intial climb out and pitch over
	// "GravityTurnAoA" //This gravity turn tries to hold the minimum AoA until the first stage cut-out
	// "CoastH" // intended to keep a low AoA when coasting until a set altitude
	// "CoastT" // intended to keep a low AoA when coasting until a set time from AP
	// "Orbit_Steer"  //Uses PEG insertion for upto three stages

////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////	
// Conducts Pre-launch checks pre-ignition
Function ff_preLaunch {
	Parameter gimbalLimit is 90.
	//TODO: Make gimble limits work.
	Wait 1. //Alow Variables to be set and Stabilise pre launch
	//Prelaunch
	Wait 1. 
	PRINT "Prelaunch.".
	Lock Throttle to 1.
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 1.
	LOCK STEERING TO r(up:pitch,up:yaw,facing:roll). //this is locked in current pointing poistion until the clamps are relased
	Print "Current Stage:" + STAGE:NUMBER.
	//Set the Gimbal limit for engines where possible
	LIST ENGINES IN engList. //Get List of Engines in the vessel
	FOR eng IN engList {  //Loops through Engines in the Vessel
		//IF eng:STAGE = STAGE:NUMBER { //Check to see if the engine is in the current Stage, Note this is only used if you want a specific stage gimbal limit, otherwise it is applied to all engines
			IF eng:HASGIMBAL{ //Check to see if it has a gimbal
				SET eng:GIMBAL:LIMIT TO gimbalLimit. //if it has a gimbal set the gimbal limit
			}
		//}
	}
	Print "Gimbal limits Set".
} /// End Function	
		
/////////////////////////////////////////////////////////////////////////////////////	
// Conducts ignition checks and releases		
Function ff_liftoff{
	Parameter thrustMargin is 0.97, MaxStartTime is 5.
	STAGE. //Ignite main engines
	Print "Starting engines".
	Local EngineStartTime is TIME:SECONDS.
	Local MaxEngineThrust is 0. 
	Wait until Stage:Ready. 
	Local englist is List().
	//List Engines. //DEBUG
	LIST ENGINES IN engList. //Get List of Engines in the vessel
	FOR eng IN engList {  //Loops through Engines in the Vessel
		// Print "eng:STAGE:" + eng:STAGE. //DEBUG
		//Print STAGE:NUMBER. //DEBUG
		IF eng:STAGE >= STAGE:NUMBER { //Check to see if the engine is in the current Stage
			SET MaxEngineThrust TO MaxEngineThrust + eng:MAXTHRUST. 
			Print "Stage Full Engine Thrust:" + MaxEngineThrust. 
		}
	}
	Print "Checking thrust".
	Local CurrEngineThrust is 0.
	until CurrEngineThrust > (thrustMargin * MaxEngineThrust){ // until upto thrust or the engines have attempted to get upto thrust for more than 5 seconds.
		Set CurrEngineThrust to 0.//reset each loop
		FOR eng IN engList {  //Loops through Engines in the Vessel
			//Print eng:name. //DEBUG
			IF eng:STAGE >= STAGE:NUMBER { //Check to see if the engine is in the current Stage
				//Print eng:THRUST. //DEBUG
				SET CurrEngineThrust TO CurrEngineThrust + eng:THRUST. //add thrust to overall thrust
			}
		}
		if TIME:SECONDS > (EngineStartTime + MaxStartTime){
			Lock Throttle to 0.
			Set SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
			Print "Engine Start up Failed...Making Safe".
			Shutdown. //ends the script
			//Print "CurrEngineThrust: " + CurrEngineThrust. //DEBUG
		}
		//Print "CurrEngineThrust: " + CurrEngineThrust. //DEBUG
		//Print "MaxEngineThrust: " + (thrustMargin * MaxEngineThrust). //DEBUG
		wait 0.1.
	}
	Print "Releasing Clamps".
	Wait until Stage:Ready . // this ensures time between staging engines and clamps so they do not end up being caught up in the same physics tick
	STAGE. // Relase Clamps
	PRINT "Lift off".
}/// End Function

/////////////////////////////////////////////////////////////////////////////////////	
// Conducts intial climb out and pitch over
Function ff_liftoffclimb{
	Parameter anglePitchover is 88, intAzimith is 90, ClearanceHeight is 100. 
	local LchAlt is ALT:RADAR.
	Wait UNTIL ALT:RADAR > ClearanceHeight + LchAlt.
	LOCK STEERING TO HEADING(intAzimith, 90).
	Wait UNTIL SHIP:Q > 0.015. //Ensure past clearance height and airspeed 0.015 equates to approx 50m/s or 1.5kpa which is high enough to ensure aero stability for most craft small pitching	
	PRINT "Starting Pitchover " + MissionTime.
	LOCK STEERING TO HEADING(intAzimith, anglePitchover). //move to pitchover angle
	WAIT 10. //allows pitchover to stabilise
}// End of Function
	
/////////////////////////////////////////////////////////////////////////////////////		
//This gravity turn tries to hold the minimum AoA until the first stage cut-out
Function ff_GravityTurnAoA{	
	PARAMETER intAzimith is 90, ullage is "RCS", Flametime is 0.5, Res is 0.995, offset is 0. 
	Print "Gravity Turn AOA".
	lock pitch to 90 - VANG(SHIP:UP:VECTOR, SHIP:VELOCITY:SURFACE).
	LOCK STEERING TO heading(intAzimith, pitch).
	Local Endstage is false.
	Until Endstage {
		set Endstage to ff_Flameout(ullage, Flametime, Res, offset).
		Wait 0.01.
	}
} // End of Function

/////////////////////////////////////////////////////////////////////////////////////
Function ff_CoastH{ // intended to keep a low AoA when coasting until a set altitude
	Parameter targetAltitude, intAzimith is 90, hold is false.
	Print "Coasting Phase".
	LOCK Throttle to 0.
	if hold{
		LOCK STEERING TO ship:facing:vector. //maintain current alignment
	}else{
		lock pitch to 90 - VANG(SHIP:UP:VECTOR, SHIP:VELOCITY:ORBIT).
		LOCK STEERING TO heading(intAzimith, pitch).
	}
	RCS on.
	UNTIL SHIP:Apoapsis > targetAltitude {
		ff_FAIRING().
	}
}// End of Function

/////////////////////////////////////////////////////////////////////////////////////

Function ff_CoastT{ // // intended to keep a low AoA when coasting until a set time from AP
	Parameter targetETA is 30, intAzimith is 90, hold is false.
	Print "Coasting Phase".
	LOCK Throttle to 0.
	if hold{
		LOCK STEERING TO ship:facing:vector. //maintain current alignment
	}else{
		lock pitch to 90 - VANG(SHIP:UP:VECTOR, SHIP:VELOCITY:ORBIT).
		LOCK STEERING TO heading(intAzimith, pitch).
	}
	RCS on.
	UNTIL ETA:APOAPSIS < targetETA {
		ff_FAIRING().
	}
}// End of Function

/////////////////////////////////////////////////////////////////////////////////////
// Uses PEG insertion for upto three stages
// References:
// http://www.orbiterwiki.org/wiki/Powered_Explicit_Guidance
//With Large assisstance and corrections from:
// https://github.com/Noiredd/PEGAS
// https://ntrs.nasa.gov/archive/nasa/casi.ntrs.nasa.gov/19660006073.pdf
// https://amyparent.com/post/automating-rocket-launches/

//Dependant Libraries
// Util_Vessels
// Util_Engines 

//An empty function to allow functions to be passed into ff_Orbit Steer
function hf_empty{}

//TOODO: pass in functions that can be run
function ff_Orbit_Steer{
	Parameter 
	Stages,
	tgt_pe,
	tgt_ap,
	sv_intAzimith,
	u is 0,//Target true anomoly
	HSL is 5, //end shutdown margin
//Stage 3
	T3 is 170, // stage three estimated burn length
	mass_flow3 is 115, //estimated mass flow(kg/s)
	start_mass3 is 30745, //estimated start mass in kg
	s_Ve3 is 3060, //estimated exhuast vel (thrust(N)/massflow(kg/s))
	tau3 is 200, //(S-Ve/avg_acc) estimated effective time to burn all propellant S-Ve = ISP*g0
//Stage 2 //
	T2 is 0, // stage two estimated burn length
	mass_flow2 is 1, //estimated mass flow(kg/s)
	start_mass2 is 1, //estimated start mass in kg
	s_Ve2 is 1, //estimated exhuast vel (thrust(kN)/massflow(kg/s))
	tau2 is 1, //(S-Ve/avg_acc) estimated effective time to burn all propellant
//Stage 1 //
	T1 is 0, // stage one estimated burn length
	mass_flow1 is 0, //estimated mass flow
	s_Ve1 is 1, //estimated exhuast vel (do not make 0)
	tau1 is 1, //(S-Ve/avg_acc) estimated effective time to burn all propellant
// shutdown offset for engine thrusts
	s_vx_offset is 0,
//  functions to be run at various stages
	Funct1 is hf_empty@,
	Funct2 is hf_empty@,
	Funct3 is hf_empty@,
	Funct4 is hf_empty@,  

 	A3 is 0, 
    B3 is 0, 

    A2 is 0, 
    B2 is 0, 

	A1 is 0,
    B1 is 0. 

// Creat elexicon of values that may need to be used by functions outside of this function (can't pass variable in or out any other way)
	Global SteerLex is lexicon().
	SteerLex:Add("T1_lock", false).// in and out
	SteerLex:Add("T2_lock", false).// in and out
	SteerLex:Add("tau_lock", false).// in and out
	SteerLex:Add("loop_break", false).// in and out
	SteerLex:Add("chiTilde", false).// in and out
	SteerLex:Add("fairlock", false).// in and out
	SteerLex:Add("T3", T3).//out only

// determine T intial paramenters based on the number of stages.
	If Stages < 2{
		Set SteerLex["T2_lock"] to true.
	}
	If Stages < 3{
		Set SteerLex["T1_lock"] to true.
	}

	local Thrust2 is s_Ve2 * mass_flow2.
	local Thrust3 is s_Ve3 * mass_flow3.

//starting peg variables

    local converged is 0. // used by convergence checker
	Local int_pitch is 90 - VANG(SHIP:UP:VECTOR, SHIP:VELOCITY:ORBIT). //locked picth prior to convergence.
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
	if u = 0 { //u=0 means PE is target position in orbit
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

	Print "PEG Values set up".
	Print ship:mass.
	Print ship:drymass.
	//SET STEERINGMANAGER:MAXSTOPPINGTIME TO 1.//can adjust for strenth/speed of changes to steeering control

	//Run first function before the PEG starts
	Funct1().

    local rTcur is MISSIONTIME. //Bound KOS time since CPU launch.
	local last is MISSIONTIME.
	local lastM is MISSIONTIME.
    local s_r is ship:orbit:body:distance.
	local s_acc is ship:AVAILABLETHRUST/ship:mass.
	local s_vy is ship:verticalspeed.
	local s_vx is sqrt(ship:velocity:orbit:sqrmagnitude - ship:verticalspeed^2).
	local w is s_vx / s_r.
	local s_ve is ff_Vel_Exhaust().
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

	//Loop through updating the parameters until the break condition is met
	//Line 1: Last Action
	//Line 2: Current Phase
	//Line 3: Tau State
	//Line 4: Loop Guidance
	//Line 5: Loop
	//Line 6: T
	//Line 7: Pitch
	ff_PrintLine("tau unlocked",3).

    until false {
		//KUniverse:PAUSE().//used for debuging
		Set SteerLex["T3"] to T3.
		//Run second function just as the PEG starts
		Funct2().

		//Collect updated time periods
        set rTcur to MISSIONTIME.
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
		
		If (SteerLex["tau_lock"] = false) and (ship:AVAILABLETHRUST > 5){ //availble thrust prevents calculation when engines are off
			set s_ve to ff_Vel_Exhaust().
			Set tau to s_ve/s_acc.
		} else{
			Set tau to 300.
		}

		if (SteerLex["tau_lock"] = false) and (SteerLex["T1_lock"] = false){
			Print "IGM Phase 1" AT (0,2).
			Set T1 to T1 - DeltaM.
			Set A1 to A1 + (B1 * DeltaM).
			Print "T1:" + T1 AT (0,6).
			if (T1 < 3) and (Converged = 1){ 
				Set SteerLex["tau_lock"] to true.
				Print"tau locked" AT (0,3).
				Set SteerLex["T1_lock"] to true. //prevents entering this loop again
			}Else{
				set s_Ve1 to s_ve.
				set tau1 to tau.
			}
		}

		if (SteerLex["T1_lock"] = true) and (SteerLex["T2_lock"] = false) and (SteerLex["tau_lock"] = false) {
			Print "IGM Phase 2" AT (0,2).
			Set T2 to T2 - DeltaM.
			Set A2 to A2 + (B2 * DeltaM).
			Print "T2:" + T2 AT (0,6).
			if (T2 < 3) and (Converged = 1){
				Set SteerLex["tau_lock"] to true.
				Print "tau locked" AT (0,3).
				Set SteerLex["T2_lock"] to true. //prevents entering this loop again
			}Else{
				set s_Ve2 to s_ve.
				set tau2 to tau.
			}
			Set T1 to 0. //ensure it's removed from calculations
		}

		if (SteerLex["T1_lock"] = true) and (SteerLex["T2_lock"] = true) and (SteerLex["tau_lock"] = false){
			Print "IGM Phase 3" AT (0,2).
			Set T3 to T3 - DeltaM.
			Print "T3:" + T3 AT (0,6).
			Set A3 to A3 + (B3 * DeltaM).
			set s_Ve3 to s_ve.
			set tau3 to tau.
			Set T1 to 0. //ensure it's removed from calculations
			Set T2 to 0. //ensure it's removed from calculations
		}

		//Run third function before thrust check
		Funct3().
		//rest run s_acc incase Funct 3 requires it due to a staging event
		set s_acc to ship:AVAILABLETHRUST/ship:mass.

		// Print "AVAILABLETHRUST:" +AVAILABLETHRUST.//DEBUG
		if (AVAILABLETHRUST < 5) {
			Stage.// release
			wait 0.1.
			Wait until Stage:Ready . 
			If SteerLex["T1_lock"] = True{
				Set SteerLex["T2_lock"] to True.
			} Else {
				Set SteerLex["T1_lock"] to True.
			}
			Print "Staging" AT (0,1).
			Stage.// start next engine
			wait 3.
			Set SteerLex["tau_lock"] to false.
			Print "Tau unlocked" AT (0,3).
			set s_acc to ship:AVAILABLETHRUST/ship:mass.//needs to be reset from remainder of loop
			//SET STEERINGMANAGER:MAXSTOPPINGTIME TO 1.
		}
		
		//Run fourth function before HSL
		Funct4().
		//enter chi-tilde approximately (HSL *2) to stop using the A and B terms.
		if  (T3 < (HSL*2)) and (SteerLex["tau_lock"] = true) and SteerLex["T2_lock"] = True{
			Set SteerLex["chiTilde"] to True.
			Print "chiTilde" AT (0,1).
		}
		//cutoff process
		if  (T3 < HSL) and (SteerLex["tau_lock"] = true) and SteerLex["T2_lock"] = True{
			Print "Terminal guidance phase" AT (0,2). 
			Until false{
				set s_vx to sqrt(ship:velocity:orbit:sqrmagnitude - ship:verticalspeed^2) + s_vx_offset.
				Local track is time:seconds.
				until (ship:orbit:eccentricity < 0.001) or (ship:periapsis > tgt_pe) or (tgt_vx < s_vx) or (time:seconds > track + 30){
					wait 0.01.
					set s_vx to sqrt(ship:velocity:orbit:sqrmagnitude - ship:verticalspeed^2) + s_vx_offset.
					//Print tgt_vx AT (0,10). //DEBUG
					//Print s_vx AT (0,11). //DEBUG
					//Print ship:orbit:eccentricity AT (0,12). //DEBUG
					//KUniverse:PAUSE(). //DEBUG
					wait 0.001.
				}
				Lock Throttle to 0.
				Set SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
				Print "Insertion: "+ (TIME:SECONDS) AT (0,1).
				Set SteerLex["loop_break"] to true.
				break.
			}
		}
		
		//////////PEG Minor loop//////////////////////
    	If (delta >= peg_step) and (SteerLex["tau_lock"] = false) and (ship:AVAILABLETHRUST > 5){  // this is used to ensure a minimum time step occurs before undertaking the next peg cycle calculations
			//KUniverse:PAUSE().//used for debuging

			Set last to MISSIONTIME.//reset major calculation loop
			/// determine peg states

			local peg_solved is hf_PEG(A1, B1, T1, rT1, hT1, w_T1, s_ve1, tau1, tgt_vy, tgt_vx, tgt_r, tgt_w, mass_flow1,  
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

			//Check for convergence
			If Converged = 0{
				If ff_Tol (T3, T3_new, 1){
					Set Converged to 1.
					Print "Closed Loop Guidanace Enabled" AT (0,4).
				}else{
					Print "Closed Loop Converging" AT (0,4).
				}
			//Print T3 AT (0,6).
			//Print T3_new AT (0,7).
			}

			if SteerLex["T1_lock"] = false {

				set w_T1 to w_T1_new.
				set w_T2 to w_T2_new.
				set w_T3 to w_T3_new.
				set T3 to T3_new.
				set A to A1.
				set B to B1.
				Print "T1 PEG Loop" AT (0,5).
			} 

			if (SteerLex["T2_lock"] = false) and (SteerLex["T1_lock"] = True){
				set w_T2 to w_T2_new.
				set w_T3 to w_T3_new.
				set T3 to T3_new.
				set A to A2.
				set B to B2.
				Print "T2 PEG Loop" AT (0,5).
				Set T1 to 0. //ensure it's removed from calculations
			}

			if (SteerLex["T2_lock"] = True) and (SteerLex["T1_lock"] = True){
				if(T3_new <= HSL) and (Converged = 1){ // below this the solution starts to become very sensitive and A and B should not longer be re-calculated but fixed until insertion
					Print "Terminal guidance enabled" AT (0,1). 
					Set peg_step to 1000. //we no longer want to go into the minor loop to calculate A, B and T3.
					//Print SteerLex["tau_lock"]. //DEBUG
					Set SteerLex["tau_lock"] to true.
					Print "tau locked" AT (0,3).
					//KUniverse:PAUSE(). //DEBUG
				} Else{
					Print "T3 PEG Loop: " AT (0,5).
					set A to A3.
					set B to B3.
				}
				Set T3 to T3_new.
				set w_T3 to w_T3_new.
				Set T1 to 0. //ensure it's removed from calculations
				Set T2 to 0. //ensure it's removed from calculations
				//KUniverse:PAUSE().//used for debuging
			}			
		}

		// Print A AT (0,15). //DEBUG
		// Print B AT (0,16). //DEBUG
		// Print C AT (0,17). //DEBUG
		// Print w AT (0,18). //DEBUG
		// Print s_acc AT (0,19). //DEBUG
		// Print peg_step AT (0,20). //DEBUG

		If SteerLex["loop_break"] = true {
			Break.// exit loop
		}
		set C to ((body:mu/(s_r^2)) - ((w^2)*s_r))/s_acc.
		if SteerLex["tau_lock"] = True{
			Set A to 0.
		}	
		set s_pitch to A + C. //sin pitch at current time.
		set s_pitch to max(-0.707, min(s_pitch, 0.707)). // limit the pitch change to between -45 and 45 degress
		Set s_pitch to arcsin(s_pitch). //covert into degress
		//Use s-pitch only if converged 
		if converged = 1{
			LOCK STEERING TO heading(sv_intAzimith, s_pitch).
		}Else{
			LOCK STEERING TO heading(sv_intAzimith, int_pitch).
		}
		Print "S pitch: " + s_pitch AT (0,7).
		// Print "T1:" + T1. //DEBUG
		// Print "T2:" + T2. //DEBUG
		// Print "T3:" + T3. //DEBUG
		// Print "RT3: " + rT3. //DEBUG
		// Print "HT3: " + hT3. //DEBUG
		//Print (HSL - delta). //DEBUG
		//Print SteerLex["tau_lock"]. //DEBUG
		if (T3 <= (2*HSL)){
			wait 0.1.//reduce computation needs until the end.
		}else{
			wait 0.01.
		}
	}//end of loop

} // end of function
	
/////////////////////////////////////////////////////////////
//Helper Functions - These are only used for internally by the file functions
/////////////////////////////////////////////////////////////

function hf_PEG {
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

	local L1 is hf_bcn(s_ve1, tau1, T1).

	local bb01 is L1[0].
	local bb11 is L1[1].
	local bb21 is L1[2].
	local cc01 is L1[3].
	local cc11 is L1[4].
	local cc21 is L1[5].

	local L2 is hf_bcn(s_ve2, tau2, T2).

	local bb02 is L2[0].
	local bb12 is L2[1].
	local bb22 is L2[2].
	local cc02 is L2[3].
	local cc12 is L2[4].
	local cc22 is L2[5].

	local L3 is hf_bcn(s_ve3, tau3, T3).

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
	// Print "T1: " + T1.
	// Print "A1: " + A1.
	// Print "B1: " + B1.
	// Print "rT1: " + rT1.
	// Print "dA1: " + dA1.
	// Print "dB1: " + dB1.
	// Print "T2: " + T2.
	// Print "A2: " + A2.
	// Print "B2: " + B2.
	// Print "rT2: " + rT2.
	// Print "dA2: " + dA2.
	// Print "dB2: " + dB2.
	// Print "T3: " + T3.
	// Print "A3: " + A3.
	// Print "B3: " + B3.
	// Print "rT3: " + rT3.
	// Print "s_ve3: " + s_ve3.
	// Print "tau3: " + tau3.
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
	//Print "Calc rdotT3 check " + rdotT3.
	set rdotT3 to tgt_vy.
	
	//J=4 l=3, k=2, i=1, m=0
	set rT3 to s_r + (s_vy*(T1+T2+T3)). 
	set rT3 to rT3 + ( (cc03 + (T3*(bb01+bb02))) + (cc02 + (T2*bb01)) + (cc01 + (T1*0)) )*A.
	set rT3 to rT3 + ( cc13 + cc12 + cc11 + (cc03*T2 + bb12*T3 + bb02*T3*T1) + (cc03*T1) + (bb11*T3) + ((bb01*T3)*0) + (cc02*T1 + bb11*T2 + bb01*T2*0) + (cc01*0 + 0*T1 + 0*T1*0)  )*B.
	set rT3 to rT3 + ((cc03*dA2) + (cc13*dB2) + (cc02*dA1) + (cc12*dB1)).
	set rT3 to rT3 + (bb02*T3*dA1 + bb02*T1*T3*0 + bb12*T3*dB1 + cc03*T2*dB1).
	set rT3 to rT3 + (bb01*T3*dA1) + (bb01*T1*T3*0) + (bb11*T3*dB1) + (cc03*T1*dB1).//l=3, k=1, i=1, m=0
	//Print "Calc RT3 check " + rT3.
	set rT3 to tgt_r.
	
	//Print "rdotT3: "+rdotT3.
	//Print "rT3: "+ rT3.

	Local L6 is hf_end_cond(w_T2, rT2, s_acc_3, w_T3, rT3, s_acc_end_3, T3, A3, B3). 
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
	//Constrain T3 outputs
	//if (dv_T3 < 5) and (T1 > 0) {Set dv_T3 to 5.} //prevent small dv_T3 which will cause errors
	//if (dv_T3 > tau3) {Set dv_T3 to (tau3).} //prevent a big dv_T3 beyond Tau3 which is impossible and will cause errors  
	Set T3 to tau3*(1 - constant:e ^ (-dv_T3/s_ve3)).
	if T3 <0 {Set T3 to 2.}
	//Print "dv gain T3 to Orbit: " + dv_T3.

	//T2 parameters
	set s_acc_2 to Thrust2/start_mass2.
	set s_acc_end_2 to Thrust2/ (start_mass2 -((mass_flow2)*T2)).

	//J= 3 l=2, k=1, i=0
	set rdotT2 to s_vy.
	set rdotT2 to rdotT2 + (bb02+bb01)*A.
	set rdotT2 to rdotT2 + ( (bb12 + (bb02*T1)) + (bb11 + (bb01*0)) )*B.   //vertical speed at staging
	set rdotT2 to rdotT2 + ((bb02*dA1) + (bb02*T1*0) + (bb12*dB1)) + ((bb01*0) + (bb01*0*0) + (bb11*0)).
	
	//J=3 l=2, k=1, i=0
	//Print "s_r: "+ s_r.
	set rT2 to s_r + (s_vy*(T1+T2)). 
	set rT2 to rT2 + ( (cc02 + (T2*bb01)) + (cc01 + (T1*0)) )*A.
	set rT2 to rT2 + ( cc12 + cc11 + (cc02*T1 + bb11*T2 + bb01*T2*0) + (cc01*0 + 0*T1 + 0*T1*0)  )*B.
	set rT2 to rT2 + ( (cc02*dA1) + (cc12*dB1) + (cc01*0) + (cc11*0)  ).
	set rT2 to rT2 + (bb01*T2*0 + bb01*0*T2*0 + bb11*T2*0 + cc02*T1*0).
	// Print "RT2: "+ rT2.  DEBUG Check if correct height units have been used
	//Print "Calc RT2 check " + rT2.

	Local L5 is hf_end_cond(w_T1, rT1, s_acc_2, w_T2, rT2, s_acc_end_2, T2, A2, B2). 
	local ft_2 is L5[0].
	local ftdot_2 is L5[1].
	local ftdd_2 is L5[2].
	local dh_T2 to ((rT1 + rT2)/2)*( (ft_2*bb02) + (ftdot_2*bb12) + (ftdd_2*bb22) ).
	Set hT2 to dh_T2 + hT1.
	local v0_T2 is hT2/rT2.
	Set w_T2 to sqrt((v0_T2^2) - (rdotT2^2))/rT2.

	set mean_r to (rT2 + rT1)/2.
	local dv_gain is dh_T2/mean_r.
	//Print "dv gain to T1 to T2: " + dv_gain.

	if (T1 = 0) and NOT(T2=0){ // if only two stage to orbit
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

	
	//J= 2 l=1, k=0, i=0
	set rT1 to s_r + (s_vy*(T1)). 
	set rT1 to rT1 + ( (cc01 + (T1*0)) )*A.
	set rT1 to rT1 + ( cc11 + (cc01*0 + 0*T1 + 0*T1*0)  )*B.
	set rT1 to rT1 + ( (cc01*0) + (cc11*0) ).
	//If (rT1 < 0){Set rT1 to 1.}. // prevent negative.
	// Print "Calc RT1 check " + rT1.
	// Print "Change rDot3: " + (bb03*A3 + bb13*B3).
	// Print "Change r3: " + (rdotT2*T3) + cc03*A3 + cc12*B3.
	// Print "Change rDot2: " + (bb02*A2 + bb12*B2).
	// Print "Change r2: " + (rdotT1*T2) + cc02*A2 + cc12*B2.
	// Print "Change rDot1: " + (bb01*A1 + bb11*B1).
	// Print "Change r1: " + (s_vy*T1) + cc01*A1 + cc11*B1.

	local L4 is hf_end_cond(w, s_r, s_acc, w_T1, rT1, s_acc_end_1, T1, A1, B1). 
	local ft_1 is L4[0].
	local ftdot_1 is L4[1].
	local ftdd_1 is L4[2].
	local dh_T1 to ((s_r + rT1)/2)*( (ft_1*bb01) + (ftdot_1*bb11) + (ftdd_1*bb21) ).
	Set hT1 to dh_T1 + h0.
	local v0_T1 is hT1/rT1.
	//constraint on V0_T1 to less than remaining stage dv
	Set w_T1 to sqrt((v0_T1^2) - (rdotT1^2))/rT1.
	//Print "w_T1: " + w_T1.
	set mean_r to (s_r + rT1)/2.
	local dv_gain is dh_T1/mean_r.
	//Print "dv gain to T1: " + dv_gain.

	if Not (T1 = 0) { // if only three stages to orbit
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

	local peg is hf_peg_solve(mA11, mA12, mA21, mA22, mC1, mC2).

	if T1 > 0{
		Set A1 to peg[0].
		Set B1 to peg[1].
		//Print "A1 peg"+ A1. 
		//Print "B1 peg" + B1.
	}
	if (T2 > 0) and (T1 = 0){
		Set A2 to peg[0].
		Set B2 to peg[1].
		//Print "A2 peg"+ A2. 
		//Print "B2 peg" + B2.
	}
	if (T2 = 0) and (T1 = 0){
		Set A3 to peg[0].
		Set B3 to peg[1].
		//Print "A3 peg"+ A3. 
		//Print "B3 peg" + B3.
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
function hf_bcn{
	parameter s_ve.
	parameter tau.
	parameter T.

	//Print s_ve. //DEBUG
	//Print tau. //DEBUG
	//Print T. //DEBUG

	if T > tau or  T = tau { //prevent infinty stack error
		set tau to (T + 0.00000001).
		//Print "Prevented infinity stack".
	}

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
Function hf_end_cond{
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
function hf_peg_solve {
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

	// //solve matrix
	// local d is ((mA11*mA22) - (mA12*mA21)). // inverse coefficent

	// //Multiple inverse matrix by result matrix
	// local A is (mA22*mC1 - mA12*mC2)/d.
	// local B is (mA11*mC2 - mA21*mC1)/d.


    return list(A, B).
}

