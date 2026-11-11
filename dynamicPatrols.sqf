/*
  dynamicPatrols.sqf
  Spawns AI patrols near player squad leaders and removes them when far away.
  The script is intended for dedicated servers and uses LAMBS Danger FSM.
*/

// Load configuration values and unit loadouts
call compile preprocessFileLineNumbers "patrolConfig.sqf";

if (isNil {missionNamespace getVariable 'ActivePatrols'}) then {
    missionNamespace setVariable ['ActivePatrols', []];
};

// Sanity check configuration values
if (isNil "PatrolCooldownTime") then { diag_log "[dynamicPatrols] PatrolCooldownTime undefined - using 300"; PatrolCooldownTime = 300; };
if (isNil "PatrolSpawnDistance") then { diag_log "[dynamicPatrols] PatrolSpawnDistance undefined - using 200"; PatrolSpawnDistance = 200; };
if (isNil "PatrolDespawnDistance") then { diag_log "[dynamicPatrols] PatrolDespawnDistance undefined - using 500"; PatrolDespawnDistance = 500; };
if (isNil "MaxPatrolsPerPlayer") then { diag_log "[dynamicPatrols] MaxPatrolsPerPlayer undefined - using 2"; MaxPatrolsPerPlayer = 2; };
if (isNil "MaxSpawnsPerLoop") then { diag_log "[dynamicPatrols] MaxSpawnsPerLoop undefined - using 3"; MaxSpawnsPerLoop = 3; };
if (isNil "EnablePatrolDebug") then { EnablePatrolDebug = false; };

// Cooldown map for squad leaders
if (isNil "PatrolCooldowns") then {
    PatrolCooldowns = createHashMap;
};

private _patrolDistance = PatrolSpawnDistance;
if (isNil "PatrolRadius") then { diag_log "[dynamicPatrols] PatrolRadius undefined - using 100"; PatrolRadius = 100; };
private _patrolRadius = PatrolRadius;
private _despawnDistance = PatrolDespawnDistance;

// Check if a unit is visible to any WEST player
_fnc_isVisibleToPlayers = {
    params ["_target"];
    (allPlayers select {side _x == west}) findIf {
        !terrainIntersectASL [AGLToASL eyePos _x, AGLToASL eyePos _target]
    } != -1
};


// Determine basic terrain type around a position
_fnc_getTerrainType = {
    params ["_pos"];
    private _houses = nearestObjects [_pos, ["House"], 50];
    if ((count _houses) > 10) exitWith {"Urban"};

    private _veg = nearestTerrainObjects [_pos, ["TREE","SMALL TREE","BUSH"], 30, false, true];
    if ((count _veg) > 15) exitWith {"Dense"};

    "Open"
};

while {missionNamespace getVariable ['PatrolScriptRunning', false]} do {
    private _patrols = missionNamespace getVariable ['ActivePatrols', []];

    // Calculate maximum patrols based on player count
    private _playerCount = count allPlayers;
    private _maxUnits = _playerCount * MaxPatrolsPerPlayer;
    private _maxGroups = ceil (_maxUnits / 6);
    private _currentGroups = count _patrols;

    // Find all WEST squad leaders
    private _leaders = allPlayers select {
        side _x == west && {leader group _x == _x}
    };

    private _maxSpawnsPerLoop = MaxSpawnsPerLoop;
    private _spawnedThisLoop = 0;

    for "_i" from 0 to ((count _leaders) - 1) do {
        if (_spawnedThisLoop >= _maxSpawnsPerLoop) exitWith {};

        private _leader = _leaders select _i;

        if ((_patrols findIf {!(isNull (_x select 1)) && {(_x select 1) isEqualTo _leader}}) == -1 && {_currentGroups < _maxGroups}) then {
            private _cooldown = PatrolCooldowns getOrDefault [_leader, 0];
            if (time >= _cooldown) then {
                private _spawnPos = [getPosATL _leader, _patrolDistance, getDir _leader] call BIS_fnc_relPos;

                if (!(surfaceIsWater _spawnPos) && {count (_spawnPos isFlatEmpty [1, -1, 0.5, 5, 0, false]) > 0}) then {
                    private _terrainType = [_spawnPos] call _fnc_getTerrainType;
                    private _unitTypes = missionNamespace getVariable [format ["Terrain_Type_%1", _terrainType], []];
                    if (_unitTypes isEqualTo [] || {(count _unitTypes) != 6}) then {
                        diag_log format ["[dynamicPatrols] Invalid or missing unit types for terrain '%1'", _terrainType];
                        continue;
                    };

                    if (
                        (_unitTypes findIf {
                            !(typeName _x == "STRING") || {!isClass (configFile >> "CfgVehicles" >> _x)}
                        }) == -1
                    ) then {
                        private _group = createGroup [east, true];
                        for "_j" from 0 to 5 do {
                            private _class = _unitTypes select _j;
                            _group createUnit [_class, _spawnPos, [], 0, 'NONE'];
                        };

                        if ((count units _group) < 6) then {
                            diag_log "[dynamicPatrols] Spawned patrol with fewer than 6 units";
                            deleteGroup _group;
                        } else {
                            [_group, _spawnPos, _patrolRadius, 4, [], true, true, false] call lambs_wp_fnc_taskPatrol;
                            (leader _group) setVariable ['lambs_danger_dangerRadio', true];
                            _group setVariable ['PatrolOwner', _leader];

                            _patrols pushBack [_group, _leader];
                            _currentGroups = _currentGroups + 1;
                            PatrolScriptLastSpawn = time;
                            PatrolCooldowns set [_leader, time + PatrolCooldownTime];
                            _spawnedThisLoop = _spawnedThisLoop + 1;
                            if (EnablePatrolDebug) then {
                                systemChat format ["Spawned patrol for: %1", name _leader];
                                diag_log format ["[dynamicPatrols] Spawned patrol for: %1", name _leader];
                            };
                        };
                    } else {
                        diag_log format ["[dynamicPatrols] Spawn failed at %1 terrain. UnitTypes: %2", _terrainType, _unitTypes];
                    };
                };
            };
        };
    };

    // Despawn patrols far from all WEST players
    for '_i' from ((count _patrols) - 1) to 0 step -1 do {
        private _entry = _patrols select _i;
        private _grp = _entry select 0;
        if (isNull _grp || {isNull leader _grp}) then {
            _patrols deleteAt _i;
        } else {
            private _close = allPlayers select {
                side _x == west && {leader _x distance leader _grp < _despawnDistance}
            };
            private _visible = (leader _grp) call _fnc_isVisibleToPlayers;
            if (_close isEqualTo [] && {!_visible}) then {
                {deleteVehicle _x} forEach units _grp;
                deleteGroup _grp;
                _patrols deleteAt _i;
                if (EnablePatrolDebug) then {
                    systemChat "Despawned patrol";
                    diag_log "[dynamicPatrols] Despawned patrol";
                };
            };
        };
    };

    _patrols = _patrols select {!(isNull (_x select 0)) && {!isNull leader (_x select 0)}};
    missionNamespace setVariable ['ActivePatrols', _patrols];
    sleep 60;
};
