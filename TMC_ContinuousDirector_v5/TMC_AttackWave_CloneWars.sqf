if (!isServer) exitWith {};

if (isNil "TMC_fnc_spawnAttackWave") then {
    TMC_fnc_spawnAttackWave = compileFinal preprocessFileLineNumbers "TMC_fnc_spawnAttackWave.sqf";
};

params [
    ["_center","defense_center"],
    ["_minSpawnRadius",500,[0]],
    ["_maxSpawnRadius",850,[0]],
    ["_infantryGroupCount",1,[0]],
    ["_vehicleGroupCount",0,[0]],
    ["_debugMode","LOG",[""]],
    ["_waveId",-1,[0]]
];

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

private _requiredClasses = [
    _B1_AT,_B1_AR,_B1_SBB3,_B1_COMMANDER,_B1_E5,_B1_SNIPER,
    _B2,_DROIDEKA,_BX_CAPTAIN,_BX,_BX_ASSASSIN,
    "3AS_GAT","3AS_GAT_Light","3AS_N99","3AS_N99_Canister",
    "ls_vehicle_agtRaptor","3AS_AAT_Red","3AS_MTT",
    "3AS_Heavy_AAT_Flamer_F","3AS_Heavy_AAT_Shield_F",
    "3AS_AAT_Desert","3AS_AAT"
];

private _missing = _requiredClasses select { !(isClass (configFile >> "CfgVehicles" >> _x)) };
if !(_missing isEqualTo []) exitWith {
    diag_log format ["[TMC v5] Missing classes: %1",_missing];
};

private _b1AssaultPlatoon = createHashMapFromArray [
    ["name","B1 Assault Platoon"],
    ["weight",7],
    ["units",[
        _B1_COMMANDER,
        _B1_E5,_B1_E5,_B1_E5,_B1_E5,_B1_E5,_B1_E5,_B1_E5,_B1_E5,
        _B1_E5,_B1_AR,_B1_AR,_B1_AR,_B1_AT,_B1_AT,_B1_SBB3
    ]],
    ["skill",[0.38,0.52]],
    ["formation","STAG COLUMN"],
    ["objectClearance",10],
    ["terrainClearance",3],
    ["maxGradient",0.32],
    ["visibilityRadius",14]
];

private _b1FireSupportPlatoon = createHashMapFromArray [
    ["name","B1 Fire Support Platoon"],
    ["weight",3],
    ["units",[
        _B1_COMMANDER,
        _B1_E5,_B1_E5,_B1_E5,_B1_E5,_B1_E5,_B1_E5,
        _B1_AR,_B1_AR,_B1_AR,_B1_AR,
        _B1_AT,_B1_AT,_B1_AT,
        _B1_SNIPER,_B1_SBB3
    ]],
    ["skill",[0.41,0.56]],
    ["formation","STAG COLUMN"],
    ["objectClearance",11],
    ["terrainClearance",3],
    ["maxGradient",0.30],
    ["visibilityRadius",15]
];

private _b2AssaultPlatoon = createHashMapFromArray [
    ["name","B2 Assault Platoon"],
    ["weight",2],
    ["units",[
        _B1_COMMANDER,
        _B1_E5,_B1_E5,_B1_E5,_B1_E5,_B1_E5,_B1_E5,
        _B1_AR,_B1_AR,_B1_AT,_B1_AT,
        _B2,_B2,_B2,_B2,_B2
    ]],
    ["skill",[0.44,0.59]],
    ["formation","STAG COLUMN"],
    ["objectClearance",12],
    ["terrainClearance",4],
    ["maxGradient",0.27],
    ["visibilityRadius",17],
    ["visibilityHeight",1.8]
];

private _commandoTeam = createHashMapFromArray [
    ["name","BX Commando Team"],
    ["weight",2],
    ["units",[
        _BX_CAPTAIN,
        _BX,
        _BX,
        _BX,
        _BX_ASSASSIN,
        _BX_ASSASSIN
    ]],
    ["skill",[0.58,0.72]],
    ["formation","DIAMOND"],
    ["objectClearance",8],
    ["terrainClearance",3],
    ["maxGradient",0.35],
    ["visibilityRadius",11]
];

