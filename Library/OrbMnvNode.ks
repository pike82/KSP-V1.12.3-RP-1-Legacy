///// Download Dependant libraies

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////

    // local OrbMnvNode is lex(
		// ff_Node_time,
		// ff_Node_exec,
		// ff_user_Node_exec
    // ).

////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////

//Note: A shut down engine(inactivated) will not allow this function to work
Function ff_Node_exec { // this function executes the node when ship has one

parameter starttime is 0, tol is 0.1, Ullage_time is 10, n is nextnode, v is n:burnvector.
	print "executing node".		  
	If Starttime = 0 {
		Set Starttime to time:seconds + n:eta - ff_burn_time(v:mag/2).
	}
	Print "locking Steering to burn vector".
	RCS on.
	lock steering to n:burnvector.
	Print "Start time: " + starttime.
	wait until time:seconds >= (starttime - Ullage_time).
	Print "Ullage Start".
	RCS on.
	SET SHIP:CONTROL:FORE to 1.0.
	wait until time:seconds >= (starttime).
	Print "Burn Start".
	SET SHIP:CONTROL:FORE to 0.0.
	Local Stage_Req is False.
	if n:burnvector:mag > ff_stage_delta_v(){
		Set Stage_Req to True.
	}
	Local originalVector is n:burnvector.
	Lock Throttle to min(max(0.0001,ff_burn_time(n:burnvector:mag)),1).//If can be throttled this allows for more accurate shutoff
	wait tol. //provides engine start up time
	until hf_isManeuverComplete(originalVector, n:burnvector, tol){
		if ship:maxthrust < 0.1 { // checks to see if the next engine is enagaged and if it is stage to activate engine
			stage.
			wait 0.1.
			if ship:maxthrust < 0.1 {
				for part in ship:parts {
					for resource in part:resources{ 
						set resource:enabled to true.
					}
				}
				wait 0.1.
			}
		}

		if Stage_Req{
			ff_Flameout().
		}
		wait 0.001.
	}// end until
	Lock Throttle to 0.0.
	Set SHIP:CONTROL:PILOTMAINTHROTTLE to 0.
	Print "Burn Complete".
	unlock steering.
	remove nextnode.
	wait 0.
	RCS off.
}/// End Function

///////////////////////////////////////////////////////////////////////////////////

Function ff_node_time{
	Parameter node_time.
	Local Start is Time:seconds.
	Until (Start + node_time) < Time:seconds {
		wait 1.
		Clearscreen.
		Print "Complete node in: " + ((Start + node_time) - time:seconds).
	}
}

///////////////////////////////////////////////////////////////////////////////////	

function ff_user_Node_exec {
	Clearscreen.
	local firstloop is 1.	
	Until firstloop = 0{
		Print "Please Create a User node: To execute the node press 1, to Skip press 0".
		Wait until terminal:input:haschar.
		Print terminal:input:haschar.
		Set termInput to terminal:input:getchar().
		
		if termInput = 1{
			If hasnode{
				ff_Node_exec().
			}
			Else{
				Print "Please make a node!!!".
			}
		}
		
		Else if termInput = 0 {
			Set firstloop to 0.
		}

		Else {
			Print "Please enter a valid selction".
		}
		Wait 0.01.
	}//end until
}/// End Function	

////////////////////////////////////////////////////////////////
//Helper Functions
////////////////////////////////////////////////////////////////

function hf_isManeuverComplete {
parameter org_mnvVec, mnvVec, tol is 0.1.
	
  	if (vang(org_mnvVec, mnvVec) > 90) or (vdot(mnvVec, org_mnvVec) < 0.01) or (mnvVec:mag < tol) {
		  Print vang(org_mnvVec, mnvVec).//DEBUG
		  Print vdot(mnvVec, org_mnvVec).//DEBUG
		  Print "Mag:" + mnvVec:mag.//DEBUG
    	return true.
  	}
  	return false.
}
