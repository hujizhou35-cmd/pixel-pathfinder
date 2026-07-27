# Test results

## V2 UI regression

- Scene: `res://test/v2_ui_test.tscn`
- Result: `V2_UI_TEST: PASS (97 assertions)`
- Saved/empty title states covered.
- Physical windows covered: 1280×720, 1366×768, 1600×900, 1920×1080.
- All visible title buttons stayed inside the 1280×720 logical viewport.
- Exit remained visible and at/before y=720.
- Help structure, scrolling, fixed close, Esc, and stack return all passed.

## Full gameplay smoke

- Scene: `res://test/smoke_test.tscn`
- Result: `SMOKE OK - 全部检查通过`
- Passed checks: 232.
- Coverage includes maps, combat, save/load, three slots, equipment generation,
  175-entry codex, six equipment slots, affixes, elemental rules, forging,
  smelting, perks, bosses, multi-region state, death, and endless cycles.

## Visual integration

- Scene: `res://test/visual_integration_test.tscn`
- Result: `VISUAL_INTEGRATION_TEST: PASS (2618 assertions)`
- Covered 35 equipment-family mappings, 175 texture paths, four frames,
  neutral-hero equality, rarity/prefix/affix invariance, particle-only element
  differences, helmets, boots, and weapon layer lengths.

## Screenshot regression

- Scene: `res://test/shot_test.tscn`
- Result: `SHOTS DONE`
- Post-fix runtime shots refreshed for title, CG, map, combat, reward, inventory,
  equipment actions, perks, codex, stats, shop, and events.

## Protected logic audit

- Register: `audit/Protected_File_Register.csv`
- Diff: `audit/Protected_File_Diff_Audit.csv`
- Result: `PASS (0 differences)`

The test-run exit warnings about Tween/ObjectDB cleanup occur after test scenes
request immediate process shutdown. They did not change the zero exit code or
any assertion result.

Overall result: **PASS**
