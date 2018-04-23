extends Node2D

var touch_start
var touch_position

var draw_path = []
var predefined_gestures = []

var debug_last_point
var debug_check_gesture = false
var online_prediction = false

func _ready():
	predefined_gestures = read_gestures("res://gestures/")
	for gesture in predefined_gestures:
		gesture[1] =  resample(gesture[1], 16)
		gesture[1] =  vectorize(gesture[1], true)
	set_process_input(true)
	
func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.is_action_pressed("left_mouse_click"):
			touch_start = get_viewport().get_mouse_position()
			debug_last_point = touch_start
		elif event.is_action_released("left_mouse_click"):
			touch_start = null
	elif event is InputEventMouseMotion:
		touch_position = get_viewport().get_mouse_position()
	#if Input.is_action_just_pressed("right_mouse_click"):
	#	debug_check_gesture = true
var temp_length = 0.0
func _process(delta):
	if touch_start:
		if touch_position != debug_last_point:
			draw_path.append(touch_position)
			temp_length += touch_position.distance_to(debug_last_point)
			debug_last_point = touch_position
			if online_prediction and temp_length / 30.0 > 1.0: #ontime predection
				protractor_recognize(draw_path, 16, true, predefined_gestures)
				temp_length = 0.0
	elif draw_path.size() > 1:
		protractor_recognize(draw_path, 16, true, predefined_gestures)
		draw_path = []
		temp_length = 0.0
	else:
		draw_path = []
		temp_length = 0.0
	update()
	#print("points: " + str(draw_path.size()))

func _draw():
	for point in draw_path:
    	draw_circle(point, 3.0, Color(1,1,1))

func protractor_recognize(points, n, o_sensitive, templates):
	points = resample(points, n)
	points = vectorize(points, o_sensitive)
	
	var best_score = 1e9
	var template_name = ""
	for template in templates:
		var dist = optimal_cosine_distance(points, template[1])
		if dist < best_score:
			best_score = dist
			template_name = template[0]
	
	print(template_name + ": " + str(1.0 / best_score))
	get_node("Label").text = template_name + ": " + str(1.0 / best_score)

###########
## UTILS ##
###########
func resample(points, n):
	var interval = path_length(points) / (n-1)
	var D = 0.0
	var src_pts = [] + points
	var rst_pts = [src_pts[0]]
	
	var i = 1
	while(true):
		var pt1 = src_pts[i-1]
		var pt2 = src_pts[i]
		var d = pt1.distance_to(pt2)
		
		if (D + d) >= interval:
			var qx = pt1.x + ((interval - D) / d) * (pt2.x - pt1.x)
			var qy = pt1.y + ((interval - D) / d) * (pt2.y - pt1.y)
			rst_pts.append(Vector2(qx, qy))
			src_pts.insert(i, Vector2(qx, qy))
			D = 0.0
		else:
			D = D + d
		i += 1
		if i >= src_pts.size():
			break
	
	if rst_pts.size() == n-1:
		rst_pts.append(src_pts[src_pts.size()-1])
	return rst_pts

func path_length(points):
	var dist = 0
	for i in range(1, points.size()):
		dist += points[i-1].distance_to(points[i])
	return dist

func vectorize(points, o_sensitive):
	var c = centroid(points)
	points = translate_to(points, c)
	var indicative_angle = atan2(points[0].y, points[0].x)
	var d = 0.0
	
	if o_sensitive:
		var base_orientation = (PI / 4.0) * floor((indicative_angle + PI / 8.0) / (PI / 4.0))
		d = base_orientation - indicative_angle
	else:
		d = -indicative_angle
	
	var sum = 0
	var vector = []
	for point in points:
		var new_x = point.x * cos(d) - point.y * sin(d)
		var new_y = point.y * cos(d) - point.x * sin(d)
		vector.append(new_x)
		vector.append(new_y)
		sum += new_x * new_x + new_y * new_y
	
	var magnitude = sqrt(sum)
	for i in range(0, vector.size()):
		vector[i] = vector[i] / magnitude
	return vector

func centroid(points):
	var x_sum = 0.0
	var y_sum = 0.0
	
	for point in points:
		x_sum += point.x
		y_sum += point.y
		
	return Vector2(x_sum / points.size(), y_sum / points.size())

func translate_to(points, c):
	var new_points = []
	for point in points:
		var qx = point.x - c.x
		var qy = point.y - c.y
		new_points.append(Vector2(qx, qy))
	return new_points

func optimal_cosine_distance(v1, v2):
	var a = 0.0
	var b = 0.0
	for i in range(0, v1.size(), 2):
		a += v1[i] * v2[i] + v1[i+1] * v2[i+1]
		b += v1[i] * v2[i+1] - v1[i+1] * v2[i]
	
	var angle = atan(b / a)
	return acos(a * cos(angle) + b * sin(angle))

##################
## GESTURE READ ##
##################
func read_gestures(dir_path):
	var file_names = list_file_pahts_in_directory(dir_path)
	var gestures = []
	for file_name in file_names:
		var file = File.new()
		if file.open(file_name, File.READ) != 0:
			print("Error opening file: " + file_name)
			continue
		
		var json = file.get_as_text()
		json = parse_json(json)
		var points = []
		
		for point in json["Point"]:
			points.append(Vector2(int(point["X"]), int(point["Y"])))
		
		gestures.append([json["Name"], points])
		
		print(file_name + " read")
		
		file.close()
	
	return gestures

func list_file_pahts_in_directory(dir_path):
	var file_names = []
	var dir = Directory.new()
	
	if dir.open(dir_path) == OK:
		dir.list_dir_begin()
	
		var file_name = dir.get_next()
		while file_name != "":
			if !file_name.begins_with("."):
				file_names.append(dir_path+file_name)
			
			file_name = dir.get_next()
	
		dir.list_dir_end()
	
	return file_names