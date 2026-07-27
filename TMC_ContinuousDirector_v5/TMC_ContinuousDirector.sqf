if (!isServer) exitWith {};

params [
    ["_mode","START",[""]],
    ["_center",objNull],
    ["_overrides",createHashMap]
];

_mode = toUpper _mode;
private _stateName = "TMC_ContinuousDirector_State";

if (_mode in ["STOP","PAUSE","RESUME","STATUS"]) exitWith {
    private _state = missionNamespace getVariable [_stateName,createHashMap];
    if ((count _state) isEqualTo 0) exitWith {};
    switch (_mode) do {
        case "STOP": {
            _state set ["running",false];
            private _handle = _state getOrDefault ["pfhHandle",-1];
            if (_handle >= 0) then { [_handle] call CBA_fnc_removePerFrameHandler };
            missionNamespace setVariable [_stateName,_state];
        };
        case "PAUSE": {
            _state set ["paused",true];
            missionNamespace setVariable [_stateName,_state];
        };
        case "RESUME": {
            _state set ["paused",false];
            missionNamespace setVariable [_stateName,_state];
        };
        case "STATUS": {
            diag_log format ["[TMC v5 Director] %1",_state getOrDefault ["snapshot",createHashMap]];
        };
    };
};

if !(_mode isEqualTo "START") exitWith {};
if !(_overrides isEqualType createHashMap) exitWith {};

private _old = missionNamespace getVariable [_stateName,createHashMap];
if ((count _old) > 0 && {_old getOrDefault ["running",false]}) exitWith {
    diag_log "[TMC v5 Director] START ignored because the director is already running.";
};

private _defaults = createHashMapFromArray [
    ["scalingMode","AREA"],
    ["scalingSide",west],
    ["scalingRadius",300],
    ["minimumScalingUnits",1],
    ["enemySide",east],
    ["enemyRatio",3],
    ["scalingUnitsPerVehicle",10],
    ["initialDelay",1],
    ["infantryEvaluationInterval",5],
    ["vehicleEvaluationInterval",10],
    ["vehicleEvaluationOffset",2.5],
    ["behaviorEvaluationInterval",20],
    ["stuckTimeout",75],
    ["stuckMovementDistance",20],
    ["targetMoveThreshold",35],
    ["maxDesiredInfantry",-1],
    ["hardInfantryCap",450],
    ["maxActiveVehicles",20],
    ["maxManagedInfantryGroups",48],
    ["maxManagedVehicleGroups",24],
    ["maxManagedGroups",72],
    ["infantryMinimumServerFPS",15],
    ["vehicleMinimumServerFPS",15],
    ["estimatedInfantryPerGroup",12],
    ["waveScript","TMC_AttackWave_CloneWars.sqf"],
    ["minSpawnRadius",500],
    ["maxSpawnRadius",850],
    ["debugMode","LOG"]
];

private _config = createHashMap;
{ _config set [_x,_defaults get _x] } forEach keys _defaults;
{ _config set [_x,_overrides get _x] } forEach keys _overrides;

private _now = diag_tickTime;
private _state = createHashMapFromArray [
    ["running",true],
    ["paused",false],
    ["center",_center],
    ["config",_config],
    ["pfhHandle",-1],
    ["infantryHandles",[]],
    ["vehicleHandles",[]],
    ["packageNumber",0],
    ["nextInfantryCheck",_now + (_config get "initialDelay")],
    ["nextVehicleCheck",_now + (_config get "initialDelay") + (_config get "vehicleEvaluationOffset")],
    ["nextBehaviorCheck",_now + (_config get "initialDelay") + 5],
    ["snapshot",createHashMap]
];
missionNamespace setVariable [_stateName,_state];

