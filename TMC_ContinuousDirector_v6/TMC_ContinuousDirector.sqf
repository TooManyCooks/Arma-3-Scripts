if (!isServer) exitWith {};

params [
    ["_mode", "START", [""]],
    ["_center", objNull],
    ["_overrides", createHashMap]
];

_mode = toUpper _mode;
private _stateName = "TMC_ContinuousDirector_State_v6";

if (_mode in ["STOP", "PAUSE", "RESUME", "STATUS"]) exitWith {
    private _state = missionNamespace getVariable [_stateName, createHashMap];

    if ((count _state) isEqualTo 0) exitWith {
        if (_mode isEqualTo "STATUS") then {
            diag_log "[TMC v6 Director] Director state was not found.";
        };
    };

    switch (_mode) do {
        case "STOP": {
            _state set ["running", false];

            private _pfhHandle = _state getOrDefault ["pfhHandle", -1];
            if (_pfhHandle >= 0) then {
                [_pfhHandle] call CBA_fnc_removePerFrameHandler;
            };

            private _entityCreatedEH = _state getOrDefault ["entityCreatedEH", -1];
            if (_entityCreatedEH >= 0) then {
                removeMissionEventHandler ["EntityCreated", _entityCreatedEH];
            };

            {
                if (!scriptDone _x) then {
                    terminate _x;
                };
            } forEach (
                (_state getOrDefault ["infantryHandles", []])
                + (_state getOrDefault ["vehicleHandles", []])
                + (_state getOrDefault ["airHandles", []])
            );

            _state set ["pfhHandle", -1];
            _state set ["entityCreatedEH", -1];
            _state set ["infantryHandles", []];
            _state set ["vehicleHandles", []];
            _state set ["airHandles", []];
            missionNamespace setVariable [_stateName, _state];
            diag_log "[TMC v6 Director] Stopped.";
        };

        case "PAUSE": {
            _state set ["paused", true];
            missionNamespace setVariable [_stateName, _state];
            diag_log "[TMC v6 Director] Paused by command.";
        };

        case "RESUME": {
            _state set ["paused", false];
            missionNamespace setVariable [_stateName, _state];
            diag_log "[TMC v6 Director] Resumed by command.";
        };

        case "STATUS": {
            diag_log format [
                "[TMC v6 Director] %1",
                _state getOrDefault ["snapshot", createHashMap]
            ];
        };
    };
};

if !(_mode isEqualTo "START") exitWith {};

if !(_overrides isEqualType createHashMap) exitWith {
    diag_log "[TMC v6 Director] START rejected because overrides were not a HashMap.";
};

private _oldState = missionNamespace getVariable [_stateName, createHashMap];
if ((count _oldState) > 0 && { _oldState getOrDefault ["running", false] }) exitWith {
    diag_log "[TMC v6 Director] START ignored because the director is already running.";
};

private _defaults = createHashMapFromArray [
    ["scalingMode", "AREA"],
    ["scalingSide", west],
    ["scalingRadius", 300],
    ["minimumScalingUnits", 1],
    ["enemySide", east],
    ["enemyRatio", 3],
    ["scalingUnitsPerVehicle", 10],
    ["maxActiveVehicles", 10],
    ["initialDelay", 2],
    ["evaluationInterval", 5],
    ["behaviorEvaluationInterval", 20],
    ["statusLogInterval", 60],
    ["minimumServerFPS", 18],
    ["estimatedInfantryPerGroup", 20],
    ["maxManagedGroups", 10],
    ["minSpawnRadius", 0],
    ["maxSpawnRadius", 850],
    ["minPlayerDistance", 100],
    ["visibilityMaxDistance", 1800],
    ["visibilityThreshold", 0.05],
    ["attemptsPerGroup", 60],
    ["groupSeparation", 45],
    ["airMinSpawnRadius", 1800],
    ["airMaxSpawnRadius", 2600],
    ["airSpawnAltitude", 250],
    ["airSpeed", 90],
    ["airActiveAltitude", 15],
    ["rushRange", 1800],
    ["rushCycle", 10],
    ["rushOnlyPlayers", false],
    ["ignoreAircraft", true],
    ["waveScript", "TMC_AttackWave_CloneWars.sqf"],
    ["debugMode", "NONE"]
];

