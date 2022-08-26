CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
SET TERMINAL:HEIGHT TO 65.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:BRIGHTNESS TO 0.8.
SET TERMINAL:CHARHEIGHT TO 10.
Local sv_ClearanceHeight is 10. 

//Hawk values 152 86.25, 160, 160

// Get Mission Values

local wndw is gui(300).
set wndw:x to 700. //window start position
set wndw:y to 120.

local label is wndw:ADDLABEL("Enter Mission Values").
set label:STYLE:ALIGN TO "CENTER".
set label:STYLE:HSTRETCH TO True. // Fill horizontally

local box_RunMode is wndw:addhlayout().
  	local RunMode_label is box_RunMode:addlabel("Runmode").
  	local RunModevalue is box_RunMode:ADDTEXTFIELD("0.1").
  	set RunModevalue:style:width to 100.
  	set RunModevalue:style:height to 18.

local box_END is wndw:addhlayout().
	local END_label is box_END:addlabel("AP Transistion END (km)").
	local ENDvalue is box_END:ADDTEXTFIELD("39500").//70000
	set ENDvalue:style:width to 100.
	set ENDvalue:style:height to 18.

local box_END_time is wndw:addhlayout().
	local END_time_label is box_END_time:addlabel("AP Transistion END time(s)").
	local END_timevalue is box_END_time:ADDTEXTFIELD("43080").//86160
	set END_timevalue:style:width to 100.
	set END_timevalue:style:height to 18.

local somebutton is wndw:addbutton("Confirm").
set somebutton:onclick to Continue@.

// Show the GUI.
wndw:SHOW().
LOCAL isDone IS FALSE.
UNTIL isDone {
	WAIT 1.
}
wait 1.

Function Continue {

	set val to RunModevalue:text.
	set val to val:tonumber(0).
	Global RunMode to val.

	set val to ENDvalue:text.
	set val to val:tonumber(0).
	Global endheight is val*1000.

	set val to END_timevalue:text.
	set val to val:tonumber(0).
	Global endtime is val.

	wndw:hide().
  	set isDone to true.
}

Global gv_ext is ".ks".

PRINT ("Initialising libraries").
//Initialise libraries first

FOR file IN LIST(
	"OrbMnvs" + gv_ext,
	"OrbMnvNode" + gv_ext,
	"Util_Orbit"+ gv_ext,
	"Util_Vessel"+ gv_ext,
	"Util_Engine"+ gv_ext)
	{ 
		RUNONCEPATH("0:/Library/" + file).
		wait 0.001.	
	}

Global boosterCPU is "Hawk".
ff_partslist(). //standard partslist create

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

Print "ZeusMol active".
Lock Throttle to 0.
Set SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
ff_COMMS().

if runMode = 0.1 { 
	Print "Run mode is:" + runMode.
	ff_COMMS().
	ff_avionics_on().
	RCS on.
	SET SHIP:CONTROL:FORE to 1.0.
	wait 5. //move away from booster.
	SET SHIP:CONTROL:FORE to 0.
	RCS off.
	set runMode to 1.1.
}

if runMode = 1.1 { 
	/////High tranfer burn
	Local transnode is ff_Transfer ().
	Print "Run mode is:" + runMode.
	Local Starttime is time:seconds + nextnode:eta - ff_burn_time(nextnode:burnvector:mag/2).
	Print "Start time is: " + Starttime.
	ff_Alarm(Starttime).
	Until Starttime < (time:seconds + 60){
		wait 1.
	}
	ff_avionics_on().
	ff_Node_exec(Starttime, 2).
	ff_avionics_off().
	wait 1.0.
	Print "Waiting for AP".
	wait 15.
	set runMode to 2.1.
}

if runMode = 2.1 { 
	/////refine burn.

	Local transnode is ff_LowerTransfer ().
	Print "Run mode is:" + runMode.
	Local Starttime is time:seconds + nextnode:eta - ff_burn_time(nextnode:burnvector:mag/2).
	Print "Start time is: " + Starttime.
	ff_Alarm(Starttime).
	Until Starttime < (time:seconds + 60){
		wait 1.
	}
	ff_avionics_on().
	ff_Node_exec(Starttime, 2).
	ff_avionics_off().
	wait 1.0.
	Print "Waiting for AP".
	wait 15.
	unlock steering.
	RCS off.
	SAS off.
	wait 400.
	Shutdown.
}

function ff_Transfer {
	local startSearchTime is time:seconds + (1800 - missiontime). // 30 mins after launch should be near south most point of orbit.
	Print "startSearchTime" + startSearchTime.
	wait 10.
	local transfer is ff_seek(ff_freeze(startSearchTime), 0, 0, 2600, hf_APScore@).
	return transfer.
}

function ff_LowerTransfer {
	Local start is time:seconds + eta:apoapsis.
	local transfer is ff_seek(ff_freeze(start), ff_freeze(0), ff_freeze(0), 0, hf_PerScore@).
	return transfer.
}

function hf_APScore{
  parameter mnv.
  Local result is 0.
	Local result is -(63-abs(mnv:orbit:inclination)) - (abs(mnv:orbit:apoapsis - endheight)/10000).// - nextnode:deltav:mag.
	Print result.
  return result.
}

function hf_PerScore{
  parameter mnv.
  Local result is 0.
	Local result is -abs(mnv:orbit:period -endtime).// - nextnode:deltav:mag.
	Print result.
  return result.
}

function ff_freeze {
	parameter n. 
	return lex("frozen", n).
}/// End Function

function ff_seek {
	parameter t, r, n, p, fitness, fine is False,
			  data is list(t, r, n, p),
			  fit is hf_orbit_fitness(fitness@).  // time, radial, normal, prograde, fitness are the parameters passed in for the node to be found. passes fitness through as a delegate to orbital fitness in this case { parameter mnv. return -mnv:orbit:eccentricity. } is passed through as a local function but any scorring evaluation can be passed through
	set data to ff_optimize(data, fit, 100). // search in 100m/s incriments
	Print "Seek 100".
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
		//Print "score" + score + "best" + Best[0].
	}
	//Print "best:" + best.
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

