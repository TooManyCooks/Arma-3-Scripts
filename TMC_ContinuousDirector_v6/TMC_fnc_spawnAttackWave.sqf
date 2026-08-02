params [["_userConfig", createHashMap]];

if (!isServer) exitWith {
    createHashMapFromArray [
        ["success", false],
        ["groups", []],
        ["vehicles", []],
        ["aircraft", []],
        ["failedSpawns", ["NOT_SERVER"]]
    ]
};

if !(_userConfig isEqualType createHashMap) exitWith {
    createHashMapFromArray [
        ["success", false],
        ["groups", []],
        ["vehicles", []],
        ["aircraft", []],
        ["failedSpawns", ["INVALID_CONFIG"]]
    ]
};

private _defaults = createHashMapFromArray [
    ["center", objNull],
    ["side", east],
    ["targetSide", west],
    ["minSpawnRadius", 0],
    ["maxSpawnRadius", 850],
    ["minPlayerDistance", 100],
    ["visibilityMaxDistance", 1800],
    ["visibilityThreshold", 0.05],
    ["attemptsPerGroup", 60],
    ["groupSeparation", 45],
    ["infantryGroupCount", 0],
    ["vehicleGroupCount", 0],
    ["aircraftGroupCount", 0],
    ["infantryTemplates", []],
    ["vehicleTemplates", []],
    ["aircraftTemplates", []],
    ["airMinSpawnRadius", 1800],
    ["airMaxSpawnRadius", 2600],
    ["airSpawnAltitude", 250],
    ["airSpeed", 90],
    ["rushRange", 1800],
    ["rushCycle", 10],
    ["rushOnlyPlayers", false],
    ["lambsReinforcement", true],
    ["lambsKnowledgeSeedChance", 0.25],
    ["debugMode", "NONE"],
    ["waveId", -1],
    ["onGroupSpawned", {}],
    ["onComplete", {}]
];

private _config = createHashMap;
{ _config set [_x, _defaults get _x] } forEach keys _defaults;
{ _config set [_x, _userConfig get _x] } forEach keys _userConfig;

private _centerRef = _config get "center";
private _centerPos = _centerRef call CBA_fnc_getPos;

if ((count _centerPos) < 2) exitWith {
    createHashMapFromArray [
        ["success", false],
        ["groups", []],
        ["vehicles", []],
        ["aircraft", []],
        ["failedSpawns", ["INVALID_CENTER"]]
    ]
};

_centerPos resize 3;
_centerPos set [2, 0];

private _side = _config get "side";
private _targetSide = _config get "targetSide";
private _minRadius = (_config get "minSpawnRadius") max 0;
private _maxRadius = (_config get "maxSpawnRadius") max _minRadius;
private _minPlayerDistance = (_config get "minPlayerDistance") max 0;
private _visibilityMaxDistance = (_config get "visibilityMaxDistance") max 0;
private _visibilityThreshold = _config get "visibilityThreshold";
private _attempts = round ((_config get "attemptsPerGroup") max 1);
private _groupSeparation = (_config get "groupSeparation") max 0;
private _airMinRadius = (_config get "airMinSpawnRadius") max 500;
private _airMaxRadius = (_config get "airMaxSpawnRadius") max _airMinRadius;
private _airAltitude = (_config get "airSpawnAltitude") max 100;
private _airSpeed = (_config get "airSpeed") max 20;
private _rushRange = (_config get "rushRange") max 100;
private _rushCycle = (_config get "rushCycle") max 2;
private _rushOnlyPlayers = _config get "rushOnlyPlayers";
private _hasLAMBSRush = !isNil "lambs_wp_fnc_taskRush";

private _reserved = [];
private _spawnedGroups = [];
private _spawnedVehicles = [];
private _spawnedAircraft = [];
private _failed = [];

private _livingPlayers = ([] call CBA_fnc_players) select {
    !isNull _x && { alive _x }
};

private _fnc_pickWeighted = {
    params ["_templates"];

    private _weighted = [];
    {
        if (_x isEqualType createHashMap) then {
            private _weight = _x getOrDefault ["weight", 1];
            if (_weight > 0) then {
                _weighted append [_x, _weight];
            };
        };
    } forEach _templates;

    if (_weighted isEqualTo []) exitWith { createHashMap };
    _weighted call BIS_fnc_selectRandomWeighted
};

