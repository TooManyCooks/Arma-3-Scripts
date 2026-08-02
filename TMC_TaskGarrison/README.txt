TMC Task Garrison

Purpose:
Creates a single EAST droid group and garrisons it inside buildings covered by a task-start trigger.

Requirements:
- CBA_A3
- ACE3 AI garrison function
- JLTS / Legion Studios droid classes used by the script

Installation:
1. Copy the entire TMC_TaskGarrison folder into the mission scenario folder.

2. Register the function in description.ext.

If the mission does not already have CfgFunctions:

class CfgFunctions
{
    #include "TMC_TaskGarrison\CfgFunctions.hpp"
};

If the mission already has CfgFunctions, add this line inside the existing class CfgFunctions block:

#include "TMC_TaskGarrison\CfgFunctions.hpp"

3. Put this in the On Activation field of each Task#_start trigger:

[thisTrigger] spawn TMC_fnc_taskGarrison;

Recommended trigger settings:
- Server Only: Yes
- Repeatable: No

Behavior:
- Counts all connected human players using CBA_fnc_players.
- Headless clients are excluded by CBA_fnc_players.
- Requests 2 droids per connected player.
- Uses a minimum of 6 droids.
- Uses no scripted maximum droid count.
- The available building positions inside the trigger radius remain the placement limit.
- Every spawned droid belongs to one EAST group.
- The group is marked for deletion when empty.
- Building capacity is gathered with CBA_fnc_buildingPositions.
- Unit class order is randomized with CBA_fnc_shuffle.
- ACE randomly teleports units into garrison positions.
- Units ACE cannot garrison are deleted.
- JLTS_Droid_B1_Marine is not used.

Composition:
- Main line unit: JLTS_Droid_B1_E5
- Approximately 1 JLTS_Droid_B1_AR per 5 droids
- Approximately 1 JLTS_Droid_B1_SBB3 per 8 droids
- Approximately 1 JLTS_Droid_B1_AT per 10 droids
- Approximately 1 ls_droid_b2 per 12 droids

The trigger's largest horizontal dimension is used as the garrison radius, with a minimum radius of 25 meters.