private _fnc_evaluate = {
    params ["_args","_pfhHandle"];
    _args params ["_stateName"];

    private _state = missionNamespace getVariable [_stateName,createHashMap];
    if ((count _state) isEqualTo 0) exitWith { [_pfhHandle] call CBA_fnc_removePerFrameHandler };
    if !(_state getOrDefault ["running",false]) exitWith { [_pfhHandle] call CBA_fnc_removePerFrameHandler };
    if (_state getOrDefault ["paused",false]) exitWith {};

    private _config = _state get "config";
    private _center = _state get "center";
    private _centerPos = _center call CBA_fnc_getPos;
    private _scalingSide = _config get "scalingSide";
    private _enemySide = _config get "enemySide";
    private _mode = toUpper (_config get "scalingMode");

    private _sideUnits = allUnits select {
        alive _x && {side group _x isEqualTo _scalingSide}
    };

    private _scalingUnits = switch (_mode) do {
        case "SIDE": {_sideUnits};
        case "RADIUS": {_sideUnits select {_x distance2D _centerPos <= (_config get "scalingRadius")}};
        default {
            if ((_center isEqualType objNull && {!isNull _center}) || {_center isEqualType "" && {markerShape _center != ""}}) then {
                _sideUnits select {_x inArea _center}
            } else {
                _sideUnits select {_x distance2D _centerPos <= (_config get "scalingRadius")}
            }
        };
    };
    private _scalingCount = count _scalingUnits;

    private _infantryHandles = (_state getOrDefault ["infantryHandles",[]]) select {!(scriptDone _x)};
    private _vehicleHandles = (_state getOrDefault ["vehicleHandles",[]]) select {!(scriptDone _x)};
    _state set ["infantryHandles",_infantryHandles];
    _state set ["vehicleHandles",_vehicleHandles];

    private _managedGroups = allGroups select {
        _x getVariable ["TMC_attackWaveManaged",false]
        && {units _x findIf {alive _x} >= 0}
    };
    private _infantryGroups = _managedGroups select {
        toUpper (_x getVariable ["TMC_attackWaveKind","INFANTRY"]) isEqualTo "INFANTRY"
    };
    private _vehicleGroups = _managedGroups select {
        toUpper (_x getVariable ["TMC_attackWaveKind",""]) isEqualTo "VEHICLE"
    };

    private _infantryCount = 0;
    {
        _infantryCount = _infantryCount + ({alive _x && {side group _x isEqualTo _enemySide}} count units _x);
    } forEach _infantryGroups;

    private _managedVehicles = vehicles select {
        alive _x
        && {_x getVariable ["TMC_attackWaveVehicle",false]}
        && {crew _x findIf {alive _x} >= 0}
    };

    private _desiredInfantry = round (_scalingCount * (_config get "enemyRatio"));
    private _maxDesired = round (_config get "maxDesiredInfantry");
    if (_maxDesired > 0) then {_desiredInfantry = _desiredInfantry min _maxDesired};
    _desiredInfantry = _desiredInfantry min round (_config get "hardInfantryCap");

    private _desiredVehicles = if (_scalingCount > 0) then {
        (ceil (_scalingCount / ((_config get "scalingUnitsPerVehicle") max 1))) max 1
    } else {0};
    _desiredVehicles = _desiredVehicles min round (_config get "maxActiveVehicles");

    private _effectiveInfantry = _infantryCount + (count _infantryHandles * round (_config get "estimatedInfantryPerGroup"));
    private _effectiveVehicles = count _managedVehicles + count _vehicleHandles;
    private _infantryDeficit = (_desiredInfantry - _effectiveInfantry) max 0;
    private _vehicleDeficit = (_desiredVehicles - _effectiveVehicles) max 0;

    private _now = diag_tickTime;
    private _infantryDue = _now >= (_state get "nextInfantryCheck");
    private _vehicleDue = _now >= (_state get "nextVehicleCheck");
    private _behaviorDue = _now >= (_state get "nextBehaviorCheck");

    if (_infantryDue) then {
        _state set ["nextInfantryCheck",_now + (_config get "infantryEvaluationInterval")];
    };
    if (_vehicleDue) then {
        _state set ["nextVehicleCheck",_now + (_config get "vehicleEvaluationInterval")];
    };
    if (_behaviorDue) then {
        _state set ["nextBehaviorCheck",_now + (_config get "behaviorEvaluationInterval")];
    };

    private _retaskedGroups = 0;
    private _stuckGroups = 0;

    if (_behaviorDue && {!(_infantryGroups isEqualTo [])}) then {
        private _aircraft = vehicles select { alive _x && {_x isKindOf "Air"} };
        private _groundPlayers = ([] call CBA_fnc_players) select {
            alive _x
            && {side group _x isEqualTo _scalingSide}
            && {!((vehicle _x) isKindOf "Air")}
        };
        private _groundLeaders = _groundPlayers select { leader group _x isEqualTo _x };
        private _targetPool = if (_groundLeaders isEqualTo []) then {_groundPlayers} else {_groundLeaders};

        {
            private _group = _x;
            private _leader = leader _group;

            if (!isNull _leader) then {
                _group setBehaviourStrong "AWARE";
                _group setCombatMode "YELLOW";
                _group setSpeedMode "FULL";
                _group enableAttack false;
                _group allowFleeing 0;

                {
                    _group ignoreTarget _x;
                } forEach _aircraft;

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

                private _targetPos = if (isNull _target) then {+_centerPos} else {getPosATL _target};
                _targetPos resize 3;
                _targetPos set [2,0];

                private _waypoint = _group getVariable ["TMC_attackWaypoint",[]];
                if !(_waypoint isEqualTo []) then {
                    private _oldTargetPos = _group getVariable ["TMC_attackTargetPosition",_targetPos];
                    if (_oldTargetPos distance2D _targetPos >= (_config get "targetMoveThreshold")) then {
                        _waypoint setWaypointPosition [_targetPos,-1];
                        _group setCurrentWaypoint _waypoint;
                        _group move _targetPos;
                        _group setVariable ["TMC_attackTargetPosition",_targetPos];
                        _group setVariable ["TMC_attackTarget",_target];
                        _group setVariable ["TMC_lastRetaskTime",_now];
                        _retaskedGroups = _retaskedGroups + 1;
                    };
                };

                private _lastPosition = _group getVariable ["TMC_lastLeaderPosition",getPosATL _leader];
                private _lastProgress = _group getVariable ["TMC_lastProgressTime",_now];

                if (_leader distance2D _lastPosition >= (_config get "stuckMovementDistance")) then {
                    _group setVariable ["TMC_lastLeaderPosition",getPosATL _leader];
                    _group setVariable ["TMC_lastProgressTime",_now];
                } else {
                    if (_now - _lastProgress >= (_config get "stuckTimeout")) then {
                        _stuckGroups = _stuckGroups + 1;
                        if !(_waypoint isEqualTo []) then {
                            _waypoint setWaypointPosition [_targetPos,-1];
                            _group setCurrentWaypoint _waypoint;
                        };
                        {
                            if (alive _x) then {
                                _x forceSpeed -1;
                                _x doFollow _leader;
                            };
                        } forEach units _group;
                        _group move _targetPos;
                        _group setVariable ["TMC_lastLeaderPosition",getPosATL _leader];
                        _group setVariable ["TMC_lastProgressTime",_now];
                        _group setVariable ["TMC_lastRetaskTime",_now];
                    };
                };
            };
        } forEach _infantryGroups;
    };

    private _sharedUsed = count _managedGroups + count _infantryHandles + count _vehicleHandles;
    private _canUseShared = _sharedUsed < round (_config get "maxManagedGroups");
    private _sentInfantry = false;
    private _sentVehicle = false;

    if (
        _infantryDue
        && {_scalingCount >= round (_config get "minimumScalingUnits")}
        && {_infantryDeficit > 0}
        && {_canUseShared}
        && {count _infantryGroups + count _infantryHandles < round (_config get "maxManagedInfantryGroups")}
        && {diag_fps >= (_config get "infantryMinimumServerFPS")}
    ) then {
        private _id = (_state get "packageNumber") + 1;
        private _handle = [
            _center,
            _config get "minSpawnRadius",
            _config get "maxSpawnRadius",
            1,
            0,
            _config get "debugMode",
            _id
        ] execVM (_config get "waveScript");
        _infantryHandles pushBack _handle;
        _state set ["infantryHandles",_infantryHandles];
        _state set ["packageNumber",_id];
        _sentInfantry = true;
    };

    if (
        _vehicleDue
        && {_scalingCount >= round (_config get "minimumScalingUnits")}
        && {_vehicleDeficit > 0}
        && {_canUseShared}
        && {count _vehicleGroups + count _vehicleHandles < round (_config get "maxManagedVehicleGroups")}
        && {diag_fps >= (_config get "vehicleMinimumServerFPS")}
    ) then {
        private _id = (_state get "packageNumber") + 1;
        private _handle = [
            _center,
            _config get "minSpawnRadius",
            _config get "maxSpawnRadius",
            0,
            1,
            _config get "debugMode",
            _id
        ] execVM (_config get "waveScript");
        _vehicleHandles pushBack _handle;
        _state set ["vehicleHandles",_vehicleHandles];
        _state set ["packageNumber",_id];
        _sentVehicle = true;
    };

    private _snapshot = createHashMapFromArray [
        ["BLUFOR",_scalingCount],
        ["infantry",_infantryCount],
        ["desiredInfantry",_desiredInfantry],
        ["infantryDeficit",_infantryDeficit],
        ["vehicles",count _managedVehicles],
        ["desiredVehicles",_desiredVehicles],
        ["vehicleDeficit",_vehicleDeficit],
        ["infantryGroups",count _infantryGroups],
        ["vehicleGroups",count _vehicleGroups],
        ["retaskedGroups",_retaskedGroups],
        ["stuckGroups",_stuckGroups],
        ["sentInfantry",_sentInfantry],
        ["sentVehicle",_sentVehicle],
        ["fps",diag_fps]
    ];
    _state set ["snapshot",_snapshot];
    missionNamespace setVariable [_stateName,_state];

    if ((_config get "debugMode") in ["LOG","MARKERS"]) then {
        diag_log format ["[TMC v5 Director] %1",_snapshot];
    };
};

private _pfh = [_fnc_evaluate,0.5,[_stateName]] call CBA_fnc_addPerFrameHandler;
_state set ["pfhHandle",_pfh];
missionNamespace setVariable [_stateName,_state];

diag_log format [
    "[TMC v5 Director] Started. Infantry %1:1 every %2s. Vehicles 1:%3 every %4s with %5s offset. Behavior checks every %6s.",
    _config get "enemyRatio",
    _config get "infantryEvaluationInterval",
    _config get "scalingUnitsPerVehicle",
    _config get "vehicleEvaluationInterval",
    _config get "vehicleEvaluationOffset",
    _config get "behaviorEvaluationInterval"
];