private _fnc_hidden = {
    params ["_candidate", "_kind", "_sampleRadius", "_sampleHeight", "_players"];

    private _viewers = _players select {
        _x distance2D _candidate <= _visibilityMaxDistance
    };

    if (_viewers isEqualTo []) exitWith { true };

    private _samples = [
        [0, 0, 0],
        [_sampleRadius, 0, 0],
        [-_sampleRadius, 0, 0],
        [0, _sampleRadius, 0],
        [0, -_sampleRadius, 0]
    ];

    private _heights = [_sampleHeight];
    if (_kind isEqualTo "VEHICLE") then {
        _heights pushBack (_sampleHeight + 1.5);
    };

    private _hidden = true;

    {
        private _viewer = _x;
        private _eye = eyePos _viewer;
        private _ignored = vehicle _viewer;

        if (_ignored isEqualTo _viewer) then {
            _ignored = objNull;
        };

        {
            private _height = _x;

            {
                private _targetAGL = [
                    (_candidate select 0) + (_x select 0),
                    (_candidate select 1) + (_x select 1),
                    _height
                ];

                private _visibility = [
                    _viewer,
                    "VIEW",
                    _ignored
                ] checkVisibility [
                    _eye,
                    AGLToASL _targetAGL
                ];

                if (_visibility > _visibilityThreshold) exitWith {
                    _hidden = false;
                };
            } forEach _samples;

            if (!_hidden) exitWith {};
        } forEach _heights;

        if (!_hidden) exitWith {};
    } forEach _viewers;

    _hidden
};

private _fnc_findGroundPosition = {
    params ["_kind", "_template", "_players"];

    private _isVehicle = _kind isEqualTo "VEHICLE";
    private _objectClearance = _template getOrDefault [
        "objectClearance",
        if (_isVehicle) then { 15 } else { 8 }
    ];
    private _terrainClearance = _template getOrDefault [
        "terrainClearance",
        if (_isVehicle) then { 8 } else { 3 }
    ];
    private _maxGradient = _template getOrDefault [
        "maxGradient",
        if (_isVehicle) then { 0.16 } else { 0.32 }
    ];
    private _sampleRadius = _template getOrDefault ["visibilityRadius", 14];
    private _sampleHeight = _template getOrDefault [
        "visibilityHeight",
        if (_isVehicle) then { 2.5 } else { 1.3 }
    ];

    private _accepted = [];
    private _failurePosition = [-10000, -10000, 0];

    for "_attempt" from 1 to _attempts do {
        private _candidate = [
            _centerPos,
            _minRadius,
            _maxRadius,
            _objectClearance,
            0,
            _maxGradient,
            0,
            [],
            [_failurePosition, _failurePosition]
        ] call BIS_fnc_findSafePos;

        private _valid = !(_candidate isEqualTo _failurePosition);

        if (_valid) then {
            _candidate resize 3;
            _candidate set [2, 0];

            if (_isVehicle && { _template getOrDefault ["preferRoad", true] }) then {
                private _roads = _candidate nearRoads (
                    _template getOrDefault ["roadSearchRadius", 80]
                );

                if (_roads isEqualTo []) then {
                    _valid = false;
                } else {
                    _candidate = getPosATL (_roads select 0);
                    _candidate set [2, 0];
                };
            };
        };

        if (_valid && { surfaceIsWater _candidate }) then {
            _valid = false;
        };

        if (
            _valid
            && {
                _players findIf {
                    _x distance2D _candidate < _minPlayerDistance
                } >= 0
            }
        ) then {
            _valid = false;
        };

        if (
            _valid
            && {
                _reserved findIf {
                    _x distance2D _candidate < _groupSeparation
                } >= 0
            }
        ) then {
            _valid = false;
        };

        if (
            _valid
            && {
                !(
                    nearestObjects [
                        _candidate,
                        ["Man", "LandVehicle", "Air", "Ship", "StaticWeapon", "Building", "House", "ThingX"],
                        _objectClearance,
                        true
                    ] isEqualTo []
                )
            }
        ) then {
            _valid = false;
        };

        if (
            _valid
            && {
                !(
                    nearestTerrainObjects [
                        _candidate,
                        ["BUILDING", "BUNKER", "FENCE", "FORTRESS", "HOUSE", "ROCK", "ROCKS", "TREE", "WALL"],
                        _terrainClearance,
                        false,
                        true
                    ] isEqualTo []
                )
            }
        ) then {
            _valid = false;
        };

        if (
            _valid
            && {
                !([_candidate, _kind, _sampleRadius, _sampleHeight, _players] call _fnc_hidden)
            }
        ) then {
            _valid = false;
        };

        if (_valid) exitWith {
            _accepted = _candidate;
        };
    };

    _accepted
};

private _fnc_findAirPosition = {
    private _angle = random 360;
    private _radius = _airMinRadius + random (_airMaxRadius - _airMinRadius);
    private _position = _centerPos getPos [_radius, _angle];
    _position resize 3;
    _position set [2, _airAltitude];
    _position
};

