// Configuration for dynamicPatrols

// General Config
PatrolCooldownTime = 300;                // Seconds before leader can get another patrol
PatrolSpawnDistance = 200;               // Distance in front of leader to spawn patrol
PatrolDespawnDistance = 500;             // Max range before despawn
MaxPatrolsPerPlayer = 2;                 // Max enemy units per player
MaxSpawnsPerLoop = 3;                    // Limit spawns per patrol loop pass
PatrolRadius = 100;                      // Radius for LAMBS patrol tasks
EnablePatrolDebug = false;               // Toggle debug messages

// Terrain Loadouts (each array must contain exactly 6 unit classnames)
Terrain_Type_Open  = ["UK3CB_ION_O_Woodland_SL","UK3CB_ION_O_Woodland_TL","UK3CB_ION_O_Woodland_MD","UK3CB_ION_O_Woodland_RIF_1","UK3CB_ION_O_Woodland_LAT","UK3CB_ION_O_Woodland_ENG"];
Terrain_Type_Dense = ["UK3CB_ION_O_Woodland_SL","UK3CB_ION_O_Woodland_TL","UK3CB_ION_O_Woodland_MD","UK3CB_ION_O_Woodland_RIF_1","UK3CB_ION_O_Woodland_LAT","UK3CB_ION_O_Woodland_DEM"];
Terrain_Type_Urban = ["UK3CB_ION_O_Woodland_SL","UK3CB_ION_O_Woodland_TL","UK3CB_ION_O_Woodland_MD","UK3CB_ION_O_Woodland_RIF_1","UK3CB_ION_O_Woodland_ENG","UK3CB_ION_O_Woodland_DEM"];

