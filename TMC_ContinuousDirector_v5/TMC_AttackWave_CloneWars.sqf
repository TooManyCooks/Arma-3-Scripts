if (!isServer) exitWith {};

if (isNil "TMC_fnc_spawnAttackWave") then {
    TMC_fnc_spawnAttackWave = compileFinal preprocessFileLineNumbers "TMC_fnc_spawnAttackWave.sqf";
};

params [
    ["_center", "defense_center"],
    ["_minSpawnRadius", 500, [0]],
    ["_maxSpawnRadius", 850, [0]],
    ["_infantryGroupCount", 1, [0]],
    ["_vehicleGroupCount", 0, [0]],
    ["_debugMode", "NONE", [""]],
    ["_waveId", -1, [0]],
    ["_targetSide", west, [west]],
    ["_cqbRadius", 75, [0]]
];

private _cacheName = "TMC_CloneWars_TemplateCache_v5_LargeGroups";
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
    private _missingInfantryClasses = [];
    private _missingVehicleClasses = [];

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
            _template set ["unitCount", count _units];
            _infantryTemplates pushBack _template;
        } else {
            _missingInfantryClasses append _missing;
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
                ["roadSearchRadius", 80]
            ];
        } else {
            _missingVehicleClasses pushBack _class;
        };
    };

    private _b1AssaultUnits = [_B1_COMMANDER];
    _b1AssaultUnits append ([_B1_E5, 27] call _fnc_repeatClass);
    _b1AssaultUnits append ([_B1_AR, 6] call _fnc_repeatClass);
    _b1AssaultUnits append ([_B1_AT, 4] call _fnc_repeatClass);
    _b1AssaultUnits append ([_B1_SBB3, 2] call _fnc_repeatClass);

    [createHashMapFromArray [
        ["name", "B1 Assault Battalion Group (40)"],
        ["weight", 12],
        ["units", _b1AssaultUnits],
        ["skill", [0.38, 0.52]],
        ["objectClearance", 18],
        ["terrainClearance", 5],
        ["maxGradient", 0.28],
        ["visibilityRadius", 22]
    ]] call _fnc_addInfantryTemplate;

    private _b1FireSupportUnits = [_B1_COMMANDER];
    _b1FireSupportUnits append ([_B1_E5, 14] call _fnc_repeatClass);
    _b1FireSupportUnits append ([_B1_AR, 8] call _fnc_repeatClass);
    _b1FireSupportUnits append ([_B1_AT, 4] call _fnc_repeatClass);
    _b1FireSupportUnits append ([_B1_SNIPER, 2] call _fnc_repeatClass);
    _b1FireSupportUnits append ([_B1_SBB3, 1] call _fnc_repeatClass);

    [createHashMapFromArray [
        ["name", "B1 Fire Support Company (30)"],
        ["weight", 9],
        ["units", _b1FireSupportUnits],
        ["skill", [0.41, 0.56]],
        ["objectClearance", 16],
        ["terrainClearance", 4],
        ["maxGradient", 0.28],
        ["visibilityRadius", 20]
    ]] call _fnc_addInfantryTemplate;

    private _mixedAssaultUnits = [_B1_COMMANDER];
    _mixedAssaultUnits append ([_B1_E5, 9] call _fnc_repeatClass);
    _mixedAssaultUnits append ([_B1_AR, 3] call _fnc_repeatClass);
    _mixedAssaultUnits append ([_B1_AT, 2] call _fnc_repeatClass);
    _mixedAssaultUnits append ([_B2, 5] call _fnc_repeatClass);

    [createHashMapFromArray [
        ["name", "B1/B2 Assault Platoon (20)"],
        ["weight", 7],
        ["units", _mixedAssaultUnits],
        ["skill", [0.44, 0.59]],
        ["objectClearance", 14],
        ["terrainClearance", 4],
        ["maxGradient", 0.27],
        ["visibilityRadius", 18],
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

    _missingInfantryClasses = _missingInfantryClasses arrayIntersect _missingInfantryClasses;
    _missingVehicleClasses = _missingVehicleClasses arrayIntersect _missingVehicleClasses;

    _templateCache = createHashMapFromArray [
        ["infantryTemplates", _infantryTemplates],
        ["vehicleTemplates", _vehicleTemplates],
        ["missingInfantryClasses", _missingInfantryClasses],
        ["missingVehicleClasses", _missingVehicleClasses]
    ];

    missionNamespace setVariable [_cacheName, _templateCache];

    if !(_missingInfantryClasses isEqualTo []) then {
        diag_log format [
            "[TMC v5] Infantry templates using missing classes were disabled: %1",
            _missingInfantryClasses
        ];
    };

    if !(_missingVehicleClasses isEqualTo []) then {
        diag_log format [
            "[TMC v5] Missing vehicle classes were removed from the pool: %1",
            _missingVehicleClasses
        ];
    };
};

private _config = createHashMapFromArray [
    ["center", _center],
    ["side", east],
    ["targetSide", _targetSide],
    ["waveId", _waveId],
    ["minSpawnRadius", _minSpawnRadius],
    ["maxSpawnRadius", _maxSpawnRadius],
    ["minPlayerDistance", 225],
    ["visibilityMaxDistance", 1500],
    ["visibilityThreshold", 0.05],
    ["infantryGroupCount", _infantryGroupCount max 0],
    ["vehicleGroupCount", _vehicleGroupCount max 0],
    ["infantryTemplates", _templateCache getOrDefault ["infantryTemplates", []]],
    ["vehicleTemplates", _templateCache getOrDefault ["vehicleTemplates", []]],
    ["attemptsPerGroup", 40],
    ["groupSeparation", 45],
    ["searchRadius", 250],
    ["cqbRadius", _cqbRadius],
    ["lambsReinforcement", true],
    ["lambsKnowledgeSeedChance", 0.25],
    ["spawnDelay", 0],
    ["debugMode", toUpper _debugMode],
    ["onGroupSpawned", {
        params ["_group", "_kind", "_template", "_spawnPosition", "_vehicle", "_config"];

        private _waveId = _config getOrDefault ["waveId", -1];
        private _kindUpper = toUpper _kind;

        _group setVariable ["TMC_attackWaveManaged", true];
        _group setVariable ["TMC_attackWaveKind", _kindUpper];
        _group setVariable ["TMC_attackWaveId", _waveId];
        _group setVariable [
            "TMC_attackWaveTemplate",
            _template getOrDefault ["name", "UNKNOWN"]
        ];

        if (!isNull _vehicle) then {
            _vehicle setVariable ["TMC_attackWaveVehicle", true];
            _vehicle setVariable ["TMC_attackWaveId", _waveId];
        };

        private _stateName = "TMC_ContinuousDirector_State";
        private _state = missionNamespace getVariable [_stateName, createHashMap];

        if ((count _state) > 0) then {
            if (_kindUpper isEqualTo "INFANTRY") then {
                private _infantryGroups = _state getOrDefault ["infantryGroups", []];
                _infantryGroups pushBackUnique _group;
                _state set ["infantryGroups", _infantryGroups];

                private _directorConfig = _state getOrDefault ["config", createHashMap];
                if (_directorConfig getOrDefault ["ignoreAircraft", true]) then {
                    {
                        if (!isNull _x && { alive _x }) then {
                            _group ignoreTarget _x;
                        };
                    } forEach (_state getOrDefault ["knownAircraft", []]);
                };
            };

            if (_kindUpper isEqualTo "VEHICLE") then {
                private _vehicleGroups = _state getOrDefault ["vehicleGroups", []];
                _vehicleGroups pushBackUnique _group;
                _state set ["vehicleGroups", _vehicleGroups];

                if (!isNull _vehicle) then {
                    private _managedVehicles = _state getOrDefault ["managedVehicles", []];
                    _managedVehicles pushBackUnique _vehicle;
                    _state set ["managedVehicles", _managedVehicles];
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
                "[TMC v5] Package %1 complete. Groups %2 Vehicles %3 Failures %4",
                _config getOrDefault ["waveId", -1],
                count (_result getOrDefault ["groups", []]),
                count (_result getOrDefault ["vehicles", []]),
                _failures
            ];
        };
    }]
];

[_config] call TMC_fnc_spawnAttackWave;
