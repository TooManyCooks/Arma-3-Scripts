if (!isServer) exitWith {};

if (isNil "TMC_fnc_spawnAttackWave") then {
    TMC_fnc_spawnAttackWave = compileFinal preprocessFileLineNumbers "TMC_fnc_spawnAttackWave.sqf";
};

params [["_request", createHashMap]];

if !(_request isEqualType createHashMap) exitWith {
    diag_log "[TMC v6] Attack request rejected because it was not a HashMap.";
};

private _kind = toUpper (_request getOrDefault ["kind", "INFANTRY"]);
private _cacheName = "TMC_CloneWars_TemplateCache_v6";
private _templateCache = missionNamespace getVariable [_cacheName, createHashMap];

if ((count _templateCache) isEqualTo 0) then {
    private _B1_AT = "JLTS_Droid_B1_AT";
    private _B1_AR = "JLTS_Droid_B1_AR";
    private _B1_SBB3 = "JLTS_Droid_B1_SBB3";
    private _B1_COMMANDER = "JLTS_Droid_B1_Commander";
    private _B1_E5 = "JLTS_Droid_B1_E5";
    private _B1_SNIPER = "JLTS_Droid_B1_Sniper";
    private _B2 = "ls_droid_b2";
    private _DROIDEKA = "ls_droid_droideka";
    private _BX_CAPTAIN = "ls_droid_bx_captain";
    private _BX = "ls_droid_bx";
    private _BX_ASSASSIN = "ls_droid_bx_assassain";

    private _infantryTemplates = [];
    private _vehicleTemplates = [];
    private _aircraftTemplates = [];
    private _missingClasses = [];

    private _fnc_repeatClass = {
        params ["_class", "_count"];
        private _result = [];

        for "_index" from 1 to _count do {
            _result pushBack _class;
        };

        _result
    };

    private _fnc_addInfantryTemplate = {
        params ["_template"];

        private _units = _template getOrDefault ["units", []];
        private _missing = _units select {
            !(isClass (configFile >> "CfgVehicles" >> _x))
        };

        if (_missing isEqualTo []) then {
            _infantryTemplates pushBack _template;
        } else {
            _missingClasses append _missing;
        };
    };

    private _fnc_addVehicleTemplate = {
        params ["_name", "_class", "_weight", "_clearance", "_gradient", ["_preferRoad", true]];

        if (isClass (configFile >> "CfgVehicles" >> _class)) then {
            _vehicleTemplates pushBack createHashMapFromArray [
                ["name", _name],
                ["weight", _weight],
                ["vehicleClass", _class],
                ["objectClearance", _clearance],
                ["terrainClearance", 8],
                ["maxGradient", _gradient],
                ["visibilityRadius", 15],
                ["visibilityHeight", 2.7],
                ["preferRoad", _preferRoad],
                ["roadSearchRadius", 100]
            ];
        } else {
            _missingClasses pushBack _class;
        };
    };

    private _fnc_addAircraftTemplate = {
        params ["_name", "_class", ["_weight", 1]];

        if (isClass (configFile >> "CfgVehicles" >> _class)) then {
            _aircraftTemplates pushBack createHashMapFromArray [
                ["name", _name],
                ["weight", _weight],
                ["aircraftClass", _class]
            ];
        } else {
            _missingClasses pushBack _class;
        };
    };

    private _b1AssaultUnits = [_B1_COMMANDER];
    _b1AssaultUnits append ([_B1_E5, 20] call _fnc_repeatClass);
    _b1AssaultUnits append ([_B1_AR, 5] call _fnc_repeatClass);
    _b1AssaultUnits append ([_B1_AT, 3] call _fnc_repeatClass);
    _b1AssaultUnits append ([_B1_SBB3, 1] call _fnc_repeatClass);

    [createHashMapFromArray [
        ["name", "B1 Assault Company (30)"],
        ["weight", 12],
        ["units", _b1AssaultUnits],
        ["skill", [0.38, 0.52]],
        ["objectClearance", 16],
        ["terrainClearance", 4],
        ["maxGradient", 0.29],
        ["visibilityRadius", 20]
    ]] call _fnc_addInfantryTemplate;

    private _b1FireSupportUnits = [_B1_COMMANDER];
    _b1FireSupportUnits append ([_B1_E5, 9] call _fnc_repeatClass);
    _b1FireSupportUnits append ([_B1_AR, 5] call _fnc_repeatClass);
    _b1FireSupportUnits append ([_B1_AT, 3] call _fnc_repeatClass);
    _b1FireSupportUnits append ([_B1_SNIPER, 1] call _fnc_repeatClass);
    _b1FireSupportUnits append ([_B1_SBB3, 1] call _fnc_repeatClass);

    [createHashMapFromArray [
        ["name", "B1 Fire Support Platoon (20)"],
        ["weight", 9],
        ["units", _b1FireSupportUnits],
        ["skill", [0.41, 0.56]],
        ["objectClearance", 14],
        ["terrainClearance", 4],
        ["maxGradient", 0.30],
        ["visibilityRadius", 18]
    ]] call _fnc_addInfantryTemplate;

    private _mixedAssaultUnits = [_B1_COMMANDER];
    _mixedAssaultUnits append ([_B1_E5, 4] call _fnc_repeatClass);
    _mixedAssaultUnits append ([_B1_AR, 1] call _fnc_repeatClass);
    _mixedAssaultUnits append ([_B1_AT, 1] call _fnc_repeatClass);
    _mixedAssaultUnits append ([_B2, 3] call _fnc_repeatClass);

    [createHashMapFromArray [
        ["name", "B1/B2 Assault Squad (10)"],
        ["weight", 7],
        ["units", _mixedAssaultUnits],
        ["skill", [0.44, 0.59]],
        ["objectClearance", 11],
        ["terrainClearance", 4],
        ["maxGradient", 0.31],
        ["visibilityRadius", 14],
        ["visibilityHeight", 1.8]
    ]] call _fnc_addInfantryTemplate;

    [createHashMapFromArray [
        ["name", "BX Commando Team (6)"],
        ["weight", 1],
        ["units", [
            _BX_CAPTAIN,
            _BX,
            _BX,
            _BX,
            _BX_ASSASSIN,
            _BX_ASSASSIN
        ]],
        ["skill", [0.58, 0.72]],
        ["objectClearance", 8],
        ["terrainClearance", 3],
        ["maxGradient", 0.35],
        ["visibilityRadius", 11]
    ]] call _fnc_addInfantryTemplate;

    [createHashMapFromArray [
        ["name", "B2 Hunter Cell (3)"],
        ["weight", 1],
        ["units", [_B2, _B2, _B2]],
        ["skill", [0.50, 0.65]],
        ["objectClearance", 8],
        ["terrainClearance", 4],
        ["maxGradient", 0.28],
        ["visibilityRadius", 10],
        ["visibilityHeight", 1.8]
    ]] call _fnc_addInfantryTemplate;

    [createHashMapFromArray [
        ["name", "Independent Droideka (1)"],
        ["weight", 1],
        ["units", [_DROIDEKA]],
        ["skill", [0.52, 0.67]],
        ["objectClearance", 8],
        ["terrainClearance", 4],
        ["maxGradient", 0.24],
        ["visibilityRadius", 10],
        ["visibilityHeight", 1.8]
    ]] call _fnc_addInfantryTemplate;

    ["GAT", "3AS_GAT", 3, 18, 0.15] call _fnc_addVehicleTemplate;
    ["GAT Light", "3AS_GAT_Light", 4, 15, 0.19] call _fnc_addVehicleTemplate;
    ["N99", "3AS_N99", 3, 17, 0.16] call _fnc_addVehicleTemplate;
    ["N99 Canister", "3AS_N99_Canister", 2, 17, 0.16] call _fnc_addVehicleTemplate;
    ["AGT Raptor", "ls_vehicle_agtRaptor", 2, 16, 0.17] call _fnc_addVehicleTemplate;
    ["AAT Red", "3AS_AAT_Red", 4, 18, 0.15] call _fnc_addVehicleTemplate;
    ["MTT", "3AS_MTT", 1, 32, 0.10] call _fnc_addVehicleTemplate;
    ["Heavy AAT Flamer", "3AS_Heavy_AAT_Flamer_F", 1, 22, 0.12] call _fnc_addVehicleTemplate;
    ["Heavy AAT Shield", "3AS_Heavy_AAT_Shield_F", 1, 22, 0.12] call _fnc_addVehicleTemplate;
    ["AAT Desert", "3AS_AAT_Desert", 3, 18, 0.15] call _fnc_addVehicleTemplate;
    ["AAT", "3AS_AAT", 4, 18, 0.15] call _fnc_addVehicleTemplate;

    ["HMP Gunship", "3AS_HMP_Gunship"] call _fnc_addAircraftTemplate;
    ["HMP Transport", "3AS_HMP_Transport"] call _fnc_addAircraftTemplate;
    ["Tri-Fighter", "3AS_Tri_Fighter_DynamicLoadout"] call _fnc_addAircraftTemplate;
    ["Vulture Droid", "3AS_CIS_Vulture_F"] call _fnc_addAircraftTemplate;
    ["Vulture Droid AA", "3AS_CIS_Vulture_AA_F"] call _fnc_addAircraftTemplate;

    _missingClasses = _missingClasses arrayIntersect _missingClasses;

    _templateCache = createHashMapFromArray [
        ["infantryTemplates", _infantryTemplates],
        ["vehicleTemplates", _vehicleTemplates],
        ["aircraftTemplates", _aircraftTemplates],
        ["missingClasses", _missingClasses]
    ];

    missionNamespace setVariable [_cacheName, _templateCache];

    if !(_missingClasses isEqualTo []) then {
        diag_log format [
            "[TMC v6] Missing classes were removed from the spawn pools: %1",
            _missingClasses
        ];
    };
};