private _fnc_taskInfantry = {
    params ["_group"];

    if (_config get "lambsReinforcement") then {
        _group setVariable ["lambs_danger_enableGroupReinforce", true, true];
    };

    {
        _x enableStamina false;
        _x enableFatigue false;
        _x setVariable ["lambs_danger_dangerRadio", true, true];
    } forEach units _group;

    [_group] call CBA_fnc_clearWaypoints;

    _group setBehaviourStrong "AWARE";
    _group setCombatMode "YELLOW";
    _group setSpeedMode "FULL";

    if (_hasLAMBSRush) then {
        private _rushHandle = [
            _group,
            _rushRange,
            _rushCycle,
            [],
            _centerPos,
            _rushOnlyPlayers
        ] spawn lambs_wp_fnc_taskRush;

        _group setVariable ["TMC_rushHandle", _rushHandle];
    } else {
        private _waypoint = _group addWaypoint [_centerPos, 0];
        _waypoint setWaypointType "MOVE";
        _waypoint setWaypointBehaviour "AWARE";
        _waypoint setWaypointCombatMode "YELLOW";
        _waypoint setWaypointSpeed "FULL";
        _group setCurrentWaypoint _waypoint;
        _group setVariable ["TMC_attackWaypoint", _waypoint];
        _group move _centerPos;
    };

    _group setVariable ["TMC_attackTargetPosition", +_centerPos];
};

private _fnc_taskVehicle = {
    params ["_group"];

    [_group] call CBA_fnc_clearWaypoints;
    _group setBehaviourStrong "COMBAT";
    _group setCombatMode "RED";
    _group setSpeedMode "FULL";

    private _waypoint = _group addWaypoint [_centerPos, 0];
    _waypoint setWaypointType "SAD";
    _waypoint setWaypointBehaviour "COMBAT";
    _waypoint setWaypointCombatMode "RED";
    _waypoint setWaypointSpeed "FULL";
    _waypoint setWaypointCompletionRadius 25;
    _group setCurrentWaypoint _waypoint;
    _group setVariable ["TMC_attackWaypoint", _waypoint];
    _group setVariable ["TMC_attackTargetPosition", +_centerPos];
};

private _fnc_taskAircraft = {
    params ["_group", "_aircraft"];

    [_group] call CBA_fnc_clearWaypoints;
    _group setBehaviourStrong "COMBAT";
    _group setCombatMode "RED";
    _group setSpeedMode "FULL";

    _aircraft flyInHeight _airAltitude;

    private _waypoint = _group addWaypoint [_centerPos, 0];
    _waypoint setWaypointType "SAD";
    _waypoint setWaypointBehaviour "COMBAT";
    _waypoint setWaypointCombatMode "RED";
    _waypoint setWaypointSpeed "FULL";
    _waypoint setWaypointCompletionRadius 100;
    _group setCurrentWaypoint _waypoint;
    _group setVariable ["TMC_attackWaypoint", _waypoint];
    _group setVariable ["TMC_attackTargetPosition", +_centerPos];
};

private _fnc_spawnInfantry = {
    params ["_template", "_position"];

    private _classes = +(_template getOrDefault ["units", []]);
    if (_classes isEqualTo []) exitWith { grpNull };

    private _group = [
        _position,
        _side,
        _classes,
        [],
        [],
        [],
        [],
        [],
        _position getDir _centerPos,
        true
    ] call BIS_fnc_spawnGroup;

    if (isNull _group) exitWith { grpNull };
    _group deleteGroupWhenEmpty true;

    private _skill = _template getOrDefault ["skill", [0.4, 0.55]];
    {
        private _value = if (_skill isEqualType []) then {
            (_skill select 0) + random ((_skill select 1) - (_skill select 0))
        } else {
            _skill
        };
        _x setSkill ((_value max 0) min 1);
    } forEach units _group;

    [_group] call _fnc_taskInfantry;

    if (
        random 1 < (_config get "lambsKnowledgeSeedChance")
    ) then {
        private _targets = _livingPlayers select {
            side group _x isEqualTo _targetSide
        };

        if !(_targets isEqualTo []) then {
            leader _group reveal [_targets select 0, 1.25];
        };
    };

    _group
};

private _fnc_spawnVehicle = {
    params ["_template", "_position"];

    private _class = _template getOrDefault ["vehicleClass", ""];
    if (_class isEqualTo "") exitWith { [objNull, grpNull] };

    private _vehicle = createVehicle [_class, _position, [], 0, "NONE"];
    if (isNull _vehicle) exitWith { [objNull, grpNull] };

    _vehicle setDir (_position getDir _centerPos);
    createVehicleCrew _vehicle;

    private _group = group effectiveCommander _vehicle;

    if (isNull _group) then {
        deleteVehicle _vehicle;
        [objNull, grpNull]
    } else {
        _group deleteGroupWhenEmpty true;
        [_group] call _fnc_taskVehicle;
        [_vehicle, _group]
    }
};

