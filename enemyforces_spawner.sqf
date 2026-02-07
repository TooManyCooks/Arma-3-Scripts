// enemywaves.sqf
// Script by TooManyCooks
// This script is intended to have a constant light amount of enemy forces coming in at the players so that they don't get bored.

if (!isServer) exitWith {};  // run on server only

// === CONFIG ===
private _waveTime        = 300;            // seconds between waves
private _spawnInterval   = 10;             // seconds between spawns inside a wave

// Air
private _airSpawnMarker  = "cisair";
private _numAircraft     = 3;
private _airDir          = 180;
private _aircraftTypes   = [
    "3AS_CIS_Vulture_AA_F",
    "3AS_CIS_Vulture_F",
    "3AS_HMP_Gunship"
];

// Ground
private _groundSpawnMarker = "cisground1";
private _numGround         = 3;
private _groundDir         = 215;
private _groundVehicleTypes = [
    "3AS_AAT_CIS", 
    "3AS_GAT", 
    "ls_vehicle_agtRaptor", 
    "3AS_N99"
];

// === CONTROL VARIABLE (start/stop via trigger) ===
enemywaves_active = true;
publicVariable "enemywaves_active";
systemChat "Enemy Forces are now in the area!";

// Helper: pick target player (returns objNull if none)
private _fnc_getTargetPlayer = {
    if ((count allPlayers) > 0) then { selectRandom allPlayers } else { objNull }
};

// === MAIN LOOP ===
while { enemywaves_active } do {

    // ——— AIR WAVE ———
    [
        _numAircraft, _aircraftTypes, _airSpawnMarker, _airDir, _spawnInterval, _fnc_getTargetPlayer
    ] spawn {
        params ["_numAircraft", "_aircraftTypes", "_airSpawnMarker", "_airDir", "_spawnInterval", "_fnc_getTargetPlayer"];

        for "_i" from 1 to _numAircraft do {
            if (!enemywaves_active) exitWith {};
            if ((count _aircraftTypes) == 0) exitWith { systemChat "[AIR][ERROR] _aircraftTypes is empty."; };

            private _type = selectRandom _aircraftTypes;

            private _pos = getMarkerPos _airSpawnMarker;
            if (_pos isEqualTo [0,0,0]) exitWith { systemChat "[AIR][ERROR] Spawn marker not found."; };
            _pos set [2, 200];

            private _veh = createVehicle [_type, _pos, [], 0, "FLY"];
            _veh setDir _airDir;
            _veh setVelocityModelSpace [0, 55.56, 0];
            private _crew = createVehicleCrew _veh;

            // SAD on random player
            private _tgt = call _fnc_getTargetPlayer;
            if (!isNull _tgt) then {
                private _grp = group _veh;
                while {(count waypoints _grp) > 0} do { deleteWaypoint [_grp, 0]; };
                private _wp = _grp addWaypoint [getPos _tgt, 0];
                _wp setWaypointType "SAD";
                _wp setWaypointSpeed "FULL";
                _wp setWaypointBehaviour "COMBAT";
            } else {
                systemChat "[AIR] No players to target.";
            };

            sleep _spawnInterval;
        };

    };

    // ——— GROUND WAVE ———
    [
        _numGround, _groundVehicleTypes, _groundSpawnMarker, _groundDir, _spawnInterval, _fnc_getTargetPlayer
    ] spawn {
        params ["_numGround", "_groundVehicleTypes", "_groundSpawnMarker", "_groundDir", "_spawnInterval", "_fnc_getTargetPlayer"];

        for "_i" from 1 to _numGround do {
            if (!enemywaves_active) exitWith {};
            if ((count _groundVehicleTypes) == 0) exitWith { systemChat "[GROUND][ERROR] _groundVehicleTypes is empty."; };

            private _type = selectRandom _groundVehicleTypes;

            private _pos = getMarkerPos _groundSpawnMarker;
            if (_pos isEqualTo [0,0,0]) exitWith { systemChat "[GROUND][ERROR] Spawn marker not found."; };
            _pos set [2, 0.5];

            private _veh = createVehicle [_type, _pos, [], 0, "NONE"];
            _veh setDir _groundDir;
            private _crew = createVehicleCrew _veh;

            // SAD on random player
            private _tgt = call _fnc_getTargetPlayer;
            if (!isNull _tgt) then {
                private _grp = group _veh;
                while {(count waypoints _grp) > 0} do { deleteWaypoint [_grp, 0]; };
                private _wp = _grp addWaypoint [getPos _tgt, 0];
                _wp setWaypointType "SAD";
                _wp setWaypointSpeed "FULL";
                _wp setWaypointBehaviour "COMBAT";
            } else {
                systemChat "[GROUND] No players to target.";
            };

            sleep _spawnInterval;
        };
    };

    sleep _waveTime;
};

systemChat "Enemy Forces have been pushed back for now.";