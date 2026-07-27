params [["_userConfig", createHashMap]];

if (!isServer) exitWith { createHashMapFromArray [["success",false],["groups",[]],["vehicles",[]],["failedSpawns",[]]] };
if !(_userConfig isEqualType createHashMap) exitWith { createHashMapFromArray [["success",false],["groups",[]],["vehicles",[]],["failedSpawns",[]]] };

private _defaults = createHashMapFromArray [
    ["center", objNull],
    ["side", east],
    ["minSpawnRadius", 500],
    ["maxSpawnRadius", 850],
    ["minPlayerDistance", 225],
    ["visibilityMaxDistance", 1500],
    ["visibilityThreshold", 0.05],
    ["attemptsPerGroup", 40],
    ["groupSeparation", 45],
    ["infantryGroupCount", 1],
    ["vehicleGroupCount", 0],
    ["infantryTemplates", []],
    ["vehicleTemplates", []],
    ["attackMode", "LAMBS"],
    ["searchRadius", 250],
    ["lambsReinforcement", true],
    ["lambsKnowledgeSeedChance", 0.25],
    ["spawnDelay", 0.20],
    ["debugMode", "LOG"],
    ["waveId", -1],
    ["onGroupSpawned", {}],
    ["onComplete", {}]
];

private _config = createHashMap;
{ _config set [_x, _defaults get _x] } forEach keys _defaults;
{ _config set [_x, _userConfig get _x] } forEach keys _userConfig;

private _centerRef = _config get "center";
private _centerPos = _centerRef call CBA_fnc_getPos;
if ((count _centerPos) < 2) exitWith { createHashMapFromArray [["success",false],["groups",[]],["vehicles",[]],["failedSpawns",["INVALID_CENTER"]]] };
_centerPos resize 3;
_centerPos set [2,0];

private _side = _config get "side";
private _minRadius = (_config get "minSpawnRadius") max 0;
private _maxRadius = (_config get "maxSpawnRadius") max _minRadius;
private _minPlayerDistance = (_config get "minPlayerDistance") max 0;
private _visibilityMaxDistance = (_config get "visibilityMaxDistance") max 0;
private _visibilityThreshold = _config get "visibilityThreshold";
private _attempts = round ((_config get "attemptsPerGroup") max 1);
private _groupSeparation = (_config get "groupSeparation") max 0;
private _debugMode = toUpper (_config get "debugMode");
private _spawnDelay = (_config get "spawnDelay") max 0;
private _reserved = [];
private _spawnedGroups = [];
private _spawnedVehicles = [];
private _failed = [];

private _fnc_log = {
    params ["_text"];
    if (_debugMode in ["LOG","MARKERS"]) then { diag_log format ["[TMC v5 Spawner] %1",_text] };
};

private _fnc_pickWeighted = {
    params ["_templates"];
    private _weighted = [];
    {
        private _weight = _x getOrDefault ["weight",1];
        if (_weight > 0) then { _weighted append [_x,_weight] };
    } forEach _templates;
    if (_weighted isEqualTo []) exitWith { createHashMap };
    _weighted call BIS_fnc_selectRandomWeighted
};

private _fnc_hidden = {
    params ["_candidate","_kind","_sampleRadius","_sampleHeight"];
    private _players = ([] call CBA_fnc_players) select {
        alive _x && { _x distance2D _candidate <= _visibilityMaxDistance }
    };
    if (_players isEqualTo []) exitWith { true };
    private _samples = [
        [0,0,0],
        [_sampleRadius,0,0],
        [-_sampleRadius,0,0],
        [0,_sampleRadius,0],
        [0,-_sampleRadius,0]
    ];
    private _heights = [_sampleHeight];
    if (_kind isEqualTo "VEHICLE") then { _heights pushBack (_sampleHeight + 1.5) };
    private _hidden = true;
    {
        private _viewer = _x;
        private _eye = eyePos _viewer;
        {
            private _height = _x;
            {
                private _targetAGL = [
                    (_candidate select 0) + (_x select 0),
                    (_candidate select 1) + (_x select 1),
                    _height
                ];
                private _ignored = vehicle _viewer;
                if (_ignored isEqualTo _viewer) then { _ignored = objNull };
                private _vis = [_viewer,"VIEW",_ignored] checkVisibility [_eye,AGLToASL _targetAGL];
                if (_vis > _visibilityThreshold) exitWith { _hidden = false };
            } forEach _samples;
            if (!_hidden) exitWith {};
        } forEach _heights;
        if (!_hidden) exitWith {};
    } forEach _players;
    _hidden
};

