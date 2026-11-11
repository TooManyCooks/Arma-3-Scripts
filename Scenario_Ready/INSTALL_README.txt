TMC FUNCTIONS - SCENARIO READY INSTALLATION

DOWNLOAD
Download the tmc-functions branch ZIP, then copy the files listed below into the root of the Arma 3 scenario folder.

FILES TO COPY FROM TMC_ContinuousDirector_v5
- TMC_AttackWave_CloneWars.sqf
- TMC_ContinuousDirector.sqf
- TMC_fnc_spawnAttackWave.sqf

FILES TO COPY FROM Scenario_Ready
- TMC_CfgFunctions.hpp
- TMC_TaskGarrison.sqf

Your scenario root should contain:
- description.ext
- mission.sqm
- TMC_AttackWave_CloneWars.sqf
- TMC_CfgFunctions.hpp
- TMC_ContinuousDirector.sqf
- TMC_fnc_spawnAttackWave.sqf
- TMC_TaskGarrison.sqf

DESCRIPTION.EXT
Keep this line near the top of description.ext:

#include "TMC_CfgFunctions.hpp"

Do not place the include inside another class CfgFunctions block. The supplied TMC_CfgFunctions.hpp already contains the full class CfgFunctions definition.

TASK GARRISON TRIGGER
Use this in the On Activation box of each Task#_start trigger:

[thisTrigger] execVM "TMC_TaskGarrison.sqf";

Recommended settings:
- Server Only: Yes
- Repeatable: No

The trigger must be centered over the buildings to populate. Its largest width or height becomes the building-search radius.

To force a specific search radius instead of using the trigger size:

[thisTrigger, 150] execVM "TMC_TaskGarrison.sqf";

CONTINUOUS DIRECTOR
Continue starting TMC_ContinuousDirector.sqf with the existing trigger or initServer call used by the mission.

IMPORTANT
Task Garrison is called directly with execVM. It does not need a CfgFunctions entry and cannot overwrite or conflict with TMC_fnc_spawnAttackWave.

After changing TMC_CfgFunctions.hpp or description.ext, fully reload the mission or restart the dedicated server.

TROUBLESHOOTING
Search the server RPT for:

[TMC Task Garrison]

The log reports the trigger, total players, search radius, buildings found, positions found, droids requested, and droids successfully garrisoned.
