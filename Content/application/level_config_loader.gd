extends RefCounted

## Loads marble upgrade modifiers and skill level values from CSV data files.
##
## Both CSVs live under Content/data/, which ContentRegistry's recursive scan
## ignores (it only collects .tres). Parsing follows
## Core/localization/localization.gd: FileAccess.get_csv_line() is quote-aware;
## a plain split(",") would break quoted cells.
##
## Failure is atomic: every error is collected, and any single error yields
## ok=false with both config halves empty — partial data is never returned and
## there is no fallback to hardcoded values. The loader never calls
## push_error(), so tests can assert on the result Dictionary directly.

const DEFAULT_MARBLE_CSV_PATH: String = "res://Content/data/marble_level_modifiers.csv"
const DEFAULT_SKILL_CSV_PATH: String = "res://Content/data/skill_level_values.csv"

const MARBLE_CSV_HEADER: PackedStringArray = ["item_id", "stat", "min_level", "value"]
const SKILL_CSV_HEADER: PackedStringArray = [
	"skill_id", "level", "recharge_time", "base_damage", "projectile_lifetime",
	"dash_damage_multiplier", "dash_damage_duration",
]

## item id -> int(Marble.MARBLE_TYPE). Kept as explicit constants instead of
## Marble.MARBLE_TYPE.get(...) to avoid any class-load ordering dependency.
const MARBLE_TYPE_BY_ITEM_ID: Dictionary = {
	"dark_marble": 0,
	"brown_marble": 1,
	"bomb_marble": 2,
	"green_marble": 3,
	"blue_marble": 4,
	"fire_marble": 5,
	"assassin_marble": 6,
	"lightning_marble": 7,
}

const KNOWN_SKILL_IDS: PackedStringArray = ["dash", "magic_missile"]

const MAX_MARBLE_LEVEL: int = 4
const MAX_SKILL_LEVEL: int = 4

## Sentinel for a non-empty cell that failed numeric parsing. A plain bool
## would collide with numeric zero comparisons (0.0 == false), and a String
## token cannot be compared against parsed ints. NAN compares validly against
## int/float and never collides with a parsed value (CSV cannot produce NAN),
## while null still means "empty cell". Detect it with _is_invalid(): IEEE
## semantics make NAN == NAN false, so direct equality cannot work.
const INVALID: float = NAN


static func load_config(
	marble_csv_path: String = DEFAULT_MARBLE_CSV_PATH,
	skill_csv_path: String = DEFAULT_SKILL_CSV_PATH
) -> Dictionary:
	var errors := PackedStringArray()
	var marble_modifiers := _load_marble_modifiers(marble_csv_path, errors)
	var skill_level_values := _load_skill_level_values(skill_csv_path, errors)
	if not errors.is_empty():
		return {&"ok": false, &"config": {}, &"errors": errors}
	return {
		&"ok": true,
		&"config": {
			&"marble_modifiers": marble_modifiers,
			&"skill_level_values": skill_level_values,
		},
		&"errors": errors,
	}


static func _try_int(raw: String) -> Variant:
	if raw.is_empty():
		return null
	if not raw.is_valid_int():
		return INVALID
	return int(raw)


static func _try_float(raw: String) -> Variant:
	if raw.is_empty():
		return null
	if not raw.is_valid_float():
		return INVALID
	return float(raw)


static func _is_invalid(parsed: Variant) -> bool:
	return parsed is float and is_nan(parsed)


static func _header_matches(header: PackedStringArray, expected: PackedStringArray) -> bool:
	if header.size() != expected.size():
		return false
	if header.is_empty():
		return false
	var first := String(header[0]).trim_prefix("﻿")
	if first != String(expected[0]):
		return false
	for column: int in range(1, expected.size()):
		if String(header[column]) != String(expected[column]):
			return false
	return true