private _fnc_findPosition = {
    params ["_kind","_template"];
    private _vehicle = _kind isEqualTo "VEHICLE";
    private _objectClearance = _template getOrDefault ["objectClearance",if (_vehicle) then {15} else {8}];
    private _terrainClearance = _template getOrDefault ["terrainClearance",if (_vehicle) then {8} else {3}];
    private _maxGradient = _template getOrDefault ["maxGradient",if (_vehicle) then {0.16} else {0.32}];
    private _sampleRadius = _template getOrDefault ["visibilityRadius",if (_vehicle) then {14} else {14}];
    private _sampleHeight = _template getOrDefault ["visibilityHeight",if (_vehicle) then {2.5} else {1.3}];
    private _accepted = [];
    for "_attempt" from 1 to _attempts do {
        private _candidate = [_centerPos,_minRadius,_maxRadius,_objectClearance,0,_maxGradient,0,[],[[0,0,0],[0,0,0]]] call BIS_fnc_findSafePos;
        private _valid = !(_candidate isEqualTo [0,0,0]);
        if (_valid) then {
            _candidate resize 3;
            _candidate set [2,0];
            if (_vehicle && {_template getOrDefault ["preferRoad",true]}) then {
                private _roads = _candidate nearRoads (_template getOrDefault ["roadSearchRadius",75]);
                if (_roads isEqualTo []) then { _valid = false } else { _candidate = getPosATL (_roads select 0) };
            };
        };
        private _players = ([] call CBA_fnc_players) select { alive _x };
        if (_valid && {_players findIf {_x distance2D _candidate < _minPlayerDistance} >= 0}) then { _valid = false };
        if (_valid && {_reserved findIf {_x distance2D _candidate < _groupSeparation} >= 0}) then { _valid = false };
        if (_valid && {surfaceIsWater _candidate}) then { _valid = false };
        if (_valid && {!((nearestObjects [_candidate,["Man","LandVehicle","Air","Ship","StaticWeapon","Building","House","ThingX"],_objectClearance,true]) isEqualTo [])}) then { _valid = false };
        if (_valid && {!((nearestTerrainObjects [_candidate,["BUILDING","BUNKER","FENCE","FORTRESS","HOUSE","ROCK","ROCKS","TREE","WALL"],_terrainClearance,false,true]) isEqualTo [])}) then { _valid = false };
        if (_valid && {!([_candidate,_kind,_sampleRadius,_sampleHeight] call _fnc_hidden)}) then { _valid = false };
        if (_valid) exitWith { _accepted = _candidate };
    };
    _accepted
};

private _fnc_prepareInfantry = {
    params ["_group"];
    _group setBehaviourStrong "COMBAT";
    _group setCombatMode "RED";
    _group setSpeedMode "FULL";
    _group enableAttack true;
    if (_config get "lambsReinforcement") then {
        _group setVariable ["lambs_danger_enableGroupReinforce",true,true];
    };
    {
        _x enableStamina false;
        _x enableFatigue false;
        _x forceSpeed -1;
        _x setUnitPos "AUTO";
        _x enableAI "MOVE";
        _x enableAI "PATH";
        _x enableAI "FSM";
        _x enableAI "AUTOCOMBAT";
        _x enableAI "TARGET";
        _x enableAI "AUTOTARGET";
        _x enableAI "SUPPRESSION";
        _x setVariable ["lambs_danger_dangerRadio",true,true];
    } forEach units _group;
};

private _fnc_taskInfantry = {
    params ["_group"];
    [_group] call _fnc_prepareInfantry;
    if (!isNil "lambs_wp_fnc_taskAssault") then {
        [_group,_centerPos] spawn lambs_wp_fnc_taskAssault;
    } else {
        private _wp = _group addWaypoint [_centerPos,_config get "searchRadius"];
        _wp setWaypointType "SAD";
        _wp setWaypointBehaviour "COMBAT";
        _wp setWaypointCombatMode "RED";
        _wp setWaypointSpeed "FULL";
    };
    if (random 1 < (_config get "lambsKnowledgeSeedChance")) then {
        private _targets = ([] call CBA_fnc_players) select { alive _x };
        if !(_targets isEqualTo []) then {
            private _leader = leader _group;
            private _nearest = _targets select 0;
            { if (_leader distance2D _x < _leader distance2D _nearest) then { _nearest = _x } } forEach _targets;
            _leader reveal [_nearest,1.25];
        };
    };
};

