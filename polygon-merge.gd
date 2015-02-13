
# merging polygons by walking their lines, switching back and forth between polys on each intersect
# adding new lines and vertex to replace intersecting ones

# Limitations:
# - does not detect lines crossing, only vertices in other polys (easily fixable with function that checks for intersect instead of point in poly)
#
# Vector2Array polyA: All vertices of a polygon in clockwise direction
# Vector2Array polyB: All vertices of another polygon in clockwise direction
# String polyAName: Name of polygon A, only needed for debugging
# String polyBName: Name of polygon B, only needed for debugging
func mergePolygons(polyA, polyB, polyAName, polyBName):
	var mergedLines = []
	var linesOfA = getLinesOfPoly(polyA)
	var linesOfB = getLinesOfPoly(polyB)
	
	# find all lines that intersect, mark them and relate them to each other
	for aLine in linesOfA:
		for bLine in linesOfB:
			if (doLinesIntersect(aLine, bLine)):
				var intersectId = randf()
				#print("intersectId: ",intersectId)
				aLine["crossed"] = true
				aLine["intersects"].push_back({"intersectId": intersectId, "line": bLine})
				bLine["crossed"] = true
				bLine["intersects"].push_back({"intersectId": intersectId, "line": aLine})
	
	var currPolyId = "A"
	var startLine = findUncrossedLine(linesOfA, polyA)
	var currPoly = linesOfA
	
	#if (startLine != null):
		#print("starting with poly A: ",polyAName)
	if (startLine == null):
		currPolyId = "B"
		startLine = findUncrossedLine(linesOfB, polyB)
		currPoly = linesOfB
		#print("starting with poly B: ",polyBName)
	if (startLine == null):
		#print("ALL LINES CROSSING EACH OTHER!!!!")
		return null
	
	var startPolyId = currPolyId
	var startPoly = currPoly
	var indexOne = currPoly.find(startLine)
	var startIndex = indexOne
	
	#print("################################################################")
	#print("###   loop starting up to max lines: ",(polyA.size()+polyB.size()))
	while true:
		#print("---start of iteration")
		if (indexOne >= currPoly.size()):
			#print("wrap index around to 0")
			indexOne = 0 # wrap around
		
		#print("indexOne now: ",indexOne)
		
		var currLine = currPoly[indexOne]
		#print("line index: ",indexOne," line: ",currLine) # printing something with currLine (recursive references!!!) crashes the game. Godot doesn't properly handle that. even though the loop can otherwise continue without a problem.
		
		# this is our wished-for break condition
		if (mergedLines.size() > 4 && currLine == startLine):
			#print("reached startLine") # wow! this can actually happen! so comparing lines with == works. at least that.
			break
		# this is the backup break condition because == on recursive references (like in lines) will not work
		if (mergedLines.size() > 0 && indexOne == startIndex && startPolyId == currPolyId): 
			#print("breaking while loop cause mergedLines.size() > 0 && indexOne == startIndex  && startPolyId == currPolyId")
			break
		# safeguard to break the loop if the poly outline walk goes wild. *2 because every intersection adds two lines, otherwise this could actually terminate too soon.
		if (mergedLines.size() >= (polyA.size()+polyB.size())*2 ): 
			#print("breaking while loop cause mergedLines.size() >= (polyA.size()+polyB.size())*2 ")
			showDialog("Poly merge out of control!", "Poly walk aborted at "+str(mergedLines.size())+" lines where input polys had "+str(polyA.size()+polyB.size())+" lines. \n\nPolyA: "+polyAName+" \nPolyB: "+polyBName)
			break
		
		# react on crossed or non-crossed line
		if (currLine["crossed"] == false):
			#print("no intersect. adding line: ",currLine)
			mergedLines.push_back(currLine)
		else:
			var distancesToIntersects = {}
			var crossingLine = null
			var breakLoop = false
			for someIntersection in currLine["intersects"]:
				for backIntersection in someIntersection["line"]["intersects"]:
					if (someIntersection["intersectId"] == backIntersection["intersectId"]):
						var intersectionPoint = getLineIntersection(currLine, someIntersection["line"])
						var distVector = intersectionPoint - currLine["start"]
						var dist = distVector.length()
						distancesToIntersects[dist] = someIntersection["line"]
				
			
			var distKeys = distancesToIntersects.keys()
			distKeys.sort()
			crossingLine = distancesToIntersects[distKeys[0]]
			
			# add replacement line
			#print("intersect! (crossed: ",currLine["crossed"],") (end: ",currLine["end"],") (start: ",currLine["start"],")",") (intersects: start ",crossingLine["start"]," end ",crossingLine["end"],")")
			#print("adding replacement lines: ",{"start": currLine["start"], "end": crossingLine["end"]})
			var intersectionPoint = getLineIntersection(currLine, crossingLine)
			mergedLines.push_back({"start": currLine["start"], "end": intersectionPoint})
			mergedLines.push_back({"start": intersectionPoint, "end": crossingLine["end"]})
			
			# switch to other poly
			if (currPolyId == "A"):
				#print("switch to poly B: ",polyBName)
				currPoly = linesOfB
				currPolyId = "B"
			elif (currPolyId == "B"):
				#print("switch to poly A: ",polyAName)
				currPoly = linesOfA
				currPolyId = "A"
			
			indexOne = currPoly.find(crossingLine)
			#print("index of crossing line in other poly: ",indexOne)
		
		indexOne += 1
		
		#print("mergedLines ",mergedLines.size())
		#print("indexOne ",indexOne," startIndex ",startIndex)
		
		#print("---end of iteration.")
	
	#print("###loop ended")
	
	# convert lines of poly to vertices
	var mergedPoly = Vector2Array()
	for line in mergedLines:
		mergedPoly.push_back(line["start"])
	
	#print("returning mergedPoly: ",mergedPoly)
	
	return mergedPoly


