
///// Dependant libraies

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////
		// ff_SpinStab,
		// ff_FAIRING,
		// ff_panels,
		// ff_Tol,
		// ff_COMMS,
		// ff_R_chutes,
		// ff_partslist,
		// ff_Gravity,
		// ff_mAngle,
		// ff_Avionics_off,
		// ff_Avionics_on,
		// ff_clearLine,
		// ff_Alarm

///////////////////////////////////////////////////////////////////////////////////
///// List of helper functions that are called internally
///////////////////////////////////////////////////////////////////////////////////
// hf_360AngDiff
// hf_180AngDiff

/////////////////////////////////////////////////////////////////////////////////////	
//File Functions	
/////////////////////////////////////////////////////////////////////////////////////	



Function ff_SpinStab{
	Parameter intAzimith is 90, pitchdown is 0, waiting is 0.
	LOCK STEERING TO HEADING(intAzimith, pitchdown).
	Print "Spin Stabilisation starting".
	// unlock steering.
	// SAS on.
	// wait 0.25.
	Wait waiting.
	set ship:control:roll to 1.
}

/////////////////////////////////////////////////////////////////////////////////////

FUNCTION ff_FAIRING {
	PARAMETER stagewait IS 0.1.

	IF SHIP:Q < 0.005 {
		FOR module IN SHIP:MODULESNAMED("ProceduralFairingDecoupler") {
			if module:HASEVENT("Jettison Fairing"){
				module:DOEVENT("Jettison Fairing").
				PRINT "Jettisoning Fairings".
				WAIT stageWait.
			}
		}
		FOR module IN SHIP:MODULESNAMED("ModuleProceduralFairing") { // Stock and KW Fairings
			if module:HASEVENT("deploy") {
				module:DOEVENT("deploy").
				PRINT "Jettisoning Fairings".
				WAIT stageWait.
			}
		}
	}
} // End of Function

function ff_panels{
	panels on.
}

/////////////////////////////////////////////////////////////////////////////////////
	
FUNCTION ff_Tol {
//Calculates if within tolerance and returns true or false
	PARAMETER a. //current value
	PARAMETER b.  /// Setpoint
	PARAMETER tol.

	RETURN (a - tol < b) AND (a + tol > b).
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
		}

		If event = "activate"{
			set event to "extend antenna".
		}else{
			set event to "retract antenna".
		}

		FOR antennaList IN SHIP:MODULESNAMED("ModuleDeployableAntenna"){
			IF antennaList:HASEVENT(event) {
				antennaList:DOEVENT(event).
				PRINT event + " Antennas".
				WAIT stageWait.
			}
		}
	}
} // End of Function

///////////////////////////////////////////////////////////////////////////////////	

function ff_R_chutes {
parameter event is "arm parachute".

	for RealChute in ship:modulesNamed("RealChuteModule") {
		RealChute:doevent(event).
		Print event + " enabled.".
		//"arm parachute".
		//"disarm parachute".
		//"deploy parachute".
		//"cut chute".
	}
}// End Function
///////////////////////////////////////////////////////////////////////////////////	

//Load Specific Parts list
function ff_partslist{
	Parameter name is "".
	Global RSS_partlist is list().
	Global partlist is List().
	//LIST Parts IN partList. 
	FOR Part IN partList {
		IF Part:tag = name { 
			RSS_partlist:add(Part).
		}
	}
	//Print "Parts: " + RSS_partlist. //DEBUG
}

///////////////////////////////////////////////////////////////////////////////////

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
///////////////////////////////////////////////////////////////////

function ff_collect_science {
	local SL to lex(). 
	local SMS to lex().
    local DMMS to list("ModuleScienceExperiment", "DMModuleScienceAnimate", "DMBathymetry").
    
	for module_name in DMMS {
		for SM in SHIP:ModulesNamed(module_name) {
			local SP to SM:PART.
			if NOT SMS:HASKEY(SP:NAME) {
				if hf_highlight_part(SP, SM) {
					SMS:ADD(SP:NAME, LIST(SM)).
				}
			} else if SMS:HASKEY(SP:NAME) AND NOT SMS[SP:NAME]:CONTAINS(SP) {
				if hf_highlight_part(SP, SM) {
					SMS[SP:NAME]:ADD(SM).
				}
			}
		}
	}
    for SM_name in SMS:KEYS {
		print "Collecting Science From: "+SM_name.
		if  SM_name = "dmUSPresTemp" {
			for SM in SMS[SM_name] { 
				hf_do_science(SM). 
			}
		}
		else { 
			SET SM to SMS[SM_name][0]. 
			hf_do_science(SM).
		}
    }
    wait 0.5.
    hf_transfer_science().
    wait 0.5.
}
////////////////////////////////////////////////////////////////

