if (!isServer) exitWith {};

params [
    ["_mode", "START", [""]],
    ["_center", objNull],
    ["_overrides", createHashMap]
];

_mode = toUpper _mode;
private _stateName = "TMC_ContinuousDirector_State";

if (_mode in ["STOP", "PAUSE", "RESUME", "STATUS"]) exitWith {
    private _state = missionNamespace getVariable [_stateName, createHashMap];

    if ((count _state) isEqualTo 0) exitWith {
        if (_mode isEqualTo "STATUS") then {
            diag_log "[TMC v5 Director] Director state was not found.";
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
            );

            _state set ["pfhHandle", -1];
            _state set ["entityCreatedEH", -1];
            _state set ["infantryHandles", []];
            _state set ["vehicleHandles", []];
            missionNamespace setVariable [_stateName, _state];
            diag_log "[TMC v5 Director] Stopped.";
        };

        case "PAUSE": {
            _state set ["paused", true];
            private _snapshot = _state getOrDefault ["snapshot", createHashMap];
            _snapshot set ["paused", true];
            _state set ["snapshot", _snapshot];
            missionNamespace setVariable [_stateName, _state];
            diag_log "[TMC v5 Director] Paused by command.";
        };

        case "RESUME": {
            _state set ["paused", false];
            private _snapshot = _state getOrDefault ["snapshot", createHashMap];
            _snapshot set ["paused", false];
            _state set ["snapshot", _snapshot];
            missionNamespace setVariable [_stateName, _state];
            diag_log "[TMC v5 Director] Resumed by command.";
        };

        case "STATUS": {
            diag_log format [
                "[TMC v5 Director] %1",
                _state getOrDefault ["snapshot", createHashMap]
            ];
        };
    };
};

if !(_mode isEqualTo "START") exitWith {};
if !(_overrides isEqualType createHashMap) exitWith {
    diag_log "[TMC v5 Director] START rejected because overrides were not a HashMap.";
};

private _oldState = missionNamespace getVariable [_stateName, createHashMap];
if ((count _oldState) > 0 && { _oldState getOrDefault ["running", false] }) exitWith {
    diag_log "[TMC v5 Director] START ignored because the director is already running.";
};

private _oldEntityCreatedEH = _oldState getOrDefault ["entityCreatedEH", -1];
if (_oldEntityCreatedEH >= 0) then {
    removeMissionEventHandler ["EntityCreated", _oldEntityCreatedEH];
};

private _defaults = createHashMapFromArray [
    ["scalingMode", "AREA"],
    ["scalingSide", west],
    ["scalingRadius", 300],
    ["scalingEvaluationInterval", 5],
    ["minimumScalingUnits", 1],
    ["enemySide", east],
    ["enemyRatio", 3],
    ["scalingUnitsPerVehicle", 10],
    ["initialDelay", 1],
    ["infantryEvaluationInterval", 5],
    ["vehicleEvaluationInterval", 10],
    ["vehicleEvaluationOffset", 2.5],
    ["behaviorEvaluationInterval", 20],
    ["statusLogInterval", 60],
    ["stuckTimeout", 75],
    ["stuckMovementDistance", 20],
    ["stuckDistanceImprovement", 10],
    ["stuckMinimumTargetDistance", 100],
    ["stuckEnemyExclusionRadius", 125],
    ["targetMoveThreshold", 35],
    ["cqbRadius", 75],
    ["ignoreAircraft", true],
    ["mergeEnabled", true],
    ["mergeThreshold", 5],
    ["mergeSearchRadius", 300],
    ["maximumMergedGroupSize", 30],
    ["maxDesiredInfantry", -1],
    ["hardInfantryCap", 450],
    ["maxActiveVehicles", 20],
    ["maxManagedInfantryGroups", 48],
    ["maxManagedVehicleGroups", 24],
    ["maxManagedGroups", 72],
    ["infantryMinimumServerFPS", 15],
    ["vehicleMinimumServerFPS", 15],
    ["estimatedInfantryPerGroup", 20],
    ["waveScript", "TMC_AttackWave_CloneWars.sqf"],
    ["minSpawnRadius", 500],
    ["maxSpawnRadius", 850],
    ["debugMode", "NONE"]
];

