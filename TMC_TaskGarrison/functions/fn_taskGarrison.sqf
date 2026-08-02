if (!isServer) exitWith {};

params [
    ["_trigger", objNull, [objNull]]
];

if (isNull _trigger) exitWith {
    diag_log "[TMC Task Garrison] Call rejected because the trigger was invalid.";
};

if (
    isNil "CBA_fnc_players"
    || { isNil "CBA_fnc_buildingPositions" }
    || { isNil "CBA_fnc_shuffle" }
    || { isNil "ace_ai_fnc_garrison" }
) exitWith {
    diag_log "[TMC Task Garrison] Required CBA or ACE functions were not found.";
};

if (_trigger getVariable ["TMC_garrisonCreated", false]) exitWith {
    diag_log format [
        "[TMC Task Garrison] Garrison already created for %1.",
        _trigger
    ];
};

private _enemySide = east;
private _droidsPerPlayer = 2;
private _minimumDroids = 6;

private _center = getPosATL _trigger;
private _triggerArea = triggerArea _trigger;
private _radius = (
    (_triggerArea select 0)
    max
    (_triggerArea select 1)
) max 25;

private _players = [] call CBA_fnc_players;
private _playerCount = count _players;
private _desiredDroids = (
    _playerCount * _droidsPerPlayer
) max _minimumDroids;

private _buildings = nearestObjects [
    _center,
    ["House", "Building"],
    _radius
];

private _availablePositions = [];

{
    private _building = _x;
    private _positions = [_building] call CBA_fnc_buildingPositions;

    {
        private _position = _x;

        if (
            (_position nearEntities ["CAManBase", 1.5])
            isEqualTo []
        ) then {
            _availablePositions pushBackUnique _position;
        };
    } forEach _positions;
} forEach _buildings;

private _availablePositionCount = count _availablePositions;
_desiredDroids = _desiredDroids min _availablePositionCount;

if (_desiredDroids < 1) exitWith {
    diag_log format [
        "[TMC Task Garrison] No available building positions near %1.",
        _trigger
    ];
};

private _b2Count = floor (_desiredDroids / 12);
private _atCount = floor (_desiredDroids / 10);
private _sbb3Count = floor (_desiredDroids / 8);
private _arCount = floor (_desiredDroids / 5);

private _e5Count = (
    _desiredDroids
    - _b2Count
    - _atCount
    - _sbb3Count
    - _arCount
) max 0;

private _spawnClasses = [];

if (_e5Count > 0) then {
    for "_i" from 1 to _e5Count do {
        _spawnClasses pushBack "JLTS_Droid_B1_E5";
    };
};

if (_arCount > 0) then {
    for "_i" from 1 to _arCount do {
        _spawnClasses pushBack "JLTS_Droid_B1_AR";
    };
};

if (_sbb3Count > 0) then {
    for "_i" from 1 to _sbb3Count do {
        _spawnClasses pushBack "JLTS_Droid_B1_SBB3";
    };
};

if (_atCount > 0) then {
    for "_i" from 1 to _atCount do {
        _spawnClasses pushBack "JLTS_Droid_B1_AT";
    };
};

if (_b2Count > 0) then {
    for "_i" from 1 to _b2Count do {
        _spawnClasses pushBack "ls_droid_b2";
    };
};

_spawnClasses = [_spawnClasses] call CBA_fnc_shuffle;

_trigger setVariable ["TMC_garrisonCreated", true];

private _group = [
    _center,
    _enemySide,
    _spawnClasses,
    [],
    [],
    [],
    [],
    [],
    random 360
] call BIS_fnc_spawnGroup;

if (isNull _group) exitWith {
    _trigger setVariable ["TMC_garrisonCreated", false];
    diag_log "[TMC Task Garrison] Failed to create the droid group.";
};

_group deleteGroupWhenEmpty true;

private _spawnedUnits = units _group;

private _notGarrisoned = [
    _center,
    nil,
    _spawnedUnits,
    _radius,
    2,
    false,
    true
] call ace_ai_fnc_garrison;

{
    if (!isNull _x) then {
        deleteVehicle _x;
    };
} forEach _notGarrisoned;

private _garrisonedUnits = _spawnedUnits select {
    !isNull _x && { alive _x }
};

_trigger setVariable [
    "TMC_garrisonUnits",
    _garrisonedUnits
];

_trigger setVariable [
    "TMC_garrisonGroup",
    _group
];

diag_log format [
    "[TMC Task Garrison] %1 total players. %2 droids requested. %3 positions found. %4 droids garrisoned in one group.",
    _playerCount,
    _desiredDroids,
    _availablePositionCount,
    count _garrisonedUnits
];