FUNCTION ff_mAngle{
PARAMETER a.

  UNTIL a >= 0 { SET a TO a + 360. }
  RETURN MOD(a,360).
  
}

////////////////////////////////////////////////////////////////

Function ff_Avionics_off{
	Local P is SHIP:PARTSNAMED(core:part:Name)[0].
	Local M is P:GETMODULE("ModuleProceduralAvionics").
	If M:HasEVENT("Shutdown Avionics"){
		M:DOEVENT("Shutdown Avionics").
	}
}
////////////////////////////////////////////////////////////////

Function ff_Avionics_on{
	Local P is SHIP:PARTSNAMED(core:part:Name)[0].
	Local M is P:GETMODULE("ModuleProceduralAvionics").
	If M:HasEVENT("Activate Avionics"){
		M:DOEVENT("Activate Avionics").
	}
}

////////////////////////////////////////////////////////////////
function ff_clearLine {
	parameter line.
	local i is 0.
	local s is "".
	until i = terminal:width {
		set s to " " + s.
		set i to i + 1.
	}
	print s at (0,line).
}
////////////////////////////////////////////////////////////////
Function ff_Alarm{
	Parameter starttime, offset is 180.
	If ADDONS:Available("KAC") {		  // if KAC installed	  
		Set ALM to ADDALARM ("Maneuver", starttime - offset, SHIP:NAME ,"").// creates a KAC alarm 3 mins prior to the manevour node
	}
}

function ff_PrintLine{
	parameter str, line.
	ff_clearline (line).
	Print str AT (0,line).

}

////////////////////////////////////////////////////////////////

function hf_highlight_part {
    parameter SP, SM.
    if not SM:HASDATA and not SM:INOPERABLE { 
		HIGHLIGHT(SP, BLUE). return true. 
	}
    else if SM:HASDATA { 
		HIGHLIGHT(SP, GREEN). 
	}
    else { 
		HIGHLIGHT(SP, YELLOW). 
		return false. 
	}
} 
////////////////////////////////////////////////////////////////  

function hf_do_science {
    parameter SM.
    if not SM:HASDATA and not SM:INOPERABLE {
		local t to time:seconds.
		HIGHLIGHT(SM:PART, RED). SM:DEPLOY.
		until (SM:HASDATA or (time:seconds > t+10)) {
			print ".". wait 1.
		}
	}
}
////////////////////////////////////////////////////////////////

function hf_transfer_science {
    for sc in ship:modulesnamed("ModuleScienceContainer") {
		print "Transfering Science".
		sc:doaction("collect all", true).
		wait 0.
    }
}
////////////////////////////////////////////////////////////////
 	
function ff_Science
{
  parameter one_use IS TRUE, overwrite IS FALSE.
	local exp_list is LIST().
	SET exp_list to SHIP:MODULESNAMED("ModuleScienceExperiment").
	FOR exp IN exp_list { 
	
		IF NOT exp:INOPERABLE AND (exp:RERUNNABLE OR one_use) {
			IF exp:DEPLOYED AND overwrite { 
				resetMod(exp). 
			}
			IF NOT exp:DEPLOYED {   
				exp:DEPLOY().
				WAIT UNTIL exp:HASDATA. 
			}
		}
	}
}	//end function


////////////////////////////////////////////////////////////////
//Helper Functions
////////////////////////////////////////////////////////////////

Function hf_360AngDiff{
	Parameter a, b.
	return 180 - abs(abs(a-b)-180). 
}
////////////////////////////////////////////////////////////////
Function hf_180AngDiff{
	Parameter a, b.
	return 90 - abs(abs(a-b)-90). 
}