# linesOfPoly Array: All connections of a polygon
# parentPoly Vector2Array: Just a reference to the polygon that these lines belong to, so we can exclude it from the check
func findUncrossedLine(linesOfPoly, parentPoly):
	var uncrossedLine = null
	
	for line in linesOfPoly:
		if (line["crossed"] == false):
			if (isPointInsideAnotherObstacle(line["start"], parentPoly) == null && isPointInsideAnotherObstacle(line["end"], parentPoly) == null):
				uncrossedLine = line
				break
	
	return uncrossedLine


# Vector2Array poly: All vertices of a polygon in clockwise direction
func getLinesOfPoly(poly):
	var linesOfPoly = []
	
	for i in range(0, poly.size()):
		var tmpLine = {}
		tmpLine["start"] = poly[i]
		if (i < poly.size()-1):
			tmpLine["end"] = poly[i+1]
		else:
			tmpLine["end"] = poly[0]
		
		tmpLine["crossed"] = false
		tmpLine["intersects"] = []
		
		linesOfPoly.push_back(tmpLine)
	
	return linesOfPoly



# http://gamedev.stackexchange.com/questions/26004/how-to-detect-2d-line-on-line-collision
# does report perfectly parallel lines as intersecting!!!
func doLinesIntersect(oneLine, otherLine):
	var a = oneLine["start"]
	var b = oneLine["end"]
	var c = otherLine["start"]
	var d = otherLine["end"]
	
	var denominator = ((b.x - a.x) * (d.y - c.y)) - ((b.y - a.y) * (d.x - c.x))
	var numerator1 = ((a.y - c.y) * (d.x - c.x)) - ((a.x - c.x) * (d.y - c.y))
	var numerator2 = ((a.y - c.y) * (b.x - a.x)) - ((a.x - c.x) * (b.y - a.y))
	
	# Detect coincident lines (has a problem, read below)
	if (denominator == 0):
		return (numerator1 == 0 && numerator2 == 0)
	
	var r = numerator1 / denominator
	var s = numerator2 / denominator
	
	return ((r >= 0 && r <= 1) && (s >= 0 && s <= 1))


# http://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect
# Returns 1 if the lines intersect, otherwise 0. In addition, if the lines 
# intersect the intersection point may be stored in the floats i_x and i_y.
func getLineIntersection(lineA, lineB):
	var intersectionPoint = Vector2()
	
	var p0_x = lineA["start"].x
	var p0_y = lineA["start"].y
	var p1_x = lineA["end"].x
	var p1_y = lineA["end"].y
	var p2_x = lineB["start"].x
	var p2_y = lineB["start"].y
	var p3_x = lineB["end"].x
	var p3_y = lineB["end"].y
	
	var s1_x = p1_x - p0_x
	var s1_y = p1_y - p0_y
	var s2_x = p3_x - p2_x
	var s2_y = p3_y - p2_y
	
	var s = (-s1_y * (p0_x - p2_x) + s1_x * (p0_y - p2_y)) / (-s2_x * s1_y + s1_x * s2_y);
	var t = ( s2_x * (p0_y - p2_y) - s2_y * (p0_x - p2_x)) / (-s2_x * s1_y + s1_x * s2_y);
	
	if (s >= 0 && s <= 1 && t >= 0 && t <= 1):
		# Collision detected
		intersectionPoint.x = p0_x + (t * s1_x)
		intersectionPoint.y = p0_y + (t * s1_y)
		
		return intersectionPoint
	
	return null; # No collision



func isPointInsideAnotherObstacle(point, parentPoly):
	for poly in levelObstaclePolysStatic:
		if (poly != parentPoly):
			if (isPointInPoly(point, poly)):
				return poly
	
	return null


# http://stackoverflow.com/questions/8721406/how-to-determine-if-a-point-is-inside-a-2d-convex-polygon
# http://www.ecse.rpi.edu/Homepages/wrf/Research/Short_Notes/pnpoly.html
func isPointInPoly(point, poly):
	var i = 0
	var k = poly.size()-1
	var result = false
	
	while i < poly.size():
		if ((poly[i].y > point.y) != (poly[k].y > point.y) && (point.x < (poly[k].x - poly[i].x) * (point.y - poly[i].y) / (poly[k].y-poly[i].y) + poly[i].x)):
			result = !result
		
		k = i
		i += 1
	
	return result

