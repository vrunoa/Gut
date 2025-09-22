extends GutTest 
class_name GutVisualTest

var _group_dir: String = ""
var group_dir = _group_dir:
	get: return _group_dir
	set(val): _group_dir = val
	
func before_all():
	group_dir = ""

func after_all():
	group_dir = ""

## Assert tree root screenshot doesnt introduce difference with baseline
## [codeblock]
##
##    var name = "unique_screenshot_name"
##
##    # Example usage
##    assert_screenshot(name, "optional description")
##
##    # Passing
##    # First time this is run a baseline is created.  If visual_autoaccept is
##    # true then this will pass, otherwise it will fail and you will need to
##    # verify the screenshot and re-run the test.
##
##    # Failing
##    # If the screenshot differs from the baseline by more than visual_threshold
##    # percent then this will fail and a diff screenshot will be created.
##
## [/codeblock]
func assert_screenshot(name, text=""):
	var node = await get_tree().root
	return assert_node_screenshot(node, name, text, group_dir)

## Assert node screenshot doesnt introduce difference with baseline
## [codeblock]
##
##    var name = "unique_screenshot_name"
##
##    # Example usage
##    assert_node_screenshot(node, name, "optional description", "optional dir")
##
##    # Passing
##    # First time this is run a baseline is created.  If visual_autoaccept is
##    # true then this will pass, otherwise it will fail and you will need to
##    # verify the screenshot and re-run the test.
##
##    # Failing
##    # If the screenshot differs from the baseline by more than visual_threshold
##    # percent then this will fail and a diff screenshot will be created.
##
## [/codeblock]
func assert_node_screenshot(node, name, text="", out_dir=""):
	if !node.has_method("get_viewport"):
		return _fail("provided node doesnt have get_viewport method")
	
	var viewport = node.get_viewport()
	if viewport == null:
		return _fail("got null viewport for node")

	if name == "":
		return _fail("screenshot name should not be empty")

	var filename_regex = RegEx.new()
	filename_regex.compile("^[a-zA-Z0-9._-]+$")
	if !filename_regex.search(name):
		return _fail("invalid screenshot name")

	var dir = DirAccess.open("res://")
	var baseline_path = gut.visual_baseline_path
	if out_dir != "":
		baseline_path = baseline_path + out_dir
		
	var diff_path = gut.visual_diff_path
	if out_dir != "":
		diff_path = diff_path + out_dir
	
	if dir:
		dir.make_dir_recursive(baseline_path)
		dir.make_dir_recursive(diff_path)
	
	var screenshot_baseline_path = "{baseline_path}/{name}.png".format({
		"baseline_path": baseline_path,
		"name": name
	})
	var screenshot = viewport.get_texture().get_image()
	if !FileAccess.file_exists(screenshot_baseline_path):
		screenshot.save_png(screenshot_baseline_path)
		if !gut.visual_autoaccept:
			return _fail("found new baseline for {name}({screenshot_path})".format({
					"name": name,
					"screenshot_path": screenshot_baseline_path,
				})
			)
		else:
			return _pass(text)
	else:
		var fresh_screenshot_path = "{diff_path}/{name}.fresh.png".format({
			"name": name,
			"diff_path": diff_path,
		})
		var diff_screenshot_path = "{diff_path}/{name}.diff.png".format({
			"name": name,
			"diff_path": diff_path,
		})
		for fp in [fresh_screenshot_path, diff_screenshot_path]:
			if dir.file_exists(fp):
				var clean = dir.remove(fp)
				if clean != OK:
					return _fail("failed to cleanup diff screenshots: {name}({fp})".format({
						"name": name,
						"fp": fp,
					}))

		screenshot.save_png(fresh_screenshot_path)
		var diff_result = ImageComparator.compare_files(screenshot_baseline_path, fresh_screenshot_path)
		if diff_result.error != ImageComparator.ImageComparatorError.OK:
			return _fail("failed to compare images: {error_code}". format({
				"error_code": diff_result["error"]
			}))
		if diff_result["percent_different"] > gut.visual_threshold:
			diff_result["diff_image"].save_png(diff_screenshot_path)
			return _fail("found visual {percent}% differences {name}({diff_path})".format({
				"percent": diff_result["percent_different"],
				"name": name,
				"diff_path": diff_screenshot_path
			}))

		return _pass(text)
