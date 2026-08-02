TMC Continuous Director v5

Files:
TMC_ContinuousDirector.sqf
TMC_AttackWave_CloneWars.sqf
TMC_fnc_spawnAttackWave.sqf
TMC_CfgFunctions.hpp

Place the three SQF files in the mission root.

Either include TMC_CfgFunctions.hpp inside description.ext:

class CfgFunctions
{
    #include "TMC_CfgFunctions.hpp"
};

Or allow TMC_AttackWave_CloneWars.sqf to compile the function automatically.

Recommended trigger On Activation:

private _settings = createHashMapFromArray [
    ["scalingMode","AREA"],
    ["scalingSide",west],
    ["initialDelay",1],
    ["scalingEvaluationInterval",5],
    ["enemyRatio",3],
    ["scalingUnitsPerVehicle",10],
    ["infantryEvaluationInterval",5],
    ["vehicleEvaluationInterval",10],
    ["vehicleEvaluationOffset",2.5],
    ["behaviorEvaluationInterval",20],
    ["stuckTimeout",75],
    ["mergeEnabled",true],
    ["mergeThreshold",5],
    ["mergeSearchRadius",300],
    ["maximumMergedGroupSize",30],
    ["infantryMinimumServerFPS",18],
    ["vehicleMinimumServerFPS",18],
    ["estimatedInfantryPerGroup",20],
    ["debugMode","NONE"]
];
["START",thisTrigger,_settings] execVM "TMC_ContinuousDirector.sqf";

Trigger settings:
Activation: Any Player
Activation Type: Present
Repeatable: No
Server Only: Yes

Behavior:
Three managed OPFOR infantry per living BLUFOR in the scaling area.
One managed OPFOR vehicle per ten living BLUFOR, minimum one while BLUFOR are present.
The director calculates reinforcement requirements from the actual number of living managed OPFOR infantry, not from the number of OPFOR groups.
One infantry group may be requested every five seconds.
One vehicle may be requested every ten seconds, offset by 2.5 seconds.
The regular infantry pool uses weighted formations of thirty, twenty, and ten droids.
The thirty-unit group is a B1 assault formation.
The twenty-unit group is a B1 fire-support formation.
The ten-unit group is a mixed B1 and B2 assault formation.
BX commandos use a separate six-unit team: one captain, three standard BX droids, and two assassins.
B2 Hunter Cells spawn as independent three-unit B2 groups.
Droidekas spawn as independent one-unit groups.
Only the thirty, twenty, and ten-unit regular formations may merge.
BX teams, B2 Hunter Cells, Droidekas, and vehicle crews never merge.
During each twenty-second behavior evaluation, a mergeable group with one to four living units searches for another eligible regular infantry group within 300 meters.
The destination group must have enough capacity to remain at or below thirty living units.
The director prefers an established destination group with at least five living units before considering another depleted group.
Groups do not merge while the source or destination is actively clearing buildings, rushing an enemy, or fighting an enemy within 125 meters.
Survivors transfer with joinSilent and follow the surviving destination leader.
The destination group's movement-progress tracking is reset after a merge so a leader change is not falsely treated as a stuck group.
Merging does not change the director infantry count and therefore does not create a false reinforcement deficit.
The weighted pending-package estimate is twenty infantry per group.
Each infantry group receives a LAMBS Task CQB waypoint centered on the nearest living ground-based BLUFOR group leader.
The waypoint updates when its target changes or moves at least thirty-five meters.
Infantry ignores aircraft through a cached aircraft registry and an EntityCreated event handler.
A behavior watchdog checks every twenty seconds.
Groups are not treated as stuck while near enemies, actively clearing buildings, or within one hundred meters of their target.
LAMBS reinforcement and radio sharing are enabled.
Knowledge seeding chance is 25 percent.
Visibility tests only consider players within 1500 meters of a candidate spawn.
Position searches use forty attempts.
All spawned infantry have stamina and fatigue disabled.

Pause behavior:
The director does not automatically enter its paused state because of low server FPS, a missing infantry deficit, a lack of BLUFOR, or exhausted group slots.
The paused state is entered only when the PAUSE command is executed.
While paused, the scheduler performs no scaling checks, spawning, retasking, stuck recovery, merging, or status updates.
Already-spawned AI continue using their existing Arma and LAMBS orders.
Low server FPS only blocks new infantry or vehicle packages until FPS recovers above the configured minimum.
An invalid center reference stops the director rather than pausing it.
The STOP command removes the scheduler and aircraft event handler and terminates pending spawn scripts, but it does not delete already-spawned forces.

Efficiency changes:
The director uses managed group and vehicle registries instead of repeatedly scanning allGroups and vehicles.
The main scheduler exits immediately unless a scaling, infantry, vehicle, behavior, or status evaluation is due.
The allUnits scaling scan runs on its own five-second interval.
Living players are cached once per spawn package and reused for distance, visibility, and target selection.
Clone Wars templates and class validation are cached once per mission.
The wrapper calls the spawn function directly without creating a second scheduled script.
The spawn delay is zero for normal one-group director packages.
Debug logging defaults to NONE and periodic status logging only runs when LOG or MARKERS mode is enabled.
Aircraft ignore commands are only applied when a group or aircraft is newly registered.

Commands:
["STATUS"] execVM "TMC_ContinuousDirector.sqf";
["PAUSE"] execVM "TMC_ContinuousDirector.sqf";
["RESUME"] execVM "TMC_ContinuousDirector.sqf";
["STOP"] execVM "TMC_ContinuousDirector.sqf";
