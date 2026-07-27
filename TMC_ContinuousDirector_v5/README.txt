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
    ["enemyRatio",3],
    ["scalingUnitsPerVehicle",10],
    ["infantryEvaluationInterval",5],
    ["vehicleEvaluationInterval",10],
    ["vehicleEvaluationOffset",2.5],
    ["behaviorEvaluationInterval",20],
    ["stuckTimeout",75],
    ["infantryMinimumServerFPS",18],
    ["vehicleMinimumServerFPS",18],
    ["debugMode","LOG"]
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
Droidekas spawn as independent one-unit groups so each can roll and maneuver separately.
BX commandos use a separate six-unit team.
Each infantry group receives a LAMBS Task CQB waypoint centered on the nearest living BLUFOR group leader.
The director updates that waypoint when the selected BLUFOR leader moves.
Infantry ignores aircraft, uses AWARE and YELLOW behavior, keeps enableAttack disabled, and retains FULL speed.
A behavior watchdog checks groups every twenty seconds and reissues movement after seventy-five seconds without meaningful progress.
LAMBS reinforcement and radio sharing are enabled.
Knowledge seeding chance is 25 percent.
Visibility tests only consider players within 1500 meters of the candidate spawn.
Position searches use forty attempts.
All spawned infantry have stamina and fatigue disabled.

Commands:
["STATUS"] execVM "TMC_ContinuousDirector.sqf";
["PAUSE"] execVM "TMC_ContinuousDirector.sqf";
["RESUME"] execVM "TMC_ContinuousDirector.sqf";
["STOP"] execVM "TMC_ContinuousDirector.sqf";
