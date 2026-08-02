# TMC Functions

This is the long-lived branch for the Arma 3 Star Wars mission functions developed for TooManyCooks.

## Current packages

### TMC_ContinuousDirector_v6
Current Clone Wars reinforcement director. It enforces a hard shared limit of ten managed groups, sends infantry through a fixed-center LAMBS taskRush, gives ground vehicles exact-center Seek and Destroy waypoints, allows hidden ground spawning anywhere inside the configured radius, and matches active airborne BLUFOR aircraft one-for-one with managed CIS aircraft when group slots are available.

### TMC_ContinuousDirector_v5
Previous director version retained as a historical fallback. It includes infantry and vehicle scaling, managed registries, LAMBS CQB tasking, depleted-group merging, FPS gates, and configurable production settings.

### TMC_TaskGarrison
Reusable task-start garrison function using CBA player and building helpers plus ACE garrison placement.

## Branch policy

Future Arma 3 Star Wars functions should be added to the `tmc-functions` branch so the complete collection remains together. Each larger system should use its own folder and include its own README and installation instructions.

The Git branch uses the slug `tmc-functions` because Git branch names cannot contain spaces. Its display name and purpose are TMC Functions.
