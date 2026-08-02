TMC Continuous Director v6

FILES
-----
TMC_ContinuousDirector.sqf
TMC_AttackWave_CloneWars.sqf
TMC_fnc_spawnAttackWave.sqf
TMC_CfgFunctions.hpp

INSTALLATION
------------
Copy the three SQF files into the mission scenario root.

The wrapper automatically compiles TMC_fnc_spawnAttackWave when necessary, so CfgFunctions registration is optional.

If using CfgFunctions, include TMC_CfgFunctions.hpp inside the mission's existing class CfgFunctions block.

TRIGGER STARTUP
---------------
Use an Any Player / Present / Server Only / Non-repeatable trigger covering the main objective area.

On Activation:

private _settings = createHashMapFromArray [
    ["scalingMode","AREA"],
    ["scalingSide",west],
    ["enemyRatio",3],
    ["scalingUnitsPerVehicle",10],
    ["maxManagedGroups",10],
    ["evaluationInterval",5],
    ["minimumServerFPS",18],
    ["minSpawnRadius",0],
    ["maxSpawnRadius",850],
    ["debugMode","NONE"]
];

["START",thisTrigger,_settings] execVM "TMC_ContinuousDirector.sqf";

CORE BEHAVIOR
-------------
- The director has a hard maximum of 10 active or pending director-managed groups.
- Values above 10 for maxManagedGroups are clamped back to 10.
- Infantry, ground vehicles, and aircraft all consume the same 10 shared group slots.
- At most one new group is requested per evaluation cycle.
- Default evaluation cycle is five seconds.
- New groups are blocked while server FPS is below the configured threshold.

INFANTRY
--------
- Desired infantry remains three managed OPFOR droids per scaling BLUFOR unit by default.
- Ground squads may spawn anywhere from the trigger center to the configured maximum radius.
- They are no longer restricted to the outside edge of the spawn radius.
- Each candidate is rejected if a living player can see the sampled spawn area.
- A 100-meter minimum player distance remains as protection against units appearing directly behind a player.
- Every spawned infantry group receives LAMBS taskRush centered on the exact trigger center.
- The taskRush center is fixed and does not follow the nearest player.
- If LAMBS taskRush is unavailable, the group receives a full-speed MOVE waypoint at the exact trigger center.
- Infantry continues to ignore aircraft so it is not distracted from the ground objective.

GROUND VEHICLES
---------------
- Desired ground vehicles remain one managed OPFOR vehicle per ten scaling BLUFOR units, minimum one while BLUFOR are present.
- Ground vehicles use the same hidden spawn search as infantry.
- Vehicles prefer nearby roads where their templates request it.
- Every vehicle group receives a Seek and Destroy waypoint at the exact trigger center.
- The waypoint uses zero placement radius, so it does not drift around the trigger area.

AIRCRAFT
--------
The director counts living, mobile BLUFOR aircraft that:
- belong to the configured scaling side,
- have a living crew,
- are not touching the ground,
- are at least 15 meters above terrain.

Desired managed OPFOR aircraft equals the number of active BLUFOR aircraft in the air.
Aircraft use the following equal-weight pool:
- 3AS_HMP_Gunship
- 3AS_HMP_Transport
- 3AS_Tri_Fighter_DynamicLoadout
- 3AS_CIS_Vulture_F
- 3AS_CIS_Vulture_AA_F

Aircraft spawn at a distant configurable ring, default 1800 to 2600 meters from the center, at 250 meters altitude. Each aircraft receives a Seek and Destroy waypoint at the exact trigger center.

The 1:1 air target is still subject to the shared 10-group hard cap. Air requests receive first priority when a group slot becomes available, followed by ground vehicles and then infantry.

INFANTRY POOL
-------------
- B1 Assault Company (30)
- B1 Fire Support Platoon (20)
- B1/B2 Assault Squad (10)
- BX Commando Team (6)
- B2 Hunter Cell (3)
- Independent Droideka (1)

COMMANDS
--------
["STATUS"] execVM "TMC_ContinuousDirector.sqf";
["PAUSE"] execVM "TMC_ContinuousDirector.sqf";
["RESUME"] execVM "TMC_ContinuousDirector.sqf";
["STOP"] execVM "TMC_ContinuousDirector.sqf";

TESTING NOTES
-------------
Use debugMode LOG while testing and check the server RPT for lines beginning with [TMC v6 Director] or [TMC v6].
The code has been statically reviewed but still requires an in-game dedicated-server test with the mission modpack.
