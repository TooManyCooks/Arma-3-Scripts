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
    ["infantryMinimumServerFPS",18],
    ["vehicleMinimumServerFPS",18],
    ["estimatedInfantryPerGroup",29],
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
The primary infantry pool uses large groups of forty, thirty, and twenty droids to reduce the number of AI group leaders.
The forty-unit group is a B1 assault formation.
The thirty-unit group is a B1 fire-support formation.
The twenty-unit group is a mixed B1/B2 assault formation.
Large formations have a combined weight of twenty-eight while each specialty formation has a weight of one, so normal director packages strongly favor the larger groups.
BX commandos use a separate six-unit team: one captain, three standard BX droids, and two assassins.
B2 Hunter Cells spawn as independent three-unit B2 groups.
Droidekas spawn as independent one-unit groups so they retain their own movement behavior.
The recommended pending-package estimate is twenty-nine infantry per group, matching the weighted template average.
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
