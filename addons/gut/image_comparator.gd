class_name ImageComparator
extends RefCounted

enum ImageComparatorError {
	OK = 0,
	BASELINE_FILE_NOT_FOUND = 1,
	DIFF_FILE_NOT_FOUND = 2,
	INVALID_FORMAT = 3,
	SIZE_MISMATCH = 4,
	LOAD_FAILED = 5
}

## Compare two image files and return difference image and percentage
## Returns: Dictionary with keys: diff_image, percent_different, ImageComparatorError
static func compare_files(baseline_path: String, diff_path: String) -> Dictionary:
	var src_image = load_image(baseline_path)
	if src_image == null:
		return {
			"diff_image": null,
			"percent_different": 0.0,
			"error": ImageComparatorError.BASELINE_FILE_NOT_FOUND
		}

	var dst_image = load_image(diff_path)
	if dst_image == null:
		return {
			"diff_image": null,
			"percent_different": 0.0,
			"error": ImageComparatorError.DIFF_FILE_NOT_FOUND
		}

	return compare_images(src_image, dst_image)

## Compare two Image objects pixel by pixel
## Returns: Dictionary with keys: diff_image, percent_different, ImageComparatorError
static func compare_images(src: Image, dst: Image) -> Dictionary:
	var src_size = src.get_size()
	var dst_size = dst.get_size()

	if !bounds_match(src_size, dst_size):
		return {
			"diff_image": null,
			"percent_different": 100.0,
			"error": ImageComparatorError.SIZE_MISMATCH
		}

	# Create diff image with same size
	var diff_image = Image.create(src_size.x, src_size.y, false, Image.FORMAT_RGBA8)

	var different_pixels = 0.0
	var total_pixels = src_size.x * src_size.y

	# Compare pixel by pixel
	for y in range(src_size.y):
		for x in range(src_size.x):
			var src_color = src.get_pixel(x, y)
			var dst_color = dst.get_pixel(x, y)

			# Set base color (destination with low alpha)
			diff_image.set_pixel(x, y, Color(dst_color.r, dst_color.g, dst_color.b, 0.25))

			if !is_equal_color(src_color, dst_color):
				different_pixels += 1.0
				# Add red dot in diff image for different pixels
				diff_image.set_pixel(x, y, Color.RED)

	var diff_percent = (different_pixels / total_pixels) * 100.0
	return {
		"diff_image": diff_image,
		"percent_different": diff_percent,
		"error": ImageComparatorError.OK
	}

## Check if two colors are equal (with some tolerance for floating point precision)
static func is_equal_color(a: Color, b: Color) -> bool:
	# Use a small epsilon for floating point comparison
	var epsilon = 0.001
	return (abs(a.r - b.r) < epsilon and
			abs(a.g - b.g) < epsilon and
			abs(a.b - b.b) < epsilon and
			abs(a.a - b.a) < epsilon)

## Check if two Vector2i sizes match
static func bounds_match(a: Vector2i, b: Vector2i) -> bool:
	return a.x == b.x and a.y == b.y

## Load an image from file path
static func load_image(filename: String) -> Image:
	if !FileAccess.file_exists(filename):
		print("Error: File does not exist: ", filename)
		return null

	var image = Image.new()
	var error = image.load(filename)

	if error != OK:
		print("Error loading image: ", filename, " (Error code: ", error, ")")
		return null

	return image

## Save an image to file
static func save_image(image: Image, filename: String) -> bool:
	var error = image.save_png(filename)
	if error != OK:
		print("Error saving image: ", filename, " (Error code: ", error, ")")
		return false
	return true

## Create a visual diff image with highlighted differences
## This creates a side-by-side comparison with differences highlighted
static func create_visual_diff(src: Image, dst: Image, diff: Image) -> Image:
	var src_size = src.get_size()
	var dst_size = dst.get_size()

	# Create a wider image to show all three: src, dst, diff
	var total_width = src_size.x + dst_size.x + diff.get_size().x
	var max_height = max(src_size.y, dst_size.y, diff.get_size().y)

	var visual_diff = Image.create(total_width, max_height, false, Image.FORMAT_RGBA8)

	# Fill with black background
	visual_diff.fill(Color.BLACK)

	# Copy source image to left
	visual_diff.blit_rect(src, Rect2i(0, 0, src_size.x, src_size.y), Vector2i(0, 0))

	# Copy destination image to middle
	visual_diff.blit_rect(dst, Rect2i(0, 0, dst_size.x, dst_size.y), Vector2i(src_size.x, 0))

	# Copy diff image to right
	visual_diff.blit_rect(diff, Rect2i(0, 0, diff.get_size().x, diff.get_size().y), Vector2i(src_size.x + dst_size.x, 0))

	return visual_diff

## Calculate similarity percentage (inverse of difference)
static func calculate_similarity(src: Image, dst: Image) -> float:
	var result = compare_images(src, dst)
	if result["diff_image"] == null:  # Error case
		return 0.0

	var diff_percent = result["percent_different"] as float
	return 100.0 - diff_percent
