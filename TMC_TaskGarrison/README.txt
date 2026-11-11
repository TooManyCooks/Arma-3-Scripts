TMC Task Garrison

PURPOSE
Creates one EAST droid group and places it in buildings around a task-start trigger.

REQUIREMENTS
- CBA_A3 recommended
- ACE3 recommended
- JLTS / Legion Studios droid classes used by the script

SCENARIO-FOLDER INSTALLATION
1. Copy fn_taskGarrison.sqf into the mission root and rename it:

   TMC_TaskGarrison.sqf

2. Put this in the On Activation field of every Task#_start trigger:

   [thisTrigger] execVM "TMC_TaskGarrison.sqf";

3. Recommended trigger settings:

   Server Only: Yes
   Repeatable: No

No CfgFunctions entry is required for Task Garrison. It runs directly through execVM and therefore cannot conflict with TMC_fnc_spawnAttackWave.

IMPORTANT AREA SETUP
The trigger position is the center of the garrison. The larger trigger width or height is used as the building-search radius, with a minimum of 25 meters.

The trigger must be placed over the buildings that should be populated and must be large enough to cover them.

Optional fixed radius example:

   [thisTrigger, 150] execVM "TMC_TaskGarrison.sqf";

This searches 150 meters around the trigger regardless of the trigger's dimensions.

BEHAVIOR
- Counts all connected human players.
- Requests 2 droids per player.
- Uses a minimum of 6 droids.
- Has no scripted maximum droid count.
- Available building positions remain the practical limit.
- Every spawned droid belongs to one EAST group.
- Empty groups delete themselves.
- Uses CBA player, building-position, and shuffle helpers when available.
- Uses ACE random teleport garrison placement when available.
- Includes a built-in placement fallback if ACE garrison is unavailable.
- Deletes units that cannot be placed.
- Does not use JLTS_Droid_B1_Marine.
- Prevents the same non-repeatable trigger from spawning twice.

COMPOSITION
- Main line unit: JLTS_Droid_B1_E5
- Approximately 1 JLTS_Droid_B1_AR per 5 droids
- Approximately 1 JLTS_Droid_B1_SBB3 per 8 droids
- Approximately 1 JLTS_Droid_B1_AT per 10 droids
- Approximately 1 ls_droid_b2 per 12 droids

TROUBLESHOOTING
Search the server RPT for:

   [TMC Task Garrison]

The final log line reports player count, radius, buildings found, positions found, droids requested, and droids successfully placed.