private _fnc_spawnAircraft = {
    params ["_template", "_position"];

    private _class = _template getOrDefault ["aircraftClass", ""];
    if (_class isEqualTo "") exitWith { [objNull, grpNull] };

    private _aircraft = createVehicle [_class, _position, [], 0, "FLY"];
    if (isNull _aircraft) exitWith { [objNull, grpNull] };

    _aircraft setPosATL _position;
    _aircraft setDir (_position getDir _centerPos);
    createVehicleCrew _aircraft;

    private _group = group effectiveCommander _aircraft;

    if (isNull _group) then {
        deleteVehicle _aircraft;
        [objNull, grpNull]
    } else {
        _group deleteGroupWhenEmpty true;
        _aircraft flyInHeight _airAltitude;
        _aircraft setVelocityModelSpace [0, _airSpeed, 0];
        [_group, _aircraft] call _fnc_taskAircraft;
        [_aircraft, _group]
    }
};

private _infantryOperations = round ((_config get "infantryGroupCount") max 0);
private _vehicleOperations = round ((_config get "vehicleGroupCount") max 0);
private _airOperations = round ((_config get "aircraftGroupCount") max 0);

for "_index" from 1 to _infantryOperations do {
    private _template = [_config get "infantryTemplates"] call _fnc_pickWeighted;

    if ((count _template) isEqualTo 0) then {
        _failed pushBack ["INFANTRY", _index, "NO_TEMPLATE"];
    } else {
        private _position = ["INFANTRY", _template, _livingPlayers] call _fnc_findGroundPosition;

        if (_position isEqualTo []) then {
            _failed pushBack ["INFANTRY", _index, "NO_HIDDEN_POSITION"];
        } else {
            private _group = [_template, _position] call _fnc_spawnInfantry;

            if (isNull _group) then {
                _failed pushBack ["INFANTRY", _index, "SPAWN_FAILED"];
            } else {
                _reserved pushBack _position;
                _spawnedGroups pushBack _group;
                [_group, "INFANTRY", _template, _position, objNull, _config] call (_config get "onGroupSpawned");
            };
        };
    };
};

for "_index" from 1 to _vehicleOperations do {
    private _template = [_config get "vehicleTemplates"] call _fnc_pickWeighted;

    if ((count _template) isEqualTo 0) then {
        _failed pushBack ["VEHICLE", _index, "NO_TEMPLATE"];
    } else {
        private _position = ["VEHICLE", _template, _livingPlayers] call _fnc_findGroundPosition;

        if (_position isEqualTo []) then {
            _failed pushBack ["VEHICLE", _index, "NO_HIDDEN_POSITION"];
        } else {
            private _spawn = [_template, _position] call _fnc_spawnVehicle;
            _spawn params ["_vehicle", "_group"];

            if (isNull _vehicle || { isNull _group }) then {
                _failed pushBack ["VEHICLE", _index, "SPAWN_FAILED"];
            } else {
                _reserved pushBack _position;
                _spawnedVehicles pushBack _vehicle;
                _spawnedGroups pushBack _group;
                [_group, "VEHICLE", _template, _position, _vehicle, _config] call (_config get "onGroupSpawned");
            };
        };
    };
};

for "_index" from 1 to _airOperations do {
    private _template = [_config get "aircraftTemplates"] call _fnc_pickWeighted;

    if ((count _template) isEqualTo 0) then {
        _failed pushBack ["AIR", _index, "NO_TEMPLATE"];
    } else {
        private _position = call _fnc_findAirPosition;
        private _spawn = [_template, _position] call _fnc_spawnAircraft;
        _spawn params ["_aircraft", "_group"];

        if (isNull _aircraft || { isNull _group }) then {
            _failed pushBack ["AIR", _index, "SPAWN_FAILED"];
        } else {
            _spawnedAircraft pushBack _aircraft;
            _spawnedGroups pushBack _group;
            [_group, "AIR", _template, _position, _aircraft, _config] call (_config get "onGroupSpawned");
        };
    };
};

private _result = createHashMapFromArray [
    ["success", _failed isEqualTo []],
    ["groups", _spawnedGroups],
    ["vehicles", _spawnedVehicles],
    ["aircraft", _spawnedAircraft],
    ["failedSpawns", _failed]
];

[_result, _config] call (_config get "onComplete");
_result
