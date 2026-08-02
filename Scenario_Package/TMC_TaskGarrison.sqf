if (!isServer) exitWith {};

params [["_trigger", objNull, [objNull]]];

if (isNull _trigger) exitWith {
    diag_log "[TMC Task Garrison] Invalid trigger passed to script.";
};

if (_trigger getVariable ["TMC_garrisonCreated", false]) exitWith {
    diag_log format ["[TMC Task Garrison] Garrison already created for %1.", _trigger];
};

if (isNil "ace_ai_fnc_garrison") exitWith {
    diag_log "[TMC Task Garrison] ACE garrison function was not found.";
};

private _enemySide = east;
private _droidsPerPlayer = 2;
private _minimumDroids = 6;
private _center = getPosATL _trigger;
private _triggerArea = triggerArea _trigger;
private _radius = (((_triggerArea select 0) max (_triggerArea select 1)) max 25);

private _players = if (!isNil "CBA_fnc_players") then {
    [] call CBA_fnc_players
} else {
    allPlayers select { !(_x isKindOf "HeadlessClient_F") }
};

private _playerCount = count _players;
private _desiredDroids = round ((_playerCount * _droidsPerPlayer) max _minimumDroids);
private _buildings = nearestObjects [_center, ["House", "Building"], _radius];
private _availablePositions = [];

{
    private _positions = if (!isNil "CBA_fnc_buildingPositions") then {
        [_x] call CBA_fnc_buildingPositions
    } else {
        _x buildingPos -1
    };

    {
        if ((_x nearEntities ["CAManBase", 1.5]) isEqualTo []) then {
            _availablePositions pushBackUnique _x;
        };
    } forEach _positions;
} forEach _buildings;

private _availablePositionCount = count _availablePositions;
_desiredDroids = _desiredDroids min _availablePositionCount;

if (_desiredDroids < 1) exitWith {
    diag_log format [
        "[TMC Task Garrison] No available building positions within %1 meters of %2.",
        _radius,
        _trigger
    ];
};

private _b2Count = floor (_desiredDroids / 12);
private _atCount = floor (_desiredDroids / 10);
private _sbb3Count = floor (_desiredDroids / 8);
private _arCount = floor (_desiredDroids / 5);
private _e5Count = (_desiredDroids - _b2Count - _atCount - _sbb3Count - _arCount) max 0;
private _spawnClasses = [];

for "_i" from 1 to _e5Count do { _spawnClasses pushBack "JLTS_Droid_B1_E5"; };
for "_i" from 1 to _arCount do { _spawnClasses pushBack "JLTS_Droid_B1_AR"; };
for "_i" from 1 to _sbb3Count do { _spawnClasses pushBack "JLTS_Droid_B1_SBB3"; };
for "_i" from 1 to _atCount do { _spawnClasses pushBack "JLTS_Droid_B1_AT"; };
for "_i" from 1 to _b2Count do { _spawnClasses pushBack "ls_droid_b2"; };

_spawnClasses = if (!isNil "CBA_fnc_shuffle") then {
    [_spawnClasses] call CBA_fnc_shuffle
} else {
    [_spawnClasses] call BIS_fnc_arrayShuffle
};

_trigger setVariable ["TMC_garrisonCreated", true, true];

private _group = [_center, _enemySide, _spawnClasses, [], [], [], [], [], random 360] call BIS_fnc_spawnGroup;

if (isNull _group) exitWith {
    _trigger setVariable ["TMC_garrisonCreated", false, true];
    diag_log "[TMC Task Garrison] BIS_fnc_spawnGroup failed to create the group.";
};

_group deleteGroupWhenEmpty true;
private _spawnedUnits = units _group;
private _notGarrisoned = [_center, nil, _spawnedUnits, _radius, 2, false, true] call ace_ai_fnc_garrison;

{
    if (!isNull _x) then { deleteVehicle _x; };
} forEach _notGarrisoned;

private _garrisonedUnits = _spawnedUnits select { !isNull _x && { alive _x } };
_trigger setVariable ["TMC_garrisonUnits", _garrisonedUnits, true];
_trigger setVariable ["TMC_garrisonGroup", _group, true];

diag_log format [
    "[TMC Task Garrison] Players: %1 | Requested: %2 | Available positions: %3 | Garrisoned: %4",
    _playerCount,
    _desiredDroids,
    _availablePositionCount,
    count _garrisonedUnits
];
