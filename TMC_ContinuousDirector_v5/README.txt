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
One infantry group may be requested every five seconds.
One vehicle may be requested every ten seconds, offset by 2.5 seconds.
B1 and B2 groups contain sixteen units.
Droidekas spawn as independent one-unit groups.
BX commandos use a separate six-unit team.
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