private _droidekaSingle = createHashMapFromArray [
    ["name","Independent Droideka"],
    ["weight",3],
    ["units",[_DROIDEKA]],
    ["skill",[0.52,0.67]],
    ["formation","FILE"],
    ["objectClearance",8],
    ["terrainClearance",4],
    ["maxGradient",0.24],
    ["visibilityRadius",10],
    ["visibilityHeight",1.8]
];

private _fnc_vehicleTemplate = {
    params ["_name","_class","_weight","_clearance","_gradient",["_preferRoad",true]];
    createHashMapFromArray [
        ["name",_name],
        ["weight",_weight],
        ["vehicleClass",_class],
        ["objectClearance",_clearance],
        ["terrainClearance",8],
        ["maxGradient",_gradient],
        ["visibilityRadius",15],
        ["visibilityHeight",2.7],
        ["preferRoad",_preferRoad],
        ["roadSearchRadius",80]
    ]
};

private _vehicleTemplates = [
    ["GAT","3AS_GAT",3,18,0.15] call _fnc_vehicleTemplate,
    ["GAT Light","3AS_GAT_Light",4,15,0.19] call _fnc_vehicleTemplate,
    ["N99","3AS_N99",3,17,0.16] call _fnc_vehicleTemplate,
    ["N99 Canister","3AS_N99_Canister",2,17,0.16] call _fnc_vehicleTemplate,
    ["AGT Raptor","ls_vehicle_agtRaptor",2,16,0.17] call _fnc_vehicleTemplate,
    ["AAT Red","3AS_AAT_Red",4,18,0.15] call _fnc_vehicleTemplate,
    ["MTT","3AS_MTT",1,32,0.10] call _fnc_vehicleTemplate,
    ["Heavy AAT Flamer","3AS_Heavy_AAT_Flamer_F",1,22,0.12] call _fnc_vehicleTemplate,
    ["Heavy AAT Shield","3AS_Heavy_AAT_Shield_F",1,22,0.12] call _fnc_vehicleTemplate,
    ["AAT Desert","3AS_AAT_Desert",3,18,0.15] call _fnc_vehicleTemplate,
    ["AAT","3AS_AAT",4,18,0.15] call _fnc_vehicleTemplate
];

private _config = createHashMapFromArray [
    ["center",_center],
    ["side",east],
    ["targetSide",west],
    ["waveId",_waveId],
    ["minSpawnRadius",_minSpawnRadius],
    ["maxSpawnRadius",_maxSpawnRadius],
    ["minPlayerDistance",225],
    ["visibilityMaxDistance",1500],
    ["visibilityThreshold",0.05],
    ["infantryGroupCount",_infantryGroupCount max 0],
    ["vehicleGroupCount",_vehicleGroupCount max 0],
    ["infantryTemplates",[
        _b1AssaultPlatoon,
        _b1FireSupportPlatoon,
        _b2AssaultPlatoon,
        _commandoTeam,
        _droidekaSingle
    ]],
    ["vehicleTemplates",_vehicleTemplates],
    ["attemptsPerGroup",40],
    ["groupSeparation",45],
    ["searchRadius",250],
    ["cqbRadius",75],
    ["lambsReinforcement",true],
    ["lambsKnowledgeSeedChance",0.25],
    ["ignoreAircraft",true],
    ["spawnDelay",0.20],
    ["debugMode",toUpper _debugMode],
    ["onGroupSpawned",{
        params ["_group","_kind","_template","_spawnPosition","_vehicle","_config"];
        private _waveId = _config getOrDefault ["waveId",-1];
        _group setVariable ["TMC_attackWaveManaged",true,true];
        _group setVariable ["TMC_attackWaveKind",toUpper _kind,true];
        _group setVariable ["TMC_attackWaveId",_waveId,true];
        _group setVariable ["TMC_attackWaveTemplate",_template getOrDefault ["name","UNKNOWN"],true];
        if (!isNull _vehicle) then {
            _vehicle setVariable ["TMC_attackWaveVehicle",true,true];
            _vehicle setVariable ["TMC_attackWaveId",_waveId,true];
        };
    }],
    ["onComplete",{
        params ["_result","_config"];
        diag_log format [
            "[TMC v5] Package %1 complete. Groups %2 Vehicles %3 Failures %4",
            _config getOrDefault ["waveId",-1],
            count (_result get "groups"),
            count (_result get "vehicles"),
            _result get "failedSpawns"
        ];
    }]
];

private _handle = [_config] spawn TMC_fnc_spawnAttackWave;
waitUntil { scriptDone _handle };
