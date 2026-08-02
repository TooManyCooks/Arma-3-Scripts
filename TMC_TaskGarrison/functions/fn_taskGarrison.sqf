if (!isServer) exitWith {};

params [
    ["_trigger", objNull, [objNull]],
    ["_radiusOverride", -1, [0]]
];

if (isNull _trigger) exitWith {
    diag_log "[TMC Task Garrison] ERROR: Invalid trigger passed to the script.";
};

if (_trigger getVariable ["TMC_garrisonCreated", false]) exitWith {
    diag_log format [
        "[TMC Task Garrison] Ignored duplicate activation for %1.",
        _trigger
    ];
};

private _enemySide = east;
private _droidsPerPlayer = 2;
private _minimumDroids = 6;

private _center = getPosATL _trigger;
private _triggerArea = triggerArea _trigger;
private _triggerRadius = (
    (_triggerArea select 0)
    max
    (_triggerArea select 1)
) max 25;
private _radius = if (_radiusOverride > 0) then {
    _radiusOverride
} else {
    _triggerRadius
};

private _players = if (!isNil "CBA_fnc_players") then {
    [] call CBA_fnc_players
} else {
    allPlayers select {
        !(_x isKindOf "HeadlessClient_F")
    }
};

private _playerCount = count _players;
private _desiredDroids = round (
    (_playerCount * _droidsPerPlayer) max _minimumDroids
);

private _buildings = nearestObjects [
    _center,
    ["House", "Building"],
    _radius
];

private _availablePositions = [];

{
    private _building = _x;
    private _positions = if (!isNil "CBA_fnc_buildingPositions") then {
        [_building] call CBA_fnc_buildingPositions
    } else {
        _building buildingPos -1
    };

    {
        private _position = _x;

        if (
            !(_position isEqualTo [0, 0, 0])
            && {
                (_position nearEntities ["CAManBase", 1.5])
                isEqualTo []
            }
        ) then {
            _availablePositions pushBackUnique _position;
        };
    } forEach _positions;
} forEach _buildings;

private _availablePositionCount = count _availablePositions;
_desiredDroids = _desiredDroids min _availablePositionCount;

if (_desiredDroids < 1) exitWith {
    diag_log format [
        "[TMC Task Garrison] ERROR: No free building positions found. Trigger=%1 Radius=%2 Buildings=%3",
        _trigger,
        _radius,
        count _buildings
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

for "_i" from 1 to _e5Count do {
    _spawnClasses pushBack "JLTS_Droid_B1_E5";
};

for "_i" from 1 to _arCount do {
    _spawnClasses pushBack "JLTS_Droid_B1_AR";
};

for "_i" from 1 to _sbb3Count do {
    _spawnClasses pushBack "JLTS_Droid_B1_SBB3";
};

for "_i" from 1 to _atCount do {
    _spawnClasses pushBack "JLTS_Droid_B1_AT";
};

for "_i" from 1 to _b2Count do {
    _spawnClasses pushBack "ls_droid_b2";
};

if (!isNil "CBA_fnc_shuffle") then {
    _spawnClasses = [_spawnClasses] call CBA_fnc_shuffle;
} else {
    _spawnClasses = _spawnClasses call BIS_fnc_arrayShuffle;
};

_trigger setVariable ["TMC_garrisonCreated", true, true];

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
    _trigger setVariable ["TMC_garrisonCreated", false, true];
    diag_log "[TMC Task Garrison] ERROR: BIS_fnc_spawnGroup failed to create the droid group.";
};

_group deleteGroupWhenEmpty true;

private _spawnedUnits = units _group;
private _notGarrisoned = [];

if (!isNil "ace_ai_fnc_garrison") then {
    _notGarrisoned = [
        _center,
        nil,
        _spawnedUnits,
        _radius,
        2,
        false,
        true
    ] call ace_ai_fnc_garrison;

    if !(_notGarrisoned isEqualType []) then {
        _notGarrisoned = [];
    };
} else {
    private _positions = +_availablePositions;

    if (!isNil "CBA_fnc_shuffle") then {
        _positions = [_positions] call CBA_fnc_shuffle;
    } else {
        _positions = _positions call BIS_fnc_arrayShuffle;
    };

    {
        private _unit = _x;
        private _index = _forEachIndex;

        if (_index < count _positions) then {
            doStop _unit;
            _unit setPosASL (AGLToASL (_positions select _index));
            _unit disableAI "PATH";
        } else {
            _notGarrisoned pushBack _unit;
        };
    } forEach _spawnedUnits;
};

{
    if (!isNull _x) then {
        deleteVehicle _x;
    };
} forEach _notGarrisoned;

private _garrisonedUnits = units _group select {
    !isNull _x && { alive _x }
};

if (_garrisonedUnits isEqualTo []) then {
    deleteGroup _group;
    _trigger setVariable ["TMC_garrisonCreated", false, true];
} else {
    _trigger setVariable ["TMC_garrisonUnits", _garrisonedUnits, true];
    _trigger setVariable ["TMC_garrisonGroup", _group, true];
};

diag_log format [
    "[TMC Task Garrison] Trigger=%1 Players=%2 Radius=%3 Buildings=%4 Positions=%5 Requested=%6 Garrisoned=%7",
    _trigger,
    _playerCount,
    _radius,
    count _buildings,
    _availablePositionCount,
    _desiredDroids,
    count _garrisonedUnits
];