private _config = createHashMap;
{ _config set [_x, _defaults get _x] } forEach keys _defaults;
{ _config set [_x, _overrides get _x] } forEach keys _overrides;

_config set [
    "maxManagedGroups",
    (((round (_config get "maxManagedGroups")) max 1) min 10)
];

private _centerPos = _center call CBA_fnc_getPos;
if ((count _centerPos) < 2) exitWith {
    diag_log "[TMC v6 Director] START rejected because the center reference was invalid.";
};

private _existingGroups = allGroups select {
    _x getVariable ["TMC_attackWaveManaged", false]
    && { units _x findIf { alive _x } >= 0 }
};

private _existingInfantryGroups = _existingGroups select {
    toUpper (_x getVariable ["TMC_attackWaveKind", ""]) isEqualTo "INFANTRY"
};

private _existingVehicleGroups = _existingGroups select {
    toUpper (_x getVariable ["TMC_attackWaveKind", ""]) isEqualTo "VEHICLE"
};

private _existingAirGroups = _existingGroups select {
    toUpper (_x getVariable ["TMC_attackWaveKind", ""]) isEqualTo "AIR"
};

private _existingManagedVehicles = vehicles select {
    alive _x && { _x getVariable ["TMC_attackWaveVehicle", false] }
};

private _existingManagedAircraft = vehicles select {
    alive _x && { _x getVariable ["TMC_attackWaveAircraft", false] }
};

private _knownAircraft = if (_config get "ignoreAircraft") then {
    vehicles select {
        alive _x && { _x isKindOf "Air" }
    }
} else {
    []
};

private _now = diag_tickTime;
private _state = createHashMapFromArray [
    ["running", true],
    ["paused", false],
    ["center", _center],
    ["config", _config],
    ["pfhHandle", -1],
    ["entityCreatedEH", -1],
    ["infantryHandles", []],
    ["vehicleHandles", []],
    ["airHandles", []],
    ["infantryGroups", _existingInfantryGroups],
    ["vehicleGroups", _existingVehicleGroups],
    ["airGroups", _existingAirGroups],
    ["managedVehicles", _existingManagedVehicles],
    ["managedAircraft", _existingManagedAircraft],
    ["knownAircraft", _knownAircraft],
    ["packageNumber", 0],
    ["nextEvaluation", _now + (_config get "initialDelay")],
    ["nextBehaviorCheck", _now + (_config get "initialDelay") + 5],
    ["nextStatusLog", _now + (_config get "statusLogInterval")],
    ["snapshot", createHashMapFromArray [["running", true], ["paused", false]]]
];

missionNamespace setVariable [_stateName, _state];

if (_config get "ignoreAircraft") then {
    {
        private _group = _x;
        {
            _group ignoreTarget _x;
        } forEach _knownAircraft;
    } forEach _existingInfantryGroups;
};

private _entityCreatedEH = -1;

if (_config get "ignoreAircraft") then {
    _entityCreatedEH = addMissionEventHandler ["EntityCreated", {
        params ["_entity"];

        if (
            !isServer
            || { isNull _entity }
            || { !(_entity isKindOf "Air") }
        ) exitWith {};

        private _stateName = "TMC_ContinuousDirector_State_v6";
        private _state = missionNamespace getVariable [_stateName, createHashMap];

        if (
            (count _state) isEqualTo 0
            || { !(_state getOrDefault ["running", false]) }
        ) exitWith {};

        private _knownAircraft = _state getOrDefault ["knownAircraft", []];
        _knownAircraft pushBackUnique _entity;
        _state set ["knownAircraft", _knownAircraft];

        {
            if (!isNull _x && { units _x findIf { alive _x } >= 0 }) then {
                _x ignoreTarget _entity;
            };
        } forEach (_state getOrDefault ["infantryGroups", []]);

        missionNamespace setVariable [_stateName, _state];
    }];
};

