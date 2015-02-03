
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


