TMC FUNCTIONS - SCENARIO SETUP

The TaskGarrison problem was caused by mixing the folder-based CfgFunctions package with the flat scenario-folder layout. This corrected version is intentionally called directly with execVM and does not need CfgFunctions registration.

COPY THESE FILES INTO THE SCENARIO ROOT
- TMC_TaskGarrison.sqf
- TMC_CfgFunctions.hpp

KEEP THESE EXISTING FILES IN THE SCENARIO ROOT
- TMC_AttackWave_CloneWars.sqf
- TMC_ContinuousDirector.sqf
- TMC_fnc_spawnAttackWave.sqf

DESCRIPTION.EXT
It must contain this line:

#include "TMC_CfgFunctions.hpp"

TASK START TRIGGER
On Activation:

[thisTrigger] execVM "TMC_TaskGarrison.sqf";

Recommended settings:
- Server Only: Yes
- Repeatable: No

The trigger's largest horizontal dimension is used as the garrison radius.

TESTING
Give the task-start trigger a variable name such as Task1_start, then run this from Server Exec:

[Task1_start] execVM "TMC_TaskGarrison.sqf";

Check the server RPT for messages beginning with:
[TMC Task Garrison]

BEHAVIOR
- Counts all connected human players.
- Requests 2 droids per player.
- Minimum 6 droids.
- Available building positions are the practical limit.
- All droids are in one EAST group.
- JLTS_Droid_B1_Marine is excluded.
- Uses CBA player, building-position, and shuffle helpers when available.
- Falls back to vanilla Arma equivalents where possible.
- Uses ACE AI garrison placement.
- Deletes droids ACE could not place.
- Prevents the same trigger from spawning the garrison twice.