_state set ["entityCreatedEH", _entityCreatedEH];
missionNamespace setVariable [_stateName, _state];

private _fnc_evaluate = {
    params ["_args", "_pfhHandle"];
    _args params ["_stateName"];

    private _state = missionNamespace getVariable [_stateName, createHashMap];

    if ((count _state) isEqualTo 0) exitWith {
        [_pfhHandle] call CBA_fnc_removePerFrameHandler;
    };

    if !(_state getOrDefault ["running", false]) exitWith {
        [_pfhHandle] call CBA_fnc_removePerFrameHandler;
    };

    if (_state getOrDefault ["paused", false]) exitWith {};

    private _config = _state get "config";
    private _now = diag_tickTime;
    private _debugMode = toUpper (_config getOrDefault ["debugMode", "NONE"]);

    private _evaluationDue = _now >= (_state get "nextEvaluation");
    private _behaviorDue = _now >= (_state get "nextBehaviorCheck");
    private _statusDue = _debugMode in ["LOG", "MARKERS"]
        && { _now >= (_state get "nextStatusLog") };

    if !(_evaluationDue || _behaviorDue || _statusDue) exitWith {};

    if (_evaluationDue) then {
        _state set [
            "nextEvaluation",
            _now + ((_config get "evaluationInterval") max 1)
        ];
    };

    if (_behaviorDue) then {
        _state set [
            "nextBehaviorCheck",
            _now + ((_config get "behaviorEvaluationInterval") max 5)
        ];
    };

    if (_statusDue) then {
        _state set [
            "nextStatusLog",
            _now + ((_config get "statusLogInterval") max 10)
        ];
    };

    private _infantryHandles = (_state getOrDefault ["infantryHandles", []]) select {
        !scriptDone _x
    };
    private _vehicleHandles = (_state getOrDefault ["vehicleHandles", []]) select {
        !scriptDone _x
    };
    private _airHandles = (_state getOrDefault ["airHandles", []]) select {
        !scriptDone _x
    };

    private _infantryGroups = (_state getOrDefault ["infantryGroups", []]) select {
        !isNull _x && { units _x findIf { alive _x } >= 0 }
    };
    private _vehicleGroups = (_state getOrDefault ["vehicleGroups", []]) select {
        !isNull _x && { units _x findIf { alive _x } >= 0 }
    };
    private _airGroups = (_state getOrDefault ["airGroups", []]) select {
        !isNull _x && { units _x findIf { alive _x } >= 0 }
    };

    private _managedVehicles = (_state getOrDefault ["managedVehicles", []]) select {
        !isNull _x && { alive _x } && { canMove _x }
    };
    private _managedAircraft = (_state getOrDefault ["managedAircraft", []]) select {
        !isNull _x && { alive _x } && { canMove _x }
    };
    private _knownAircraft = (_state getOrDefault ["knownAircraft", []]) select {
        !isNull _x && { alive _x }
    };

    _state set ["infantryHandles", _infantryHandles];
    _state set ["vehicleHandles", _vehicleHandles];
    _state set ["airHandles", _airHandles];
    _state set ["infantryGroups", _infantryGroups];
    _state set ["vehicleGroups", _vehicleGroups];
    _state set ["airGroups", _airGroups];
    _state set ["managedVehicles", _managedVehicles];
    _state set ["managedAircraft", _managedAircraft];
    _state set ["knownAircraft", _knownAircraft];

    private _center = _state get "center";
    private _centerPos = _center call CBA_fnc_getPos;

    if ((count _centerPos) < 2) exitWith {
        diag_log "[TMC v6 Director] Center reference became invalid. Director stopped.";

        private _entityCreatedEH = _state getOrDefault ["entityCreatedEH", -1];
        if (_entityCreatedEH >= 0) then {
            removeMissionEventHandler ["EntityCreated", _entityCreatedEH];
        };

        _state set ["running", false];
        _state set ["entityCreatedEH", -1];
        missionNamespace setVariable [_stateName, _state];
        [_pfhHandle] call CBA_fnc_removePerFrameHandler;
    };

    _centerPos resize 3;
    _centerPos set [2, 0];

    private _scalingSide = _config get "scalingSide";
    private _enemySide = _config get "enemySide";
    private _scalingCount = 0;
    private _activeFriendlyAircraft = [];

    if (_evaluationDue || _statusDue) then {
        private _sideUnits = allUnits select {
            alive _x && { side group _x isEqualTo _scalingSide }
        };

        private _scalingMode = toUpper (_config get "scalingMode");
        private _scalingUnits = switch (_scalingMode) do {
            case "SIDE": {
                _sideUnits
            };

            case "RADIUS": {
                _sideUnits select {
                    _x distance2D _centerPos <= (_config get "scalingRadius")
                }
            };

            default {
                if (
                    (_center isEqualType objNull && { !isNull _center })
                    || { _center isEqualType "" && { markerShape _center != "" } }
                ) then {
                    _sideUnits select { _x inArea _center }
                } else {
                    _sideUnits select {
                        _x distance2D _centerPos <= (_config get "scalingRadius")
                    }
                }
            };
        };

        _scalingCount = count _scalingUnits;

        _activeFriendlyAircraft = vehicles select {
            !isNull _x
            && { alive _x }
            && { canMove _x }
            && { _x isKindOf "Air" }
            && { !isTouchingGround _x }
            && { (getPosATL _x select 2) >= (_config get "airActiveAltitude") }
            && {
                crew _x findIf {
                    alive _x && { side group _x isEqualTo _scalingSide }
                } >= 0
            }
        };
    } else {
        private _oldSnapshot = _state getOrDefault ["snapshot", createHashMap];
        _scalingCount = _oldSnapshot getOrDefault ["BLUFOR", 0];
    };

    if (_behaviorDue) then {
        private _hasLAMBSRush = !isNil "lambs_wp_fnc_taskRush";
        private _rushRange = (_config get "rushRange") max 100;
        private _rushCycle = (_config get "rushCycle") max 2;
        private _rushOnlyPlayers = _config get "rushOnlyPlayers";

        {
            private _group = _x;

            _group setBehaviourStrong "AWARE";
            _group setCombatMode "YELLOW";
            _group setSpeedMode "FULL";
            _group setVariable ["TMC_attackTargetPosition", +_centerPos];

            if (_hasLAMBSRush) then {
                private _rushHandle = _group getVariable ["TMC_rushHandle", scriptNull];

                if (scriptDone _rushHandle) then {
                    [_group] call CBA_fnc_clearWaypoints;

                    _rushHandle = [
                        _group,
                        _rushRange,
                        _rushCycle,
                        [],
                        _centerPos,
                        _rushOnlyPlayers
                    ] spawn lambs_wp_fnc_taskRush;

                    _group setVariable ["TMC_rushHandle", _rushHandle];
                };
            } else {
                private _waypoint = _group getVariable ["TMC_attackWaypoint", []];

                if (_waypoint isEqualTo [] || { count waypoints _group isEqualTo 0 }) then {
                    [_group] call CBA_fnc_clearWaypoints;
                    _waypoint = _group addWaypoint [_centerPos, 0];
                    _waypoint setWaypointType "MOVE";
                    _waypoint setWaypointBehaviour "AWARE";
                    _waypoint setWaypointCombatMode "YELLOW";
                    _waypoint setWaypointSpeed "FULL";
                    _group setVariable ["TMC_attackWaypoint", _waypoint];
                } else {
                    _waypoint setWaypointPosition [_centerPos, 0];
                };

                _group setCurrentWaypoint _waypoint;
                _group move _centerPos;
            };
        } forEach _infantryGroups;

        {
            private _group = _x;
            private _waypoint = _group getVariable ["TMC_attackWaypoint", []];

            if (_waypoint isEqualTo [] || { count waypoints _group isEqualTo 0 }) then {
                [_group] call CBA_fnc_clearWaypoints;
                _waypoint = _group addWaypoint [_centerPos, 0];
                _group setVariable ["TMC_attackWaypoint", _waypoint];
            } else {
                _waypoint setWaypointPosition [_centerPos, 0];
            };

            _waypoint setWaypointType "SAD";
            _waypoint setWaypointBehaviour "COMBAT";
            _waypoint setWaypointCombatMode "RED";
            _waypoint setWaypointSpeed "FULL";
            _waypoint setWaypointCompletionRadius 25;
            _group setCurrentWaypoint _waypoint;
            _group setVariable ["TMC_attackTargetPosition", +_centerPos];
        } forEach _vehicleGroups;

        {
            private _group = _x;
            private _waypoint = _group getVariable ["TMC_attackWaypoint", []];

            if (_waypoint isEqualTo [] || { count waypoints _group isEqualTo 0 }) then {
                [_group] call CBA_fnc_clearWaypoints;
                _waypoint = _group addWaypoint [_centerPos, 0];
                _group setVariable ["TMC_attackWaypoint", _waypoint];
            } else {
                _waypoint setWaypointPosition [_centerPos, 0];
            };

            _waypoint setWaypointType "SAD";
            _waypoint setWaypointBehaviour "COMBAT";
            _waypoint setWaypointCombatMode "RED";
            _waypoint setWaypointSpeed "FULL";
            _waypoint setWaypointCompletionRadius 100;
            _group setCurrentWaypoint _waypoint;
            _group setVariable ["TMC_attackTargetPosition", +_centerPos];
        } forEach _airGroups;

        {
            _x flyInHeight (_config get "airSpawnAltitude");
        } forEach _managedAircraft;
    };

    private _infantryCount = 0;
    {
        _infantryCount = _infantryCount + ({
            alive _x && { side group _x isEqualTo _enemySide }
        } count units _x);
    } forEach _infantryGroups;

    private _activeVehicles = _managedVehicles select {
        crew _x findIf { alive _x } >= 0
    };

    private _activeAircraft = _managedAircraft select {
        crew _x findIf { alive _x } >= 0
    };

    private _desiredInfantry = round (
        _scalingCount * (_config get "enemyRatio")
    );

    private _desiredVehicles = if (_scalingCount > 0) then {
        (ceil (
            _scalingCount
            / ((_config get "scalingUnitsPerVehicle") max 1)
        )) max 1
    } else {
        0
    };

    _desiredVehicles = _desiredVehicles min round (_config get "maxActiveVehicles");

    private _desiredAircraft = count _activeFriendlyAircraft;

    private _effectiveInfantry = _infantryCount
        + (count _infantryHandles * round (_config get "estimatedInfantryPerGroup"));
    private _effectiveVehicles = count _activeVehicles + count _vehicleHandles;
    private _effectiveAircraft = count _activeAircraft + count _airHandles;

    private _infantryDeficit = (_desiredInfantry - _effectiveInfantry) max 0;
    private _vehicleDeficit = (_desiredVehicles - _effectiveVehicles) max 0;
    private _airDeficit = (_desiredAircraft - _effectiveAircraft) max 0;

    private _usedGroups = count _infantryGroups
        + count _vehicleGroups
        + count _airGroups
        + count _infantryHandles
        + count _vehicleHandles
        + count _airHandles;

    private _maxGroups = round (_config get "maxManagedGroups");
    private _availableSlots = (_maxGroups - _usedGroups) max 0;
    private _fps = diag_fps;
    private _sentKind = "NONE";

    if (
        _evaluationDue
        && { _scalingCount >= round (_config get "minimumScalingUnits") }
        && { _availableSlots > 0 }
        && { _fps >= (_config get "minimumServerFPS") }
    ) then {
        private _kind = "";

        if (_airDeficit > 0) then {
            _kind = "AIR";
        } else {
            if (_vehicleDeficit > 0) then {
                _kind = "VEHICLE";
            } else {
                if (_infantryDeficit > 0) then {
                    _kind = "INFANTRY";
                };
            };
        };

        if !(_kind isEqualTo "") then {
            private _id = (_state get "packageNumber") + 1;
            private _request = createHashMapFromArray [
                ["kind", _kind],
                ["center", _center],
                ["enemySide", _enemySide],
                ["targetSide", _scalingSide],
                ["waveId", _id],
                ["minSpawnRadius", _config get "minSpawnRadius"],
                ["maxSpawnRadius", _config get "maxSpawnRadius"],
                ["minPlayerDistance", _config get "minPlayerDistance"],
                ["visibilityMaxDistance", _config get "visibilityMaxDistance"],
                ["visibilityThreshold", _config get "visibilityThreshold"],
                ["attemptsPerGroup", _config get "attemptsPerGroup"],
                ["groupSeparation", _config get "groupSeparation"],
                ["airMinSpawnRadius", _config get "airMinSpawnRadius"],
                ["airMaxSpawnRadius", _config get "airMaxSpawnRadius"],
                ["airSpawnAltitude", _config get "airSpawnAltitude"],
                ["airSpeed", _config get "airSpeed"],
                ["rushRange", _config get "rushRange"],
                ["rushCycle", _config get "rushCycle"],
                ["rushOnlyPlayers", _config get "rushOnlyPlayers"],
                ["debugMode", _debugMode]
            ];

            private _handle = [_request] execVM (_config get "waveScript");

            switch (_kind) do {
                case "INFANTRY": {
                    _infantryHandles pushBack _handle;
                    _state set ["infantryHandles", _infantryHandles];
                };

                case "VEHICLE": {
                    _vehicleHandles pushBack _handle;
                    _state set ["vehicleHandles", _vehicleHandles];
                };

                case "AIR": {
                    _airHandles pushBack _handle;
                    _state set ["airHandles", _airHandles];
                };
            };

            _state set ["packageNumber", _id];
            _sentKind = _kind;
        };
    };

    private _snapshot = createHashMapFromArray [
        ["running", true],
        ["paused", false],
        ["BLUFOR", _scalingCount],
        ["activeBLUFORAircraft", count _activeFriendlyAircraft],
        ["infantry", _infantryCount],
        ["desiredInfantry", _desiredInfantry],
        ["infantryDeficit", _infantryDeficit],
        ["vehicles", count _activeVehicles],
        ["desiredVehicles", _desiredVehicles],
        ["vehicleDeficit", _vehicleDeficit],
        ["aircraft", count _activeAircraft],
        ["desiredAircraft", _desiredAircraft],
        ["airDeficit", _airDeficit],
        ["infantryGroups", count _infantryGroups],
        ["vehicleGroups", count _vehicleGroups],
        ["airGroups", count _airGroups],
        ["pendingInfantry", count _infantryHandles],
        ["pendingVehicles", count _vehicleHandles],
        ["pendingAircraft", count _airHandles],
        ["usedGroupSlots", _usedGroups],
        ["maxGroupSlots", _maxGroups],
        ["availableGroupSlots", _availableSlots],
        ["sentKind", _sentKind],
        ["fps", _fps]
    ];

    _state set ["snapshot", _snapshot];
    missionNamespace setVariable [_stateName, _state];

    if (_statusDue) then {
        diag_log format ["[TMC v6 Director] %1", _snapshot];
    };
};

private _pfhHandle = [
    _fnc_evaluate,
    0.5,
    [_stateName]
] call CBA_fnc_addPerFrameHandler;

_state set ["pfhHandle", _pfhHandle];
missionNamespace setVariable [_stateName, _state];

diag_log format [
    "[TMC v6 Director] Started. Hard group cap %1. One package maximum every %2 seconds. Ground spawns %3-%4 meters from trigger center. Air matching enabled.",
    _config get "maxManagedGroups",
    _config get "evaluationInterval",
    _config get "minSpawnRadius",
    _config get "maxSpawnRadius"
];