## Returns {marble_type_int: {stat_id: [{min_level, value}, ...]}}.
## Rows for the same (item_id, stat) are sorted by min_level ascending.
static func _load_marble_modifiers(path: String, errors: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Cannot open %s" % path)
		return result
	var header: PackedStringArray = file.get_csv_line()
	if not _header_matches(header, MARBLE_CSV_HEADER):
		errors.append("%s:1: marble header mismatch" % path)
		return result
	var seen: Dictionary = {}
	var line := 1
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		line += 1
		if row.is_empty() or (row.size() == 1 and String(row[0]).is_empty()):
			continue
		if row.size() != 4:
			errors.append("%s:%d: expected 4 columns, got %d" % [path, line, row.size()])
			continue
		var item_id := String(row[0])
		var stat_id := String(row[1])
		var min_level: Variant = _try_int(String(row[2]))
		var value: Variant = _try_float(String(row[3]))
		if not MARBLE_TYPE_BY_ITEM_ID.has(item_id):
			errors.append("%s:%d: unknown marble item id '%s'" % [path, line, item_id])
			continue
		if stat_id.is_empty():
			errors.append("%s:%d: empty stat" % [path, line])
			continue
		if min_level == null or _is_invalid(min_level) \
				or int(min_level) < 1 or int(min_level) > MAX_MARBLE_LEVEL:
			errors.append("%s:%d: invalid min_level '%s'" % [path, line, String(row[2])])
			continue
		if value == null or _is_invalid(value):
			errors.append("%s:%d: invalid value '%s'" % [path, line, String(row[3])])
			continue
		var key := "%s:%s:%d" % [item_id, stat_id, int(min_level)]
		if seen.has(key):
			errors.append("%s:%d: duplicate row %s" % [path, line, key])
			continue
		seen[key] = true
		var marble_type := int(MARBLE_TYPE_BY_ITEM_ID[item_id])
		if not result.has(marble_type):
			result[marble_type] = {}
		var stats_by_id: Dictionary = result[marble_type]
		if not stats_by_id.has(stat_id):
			stats_by_id[stat_id] = []
		(stats_by_id[stat_id] as Array).append({"min_level": int(min_level), "value": float(value)})
	# Every known marble must carry at least one min_level=1 row so the level
	# curve is well defined from the starting level on.
	for item_id: String in MARBLE_TYPE_BY_ITEM_ID:
		var marble_type := int(MARBLE_TYPE_BY_ITEM_ID[item_id])
		var has_level_one := false
		if result.has(marble_type):
			for stat_id: Variant in (result[marble_type] as Dictionary):
				if (result[marble_type][stat_id] as Array).any(
						func(row: Dictionary) -> bool: return int(row.get("min_level", 0)) == 1):
					has_level_one = true
					break
		if not has_level_one:
			errors.append("%s: marble '%s' has no min_level=1 row" % [path, item_id])
	for marble_type: Variant in result:
		for stat_id: Variant in (result[marble_type] as Dictionary):
			(result[marble_type][stat_id] as Array).sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool: return int(a["min_level"]) < int(b["min_level"]))
	return result


## Returns {skill_id: [{stat fields}, ...]} ordered by level 1..4 so callers can
## index with values[level - 1]. Empty cells mean the field is absent; a literal
## 0.0 is a real value and is preserved. A transient "level" key is used for
## ordering and stripped before the result is returned.
static func _load_skill_level_values(path: String, errors: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Cannot open %s" % path)
		return result
	var header: PackedStringArray = file.get_csv_line()
	if not _header_matches(header, SKILL_CSV_HEADER):
		errors.append("%s:1: skill header mismatch" % path)
		return result
	var seen: Dictionary = {}
	var line := 1
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		line += 1
		if row.is_empty() or (row.size() == 1 and String(row[0]).is_empty()):
			continue
		if row.size() != SKILL_CSV_HEADER.size():
			errors.append("%s:%d: expected %d columns, got %d"
					% [path, line, SKILL_CSV_HEADER.size(), row.size()])
			continue
		var skill_id := String(row[0])
		var level: Variant = _try_int(String(row[1]))
		if not KNOWN_SKILL_IDS.has(skill_id):
			errors.append("%s:%d: unknown skill id '%s'" % [path, line, skill_id])
			continue
		if level == null or _is_invalid(level) \
				or int(level) < 1 or int(level) > MAX_SKILL_LEVEL:
			errors.append("%s:%d: invalid level '%s'" % [path, line, String(row[1])])
			continue
		var key := "%s:%d" % [skill_id, int(level)]
		if seen.has(key):
			errors.append("%s:%d: duplicate level %d for skill '%s'"
					% [path, line, int(level), skill_id])
			continue
		seen[key] = true
		var recharge: Variant = _try_float(String(row[2]))
		if recharge == null or _is_invalid(recharge):
			errors.append("%s:%d: invalid recharge_time '%s'" % [path, line, String(row[2])])
			continue
		var values: Dictionary = {"level": int(level), "recharge_time": float(recharge)}
		var row_valid := true
		for column: int in range(3, 7):
			var raw := String(row[column])
			if raw.is_empty():
				continue
			if column == 3:
				var parsed: Variant = _try_int(raw)
				if _is_invalid(parsed):
					errors.append("%s:%d: invalid base_damage '%s'" % [path, line, raw])
					row_valid = false
				else:
					values["base_damage"] = int(parsed)
			else:
				var field_name := String(SKILL_CSV_HEADER[column])
				var parsed_float: Variant = _try_float(raw)
				if _is_invalid(parsed_float):
					errors.append("%s:%d: invalid %s '%s'" % [path, line, field_name, raw])
					row_valid = false
				else:
					values[field_name] = float(parsed_float)
		if not row_valid:
			continue
		if not result.has(skill_id):
			result[skill_id] = []
		(result[skill_id] as Array).append(values)
	# Every skill must carry levels 1..4 so values[level - 1] indexing stays
	# valid across the whole growth curve.
	for skill_id: String in KNOWN_SKILL_IDS:
		if not result.has(skill_id):
			errors.append("%s: skill '%s' missing" % [path, skill_id])
			continue
		var levels: Array = result[skill_id]
		for expected_level: int in range(1, MAX_SKILL_LEVEL + 1):
			if not levels.any(func(values: Dictionary) -> bool:
					return int(values.get("level", 0)) == expected_level):
				errors.append("%s: skill '%s' missing level %d" % [path, skill_id, expected_level])
		levels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["level"]) < int(b["level"]))
		for values: Dictionary in levels:
			values.erase("level")
	return result