private _config = createHashMap;
{ _config set [_x, _defaults get _x] } forEach keys _defaults;
{ _config set [_x, _overrides get _x] } forEach keys _overrides;

private _centerPos = _center call CBA_fnc_getPos;
if ((count _centerPos) < 2) exitWith {
    diag_log "[TMC v5 Director] START rejected because the center reference was invalid.";
};

private _existingManagedGroups = allGroups select {
    _x getVariable ["TMC_attackWaveManaged", false]
    && { units _x findIf { alive _x } >= 0 }
};

private _existingInfantryGroups = _existingManagedGroups select {
    toUpper (_x getVariable ["TMC_attackWaveKind", "INFANTRY"]) isEqualTo "INFANTRY"
};

private _existingVehicleGroups = _existingManagedGroups select {
    toUpper (_x getVariable ["TMC_attackWaveKind", ""]) isEqualTo "VEHICLE"
};

private _existingManagedVehicles = vehicles select {
    alive _x && { _x getVariable ["TMC_attackWaveVehicle", false] }
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
    ["infantryGroups", _existingInfantryGroups],
    ["vehicleGroups", _existingVehicleGroups],
    ["managedVehicles", _existingManagedVehicles],
    ["knownAircraft", _knownAircraft],
    ["packageNumber", 0],
    ["retaskedTotal", 0],
    ["stuckTotal", 0],
    ["mergedGroupsTotal", 0],
    ["mergedUnitsTotal", 0],
    ["nextScalingCheck", _now + (_config get "initialDelay")],
    ["nextInfantryCheck", _now + (_config get "initialDelay")],
    ["nextVehicleCheck", _now + (_config get "initialDelay") + (_config get "vehicleEvaluationOffset")],
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

        private _stateName = "TMC_ContinuousDirector_State";
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

    private _scalingDue = _now >= (_state get "nextScalingCheck");
    private _infantryDue = _now >= (_state get "nextInfantryCheck");
    private _vehicleDue = _now >= (_state get "nextVehicleCheck");
    private _behaviorDue = _now >= (_state get "nextBehaviorCheck");
    private _statusDue = _debugMode in ["LOG", "MARKERS"]
        && { _now >= (_state get "nextStatusLog") };

    if !(_scalingDue || _infantryDue || _vehicleDue || _behaviorDue || _statusDue) exitWith {};

    if (_scalingDue) then {
        _state set [
            "nextScalingCheck",
            _now + (_config get "scalingEvaluationInterval")
        ];
    };

    if (_infantryDue) then {
        _state set [
            "nextInfantryCheck",
            _now + (_config get "infantryEvaluationInterval")
        ];
    };

    if (_vehicleDue) then {
        _state set [
            "nextVehicleCheck",
            _now + (_config get "vehicleEvaluationInterval")
        ];
    };

    if (_behaviorDue) then {
        _state set [
            "nextBehaviorCheck",
            _now + (_config get "behaviorEvaluationInterval")
        ];
    };

    if (_statusDue) then {
        _state set [
            "nextStatusLog",
            _now + (_config get "statusLogInterval")
        ];
    };

    private _infantryHandles = (_state getOrDefault ["infantryHandles", []]) select {
        !scriptDone _x
    };
    private _vehicleHandles = (_state getOrDefault ["vehicleHandles", []]) select {
        !scriptDone _x
    };

    private _infantryGroups = (_state getOrDefault ["infantryGroups", []]) select {
        !isNull _x && { units _x findIf { alive _x } >= 0 }
    };
    private _vehicleGroups = (_state getOrDefault ["vehicleGroups", []]) select {
        !isNull _x && { units _x findIf { alive _x } >= 0 }
    };
    private _managedVehicles = (_state getOrDefault ["managedVehicles", []]) select {
        !isNull _x && { alive _x }
    };
    private _activeVehicles = _managedVehicles select {
        crew _x findIf { alive _x } >= 0
    };
    private _knownAircraft = (_state getOrDefault ["knownAircraft", []]) select {
        !isNull _x && { alive _x }
    };

    _state set ["infantryHandles", _infantryHandles];
    _state set ["vehicleHandles", _vehicleHandles];
    _state set ["infantryGroups", _infantryGroups];
    _state set ["vehicleGroups", _vehicleGroups];
    _state set ["managedVehicles", _managedVehicles];
    _state set ["knownAircraft", _knownAircraft];

    private _center = _state get "center";
    private _centerPos = _center call CBA_fnc_getPos;

    if ((count _centerPos) < 2) exitWith {
        diag_log "[TMC v5 Director] Center reference became invalid. Director stopped.";

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

    private _snapshotPrevious = _state getOrDefault ["snapshot", createHashMap];
    private _scalingCount = _snapshotPrevious getOrDefault ["BLUFOR", 0];
    private _scalingSide = _config get "scalingSide";
    private _enemySide = _config get "enemySide";

    if (_scalingDue) then {
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
    };

    private _infantryCount = 0;
    {
        _infantryCount = _infantryCount + ({
            alive _x && { side group _x isEqualTo _enemySide }
        } count units _x);
    } forEach _infantryGroups;

    private _desiredInfantry = round (
        _scalingCount * (_config get "enemyRatio")
    );

    private _maxDesired = round (_config get "maxDesiredInfantry");
    if (_maxDesired > 0) then {
        _desiredInfantry = _desiredInfantry min _maxDesired;
    };

    _desiredInfantry = _desiredInfantry min round (_config get "hardInfantryCap");

    private _desiredVehicles = if (_scalingCount > 0) then {
        (ceil (
            _scalingCount
            / ((_config get "scalingUnitsPerVehicle") max 1)
        )) max 1
    } else {
        0
    };

    _desiredVehicles = _desiredVehicles min round (_config get "maxActiveVehicles");

    private _effectiveInfantry = _infantryCount
        + (count _infantryHandles * round (_config get "estimatedInfantryPerGroup"));
    private _effectiveVehicles = count _activeVehicles + count _vehicleHandles;
    private _infantryDeficit = (_desiredInfantry - _effectiveInfantry) max 0;
    private _vehicleDeficit = (_desiredVehicles - _effectiveVehicles) max 0;

    private _mergedGroupsThisCheck = 0;
    private _mergedUnitsThisCheck = 0;
    private _retaskedThisCheck = 0;
    private _stuckThisCheck = 0;

    if (
        _behaviorDue
        && { _config getOrDefault ["mergeEnabled", true] }
        && { !(_infantryGroups isEqualTo []) }
    ) then {
        private _mergeThreshold = (round (_config getOrDefault ["mergeThreshold", 5])) max 1;
        private _mergeSearchRadius = (_config getOrDefault ["mergeSearchRadius", 300]) max 0;
        private _defaultMaximumSize = (round (_config getOrDefault ["maximumMergedGroupSize", 30])) max _mergeThreshold;
        private _enemyExclusionRadius = (_config get "stuckEnemyExclusionRadius") max 0;

        private _fnc_groupBusy = {
            params ["_group"];

            private _leader = leader _group;
            if (isNull _leader) exitWith { true };

            private _lambsTask = _leader getVariable ["lambs_main_currentTask", ""];
            private _activeCQB = (_lambsTask find "Clearing rooms") >= 0
                || { (_lambsTask find "Rush enemy") >= 0 };
            private _nearestEnemy = _leader findNearestEnemy (getPosATL _leader);
            private _enemyNearby = !isNull _nearestEnemy
                && { _leader distance2D _nearestEnemy <= _enemyExclusionRadius };

            _activeCQB || _enemyNearby
        };

        private _sourceGroups = +(_infantryGroups select {
            _x getVariable ["TMC_attackWaveAllowMerge", false]
            && {
                private _living = { alive _x } count units _x;
                _living > 0 && { _living < _mergeThreshold }
            }
        });

        {
            private _sourceGroup = _x;
            private _sourceUnits = units _sourceGroup select { alive _x };
            private _sourceCount = count _sourceUnits;
            private _sourceLeader = leader _sourceGroup;

            if (
                _sourceCount > 0
                && { _sourceCount < _mergeThreshold }
                && { !isNull _sourceLeader }
                && { !([_sourceGroup] call _fnc_groupBusy) }
            ) then {
                private _eligibleGroups = _infantryGroups select {
                    private _destinationGroup = _x;
                    private _destinationLeader = leader _destinationGroup;
                    private _destinationCount = { alive _x } count units _destinationGroup;
                    private _destinationMaximum = (
                        round (_destinationGroup getVariable [
                            "TMC_attackWaveMaximumMergedSize",
                            _defaultMaximumSize
                        ])
                    ) max _mergeThreshold;

                    !(_destinationGroup isEqualTo _sourceGroup)
                    && { !isNull _destinationGroup }
                    && { !isNull _destinationLeader }
                    && { _destinationGroup getVariable ["TMC_attackWaveAllowMerge", false] }
                    && { _destinationCount > 0 }
                    && { _destinationCount + _sourceCount <= _destinationMaximum }
                    && { _sourceLeader distance2D _destinationLeader <= _mergeSearchRadius }
                    && { !([_destinationGroup] call _fnc_groupBusy) }
                };

                private _establishedGroups = _eligibleGroups select {
                    ({ alive _x } count units _x) >= _mergeThreshold
                };
                private _destinationPool = if (_establishedGroups isEqualTo []) then {
                    _eligibleGroups
                } else {
                    _establishedGroups
                };

                if !(_destinationPool isEqualTo []) then {
                    private _destinationGroup = _destinationPool select 0;
                    private _bestDistance = _sourceLeader distance2D leader _destinationGroup;

                    {
                        private _distance = _sourceLeader distance2D leader _x;
                        if (_distance < _bestDistance) then {
                            _destinationGroup = _x;
                            _bestDistance = _distance;
                        };
                    } forEach _destinationPool;

                    _sourceGroup setVariable ["TMC_attackWaveAllowMerge", false];
                    _sourceUnits joinSilent _destinationGroup;

                    private _destinationLeader = leader _destinationGroup;
                    {
                        if (alive _x && { !isNull _destinationLeader }) then {
                            _x doFollow _destinationLeader;
                        };
                    } forEach _sourceUnits;

                    _destinationGroup setVariable ["TMC_attackWaveAllowMerge", true];
                    _destinationGroup setVariable ["TMC_attackWaveTemplate", "Merged regular infantry"];
                    _destinationGroup setVariable ["TMC_lastLeaderPosition", getPosATL _destinationLeader];
                    _destinationGroup setVariable ["TMC_lastProgressTime", _now];

                    if ((units _sourceGroup) isEqualTo []) then {
                        deleteGroup _sourceGroup;
                    };

                    _mergedGroupsThisCheck = _mergedGroupsThisCheck + 1;
                    _mergedUnitsThisCheck = _mergedUnitsThisCheck + _sourceCount;
                };
            };
        } forEach _sourceGroups;

        _infantryGroups = _infantryGroups select {
            !isNull _x && { units _x findIf { alive _x } >= 0 }
        };
        _state set ["infantryGroups", _infantryGroups];
    };

    if (_behaviorDue && { !(_infantryGroups isEqualTo []) }) then {
        private _groundPlayers = ([] call CBA_fnc_players) select {
            alive _x
            && { side group _x isEqualTo _scalingSide }
            && { !((vehicle _x) isKindOf "Air") }
        };

        private _groundLeaders = _groundPlayers select {
            leader group _x isEqualTo _x
        };

        private _targetPool = if (_groundLeaders isEqualTo []) then {
            _groundPlayers
        } else {
            _groundLeaders
        };

        private _hasLAMBS_CQB = !isNil "lambs_wp_fnc_taskCQB";

        {
            private _group = _x;
            private _leader = leader _group;

            if (!isNull _leader) then {
                private _target = objNull;

                if !(_targetPool isEqualTo []) then {
                    _target = _targetPool select 0;
                    private _bestDistance = _leader distance2D _target;

                    {
                        private _distance = _leader distance2D _x;
                        if (_distance < _bestDistance) then {
                            _target = _x;
                            _bestDistance = _distance;
                        };
                    } forEach _targetPool;
                };

                private _targetPos = if (isNull _target) then {
                    +_centerPos
                } else {
                    getPosATL _target
                };

                _targetPos resize 3;
                _targetPos set [2, 0];

                private _lambsTask = _leader getVariable [
                    "lambs_main_currentTask",
                    ""
                ];
                private _activeCQB = (_lambsTask find "Clearing rooms") >= 0
                    || { (_lambsTask find "Rush enemy") >= 0 };

                private _nearestEnemy = _leader findNearestEnemy (getPosATL _leader);
                private _enemyNearby = !isNull _nearestEnemy
                    && {
                        _leader distance2D _nearestEnemy
                        <= (_config get "stuckEnemyExclusionRadius")
                    };

                private _waypoint = _group getVariable ["TMC_attackWaypoint", []];
                private _hasWaypoint = !(_waypoint isEqualTo [])
                    && { count waypoints _group > 0 };

                if (!_hasWaypoint) then {
                    _waypoint = _group addWaypoint [_targetPos, -1];
                    _waypoint setWaypointType ([
                        "SAD",
                        "lambs_danger_CQB"
                    ] select _hasLAMBS_CQB);
                    _waypoint setWaypointBehaviour "AWARE";
                    _waypoint setWaypointCombatMode "YELLOW";
                    _waypoint setWaypointSpeed "FULL";
                    _waypoint setWaypointCompletionRadius (
                        (_config get "cqbRadius") max 25
                    );
                    _group setCurrentWaypoint _waypoint;

                    if (!_enemyNearby && { !_activeCQB }) then {
                        _group move _targetPos;
                    };

                    _group setVariable ["TMC_attackWaypoint", _waypoint];
                    _group setVariable ["TMC_attackTarget", _target];
                    _group setVariable ["TMC_attackTargetPosition", _targetPos];
                    _group setVariable ["TMC_lastLeaderPosition", getPosATL _leader];
                    _group setVariable ["TMC_lastProgressTime", _now];
                    _group setVariable [
                        "TMC_lastTargetDistance",
                        _leader distance2D _targetPos
                    ];
                    _retaskedThisCheck = _retaskedThisCheck + 1;
                };

                private _oldTarget = _group getVariable [
                    "TMC_attackTarget",
                    objNull
                ];
                private _oldTargetPos = _group getVariable [
                    "TMC_attackTargetPosition",
                    _targetPos
                ];

                private _targetChanged = !(_oldTarget isEqualTo _target);
                private _targetMoved = _oldTargetPos distance2D _targetPos
                    >= (_config get "targetMoveThreshold");

                if (_targetChanged || _targetMoved) then {
                    _waypoint setWaypointPosition [_targetPos, -1];
                    _group setCurrentWaypoint _waypoint;

                    if (!_enemyNearby && { !_activeCQB }) then {
                        _group move _targetPos;
                    };

                    _group setVariable ["TMC_attackTarget", _target];
                    _group setVariable ["TMC_attackTargetPosition", _targetPos];
                    _group setVariable ["TMC_lastLeaderPosition", getPosATL _leader];
                    _group setVariable ["TMC_lastProgressTime", _now];
                    _group setVariable [
                        "TMC_lastTargetDistance",
                        _leader distance2D _targetPos
                    ];
                    _retaskedThisCheck = _retaskedThisCheck + 1;
                };

                private _distanceToTarget = _leader distance2D _targetPos;
                private _lastPosition = _group getVariable [
                    "TMC_lastLeaderPosition",
                    getPosATL _leader
                ];
                private _lastProgress = _group getVariable [
                    "TMC_lastProgressTime",
                    _now
                ];
                private _lastTargetDistance = _group getVariable [
                    "TMC_lastTargetDistance",
                    _distanceToTarget
                ];

                if (
                    _enemyNearby
                    || { _activeCQB }
                    || {
                        _distanceToTarget
                        <= (_config get "stuckMinimumTargetDistance")
                    }
                ) then {
                    _group setVariable [
                        "TMC_lastLeaderPosition",
                        getPosATL _leader
                    ];
                    _group setVariable ["TMC_lastProgressTime", _now];
                    _group setVariable [
                        "TMC_lastTargetDistance",
                        _distanceToTarget
                    ];
                } else {
                    private _movedEnough = _leader distance2D _lastPosition
                        >= (_config get "stuckMovementDistance");
                    private _closedDistance = _lastTargetDistance - _distanceToTarget
                        >= (_config get "stuckDistanceImprovement");

                    if (_movedEnough || _closedDistance) then {
                        _group setVariable [
                            "TMC_lastLeaderPosition",
                            getPosATL _leader
                        ];
                        _group setVariable ["TMC_lastProgressTime", _now];
                        _group setVariable [
                            "TMC_lastTargetDistance",
                            _distanceToTarget
                        ];
                    } else {
                        if (
                            _now - _lastProgress
                            >= (_config get "stuckTimeout")
                        ) then {
                            _stuckThisCheck = _stuckThisCheck + 1;

                            _waypoint setWaypointPosition [_targetPos, -1];
                            _group setCurrentWaypoint _waypoint;

                            {
                                if (alive _x) then {
                                    _x forceSpeed -1;
                                    _x doFollow _leader;
                                };
                            } forEach units _group;

                            _group move _targetPos;
                            _group setVariable [
                                "TMC_lastLeaderPosition",
                                getPosATL _leader
                            ];
                            _group setVariable ["TMC_lastProgressTime", _now];
                            _group setVariable [
                                "TMC_lastTargetDistance",
                                _distanceToTarget
                            ];
                        };
                    };
                };
            };
        } forEach _infantryGroups;
    };

    private _retaskedTotal = (_state getOrDefault ["retaskedTotal", 0])
        + _retaskedThisCheck;
    private _stuckTotal = (_state getOrDefault ["stuckTotal", 0])
        + _stuckThisCheck;
    private _mergedGroupsTotal = (_state getOrDefault ["mergedGroupsTotal", 0])
        + _mergedGroupsThisCheck;
    private _mergedUnitsTotal = (_state getOrDefault ["mergedUnitsTotal", 0])
        + _mergedUnitsThisCheck;

    _state set ["retaskedTotal", _retaskedTotal];
    _state set ["stuckTotal", _stuckTotal];
    _state set ["mergedGroupsTotal", _mergedGroupsTotal];
    _state set ["mergedUnitsTotal", _mergedUnitsTotal];

    private _usedSharedSlots = count _infantryGroups
        + count _vehicleGroups
        + count _infantryHandles
        + count _vehicleHandles;
    private _availableSharedSlots = (
        round (_config get "maxManagedGroups") - _usedSharedSlots
    ) max 0;
    private _availableInfantrySlots = (
        round (_config get "maxManagedInfantryGroups")
        - count _infantryGroups
        - count _infantryHandles
    ) max 0;
    private _availableVehicleSlots = (
        round (_config get "maxManagedVehicleGroups")
        - count _vehicleGroups
        - count _vehicleHandles
    ) max 0;

    private _fps = diag_fps;
    private _sentInfantry = false;
    private _sentVehicle = false;

    if (
        _infantryDue
        && { _scalingCount >= round (_config get "minimumScalingUnits") }
        && { _infantryDeficit > 0 }
        && { _availableSharedSlots > 0 }
        && { _availableInfantrySlots > 0 }
        && { _fps >= (_config get "infantryMinimumServerFPS") }
    ) then {
        private _id = (_state get "packageNumber") + 1;
        private _handle = [
            _center,
            _config get "minSpawnRadius",
            _config get "maxSpawnRadius",
            1,
            0,
            _debugMode,
            _id,
            _scalingSide,
            _config get "cqbRadius"
        ] execVM (_config get "waveScript");

        _infantryHandles pushBack _handle;
        _state set ["infantryHandles", _infantryHandles];
        _state set ["packageNumber", _id];
        _availableSharedSlots = _availableSharedSlots - 1;
        _availableInfantrySlots = _availableInfantrySlots - 1;
        _sentInfantry = true;

        if (_debugMode in ["LOG", "MARKERS"]) then {
            diag_log format [
                "[TMC v5 Director] Requested infantry package %1. Deficit %2.",
                _id,
                _infantryDeficit
            ];
        };
    };

    if (
        _vehicleDue
        && { _scalingCount >= round (_config get "minimumScalingUnits") }
        && { _vehicleDeficit > 0 }
        && { _availableSharedSlots > 0 }
        && { _availableVehicleSlots > 0 }
        && { _fps >= (_config get "vehicleMinimumServerFPS") }
    ) then {
        private _id = (_state get "packageNumber") + 1;
        private _handle = [
            _center,
            _config get "minSpawnRadius",
            _config get "maxSpawnRadius",
            0,
            1,
            _debugMode,
            _id,
            _scalingSide,
            _config get "cqbRadius"
        ] execVM (_config get "waveScript");

        _vehicleHandles pushBack _handle;
        _state set ["vehicleHandles", _vehicleHandles];
        _state set ["packageNumber", _id];
        _availableSharedSlots = _availableSharedSlots - 1;
        _availableVehicleSlots = _availableVehicleSlots - 1;
        _sentVehicle = true;

        if (_debugMode in ["LOG", "MARKERS"]) then {
            diag_log format [
                "[TMC v5 Director] Requested vehicle package %1. Deficit %2.",
                _id,
                _vehicleDeficit
            ];
        };
    };

    private _snapshot = createHashMapFromArray [
        ["running", true],
        ["paused", false],
        ["BLUFOR", _scalingCount],
        ["infantry", _infantryCount],
        ["desiredInfantry", _desiredInfantry],
        ["effectiveInfantry", _effectiveInfantry],
        ["infantryDeficit", _infantryDeficit],
        ["vehicles", count _activeVehicles],
        ["desiredVehicles", _desiredVehicles],
        ["effectiveVehicles", _effectiveVehicles],
        ["vehicleDeficit", _vehicleDeficit],
        ["infantryGroups", count _infantryGroups],
        ["vehicleGroups", count _vehicleGroups],
        ["pendingInfantryPackages", count _infantryHandles],
        ["pendingVehiclePackages", count _vehicleHandles],
        ["mergedGroupsThisCheck", _mergedGroupsThisCheck],
        ["mergedUnitsThisCheck", _mergedUnitsThisCheck],
        ["mergedGroupsTotal", _mergedGroupsTotal],
        ["mergedUnitsTotal", _mergedUnitsTotal],
        ["retaskedThisCheck", _retaskedThisCheck],
        ["stuckThisCheck", _stuckThisCheck],
        ["retaskedTotal", _retaskedTotal],
        ["stuckTotal", _stuckTotal],
        ["sentInfantry", _sentInfantry],
        ["sentVehicle", _sentVehicle],
        ["fps", _fps]
    ];

    _state set ["snapshot", _snapshot];
    missionNamespace setVariable [_stateName, _state];

    if (
        _debugMode in ["LOG", "MARKERS"]
        && {
            _mergedGroupsThisCheck > 0
            || { _retaskedThisCheck > 0 }
            || { _stuckThisCheck > 0 }
        }
    ) then {
        diag_log format [
            "[TMC v5 Director] Behavior check merged %1 groups (%2 units), retasked %3 groups, and recovered %4 stuck groups.",
            _mergedGroupsThisCheck,
            _mergedUnitsThisCheck,
            _retaskedThisCheck,
            _stuckThisCheck
        ];
    };

    if (_statusDue) then {
        diag_log format ["[TMC v5 Director] %1", _snapshot];
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
    "[TMC v5 Director] Started. Scaling every %1s. Infantry %2:1 every %3s. Vehicles 1:%4 every %5s with %6s offset. Behavior and merge checks every %7s.",
    _config get "scalingEvaluationInterval",
    _config get "enemyRatio",
    _config get "infantryEvaluationInterval",
    _config get "scalingUnitsPerVehicle",
    _config get "vehicleEvaluationInterval",
    _config get "vehicleEvaluationOffset",
    _config get "behaviorEvaluationInterval"
];