private _fnc_taskVehicle = {
    params ["_group"];
    _group setBehaviourStrong "AWARE";
    _group setCombatMode "RED";
    _group setSpeedMode "FULL";
    private _wp = _group addWaypoint [_centerPos,_config get "searchRadius"];
    _wp setWaypointType "SAD";
    _wp setWaypointBehaviour "COMBAT";
    _wp setWaypointCombatMode "RED";
    _wp setWaypointSpeed "FULL";
};

private _fnc_spawnInfantry = {
    params ["_template","_position"];
    private _classes = +(_template getOrDefault ["units",[]]);
    if (_classes isEqualTo []) exitWith { grpNull };
    private _group = [_position,_side,_classes,[],[],[],[],[],_position getDir _centerPos,true] call BIS_fnc_spawnGroup;
    if (isNull _group) exitWith { grpNull };
    _group deleteGroupWhenEmpty true;
    _group setFormation (_template getOrDefault ["formation","STAG COLUMN"]);
    private _skill = _template getOrDefault ["skill",[0.4,0.55]];
    {
        private _value = if (_skill isEqualType []) then { (_skill select 0) + random ((_skill select 1)-(_skill select 0)) } else { _skill };
        _x setSkill ((_value max 0) min 1);
    } forEach units _group;
    [_group] call _fnc_taskInfantry;
    _group
};

private _fnc_spawnVehicle = {
    params ["_template","_position"];
    private _class = _template getOrDefault ["vehicleClass",""];
    if (_class isEqualTo "") exitWith { [objNull,grpNull] };
    private _vehicle = createVehicle [_class,_position,[],0,"NONE"];
    if (isNull _vehicle) exitWith { [objNull,grpNull] };
    _vehicle setDir (_position getDir _centerPos);
    createVehicleCrew _vehicle;
    private _group = group effectiveCommander _vehicle;
    if (isNull _group) then {
        deleteVehicle _vehicle;
        [objNull,grpNull]
    } else {
        _group deleteGroupWhenEmpty true;
        [_group] call _fnc_taskVehicle;
        [_vehicle,_group]
    }
};

for "_index" from 1 to round (_config get "infantryGroupCount") do {
    private _template = [_config get "infantryTemplates"] call _fnc_pickWeighted;
    if ((count _template) isEqualTo 0) then {
        _failed pushBack ["INFANTRY",_index,"NO_TEMPLATE"];
    } else {
        private _position = ["INFANTRY",_template] call _fnc_findPosition;
        if (_position isEqualTo []) then {
            _failed pushBack ["INFANTRY",_index,"NO_POSITION"];
        } else {
            private _group = [_template,_position] call _fnc_spawnInfantry;
            if (isNull _group) then {
                _failed pushBack ["INFANTRY",_index,"SPAWN_FAILED"];
            } else {
                _reserved pushBack _position;
                _spawnedGroups pushBack _group;
                [_group,"INFANTRY",_template,_position,objNull,_config] call (_config get "onGroupSpawned");
            };
        };
    };
    if (_spawnDelay > 0) then { sleep _spawnDelay };
};

for "_index" from 1 to round (_config get "vehicleGroupCount") do {
    private _template = [_config get "vehicleTemplates"] call _fnc_pickWeighted;
    if ((count _template) isEqualTo 0) then {
        _failed pushBack ["VEHICLE",_index,"NO_TEMPLATE"];
    } else {
        private _position = ["VEHICLE",_template] call _fnc_findPosition;
        if (_position isEqualTo []) then {
            _failed pushBack ["VEHICLE",_index,"NO_POSITION"];
        } else {
            private _spawn = [_template,_position] call _fnc_spawnVehicle;
            _spawn params ["_vehicle","_group"];
            if (isNull _vehicle || {isNull _group}) then {
                _failed pushBack ["VEHICLE",_index,"SPAWN_FAILED"];
            } else {
                _reserved pushBack _position;
                _spawnedVehicles pushBack _vehicle;
                _spawnedGroups pushBack _group;
                [_group,"VEHICLE",_template,_position,_vehicle,_config] call (_config get "onGroupSpawned");
            };
        };
    };
    if (_spawnDelay > 0) then { sleep _spawnDelay };
};

private _result = createHashMapFromArray [
    ["success",true],
    ["groups",_spawnedGroups],
    ["vehicles",_spawnedVehicles],
    ["failedSpawns",_failed]
];
[_result,_config] call (_config get "onComplete");
_result