private _config = createHashMapFromArray [
    ["center", _request getOrDefault ["center", objNull]],
    ["side", _request getOrDefault ["enemySide", east]],
    ["targetSide", _request getOrDefault ["targetSide", west]],
    ["waveId", _request getOrDefault ["waveId", -1]],
    ["minSpawnRadius", _request getOrDefault ["minSpawnRadius", 0]],
    ["maxSpawnRadius", _request getOrDefault ["maxSpawnRadius", 850]],
    ["minPlayerDistance", _request getOrDefault ["minPlayerDistance", 100]],
    ["visibilityMaxDistance", _request getOrDefault ["visibilityMaxDistance", 1800]],
    ["visibilityThreshold", _request getOrDefault ["visibilityThreshold", 0.05]],
    ["attemptsPerGroup", _request getOrDefault ["attemptsPerGroup", 60]],
    ["groupSeparation", _request getOrDefault ["groupSeparation", 45]],
    ["airMinSpawnRadius", _request getOrDefault ["airMinSpawnRadius", 1800]],
    ["airMaxSpawnRadius", _request getOrDefault ["airMaxSpawnRadius", 2600]],
    ["airSpawnAltitude", _request getOrDefault ["airSpawnAltitude", 250]],
    ["airSpeed", _request getOrDefault ["airSpeed", 90]],
    ["rushRange", _request getOrDefault ["rushRange", 1800]],
    ["rushCycle", _request getOrDefault ["rushCycle", 10]],
    ["rushOnlyPlayers", _request getOrDefault ["rushOnlyPlayers", false]],
    ["infantryGroupCount", [0, 1] select (_kind isEqualTo "INFANTRY")],
    ["vehicleGroupCount", [0, 1] select (_kind isEqualTo "VEHICLE")],
    ["aircraftGroupCount", [0, 1] select (_kind isEqualTo "AIR")],
    ["infantryTemplates", _templateCache getOrDefault ["infantryTemplates", []]],
    ["vehicleTemplates", _templateCache getOrDefault ["vehicleTemplates", []]],
    ["aircraftTemplates", _templateCache getOrDefault ["aircraftTemplates", []]],
    ["lambsReinforcement", true],
    ["lambsKnowledgeSeedChance", 0.25],
    ["debugMode", toUpper (_request getOrDefault ["debugMode", "NONE"])],
    ["onGroupSpawned", {
        params ["_group", "_kind", "_template", "_spawnPosition", "_asset", "_config"];

        private _kindUpper = toUpper _kind;
        private _waveId = _config getOrDefault ["waveId", -1];

        _group setVariable ["TMC_attackWaveManaged", true];
        _group setVariable ["TMC_attackWaveKind", _kindUpper];
        _group setVariable ["TMC_attackWaveId", _waveId];
        _group setVariable [
            "TMC_attackWaveTemplate",
            _template getOrDefault ["name", "UNKNOWN"]
        ];

        private _stateName = "TMC_ContinuousDirector_State_v6";
        private _state = missionNamespace getVariable [_stateName, createHashMap];

        if ((count _state) > 0) then {
            switch (_kindUpper) do {
                case "INFANTRY": {
                    private _groups = _state getOrDefault ["infantryGroups", []];
                    _groups pushBackUnique _group;
                    _state set ["infantryGroups", _groups];

                    private _directorConfig = _state getOrDefault ["config", createHashMap];
                    if (_directorConfig getOrDefault ["ignoreAircraft", true]) then {
                        {
                            if (!isNull _x && { alive _x }) then {
                                _group ignoreTarget _x;
                            };
                        } forEach (_state getOrDefault ["knownAircraft", []]);
                    };
                };

                case "VEHICLE": {
                    private _groups = _state getOrDefault ["vehicleGroups", []];
                    _groups pushBackUnique _group;
                    _state set ["vehicleGroups", _groups];

                    if (!isNull _asset) then {
                        _asset setVariable ["TMC_attackWaveVehicle", true];
                        _asset setVariable ["TMC_attackWaveId", _waveId];

                        private _assets = _state getOrDefault ["managedVehicles", []];
                        _assets pushBackUnique _asset;
                        _state set ["managedVehicles", _assets];
                    };
                };

                case "AIR": {
                    private _groups = _state getOrDefault ["airGroups", []];
                    _groups pushBackUnique _group;
                    _state set ["airGroups", _groups];

                    if (!isNull _asset) then {
                        _asset setVariable ["TMC_attackWaveAircraft", true];
                        _asset setVariable ["TMC_attackWaveId", _waveId];

                        private _assets = _state getOrDefault ["managedAircraft", []];
                        _assets pushBackUnique _asset;
                        _state set ["managedAircraft", _assets];
                    };
                };
            };

            missionNamespace setVariable [_stateName, _state];
        };
    }],
    ["onComplete", {
        params ["_result", "_config"];

        private _failures = _result getOrDefault ["failedSpawns", []];
        private _debug = toUpper (_config getOrDefault ["debugMode", "NONE"]);

        if (!(_failures isEqualTo []) || { _debug in ["LOG", "MARKERS"] }) then {
            diag_log format [
                "[TMC v6] Package %1 complete. Groups %2 Vehicles %3 Aircraft %4 Failures %5",
                _config getOrDefault ["waveId", -1],
                count (_result getOrDefault ["groups", []]),
                count (_result getOrDefault ["vehicles", []]),
                count (_result getOrDefault ["aircraft", []]),
                _failures
            ];
        };
    }]
];

[_config] call TMC_fnc_spawnAttackWave;
