extends Node2D

#element load type enumerators
enum {LOBACKGROUND,LOOBJECT}
#object iteration data
var layerOneIteration = 0
var layerTwoIteration = 0
#node for iteration objects
var iterationObjectNode = null
#random number generator tool
var randomNumberGenerate = null

#get a list of contents in a directory, selecting from folders or png files
func getDirectoryContentsList(checkFolder,getFolderBool):
	var folderTool = Directory.new()
	if(folderTool.open(checkFolder) == OK):
		folderTool.list_dir_begin(true)
		var potentialItemName = folderTool.get_next()
		var finalItemList = []
		while potentialItemName != "":
			if(folderTool.current_is_dir() and getFolderBool == true):
				finalItemList.append(potentialItemName)
			elif(folderTool.current_is_dir() == false and getFolderBool == false and (".png" in potentialItemName) and ((".import" in potentialItemName) == false)):
				finalItemList.append(potentialItemName)
			potentialItemName = folderTool.get_next()
		return finalItemList

#move an object to an attachment point while respecting origin points
func moveWithOriginPoints(targetOffset,targetLayer,movingObject):
	var interpPosition = lerp(movingObject.get("position"), Vector2(targetOffset[0], targetOffset[1]), 0.1)
	movingObject.set("position",Vector2(interpPosition[0],interpPosition[1]))
	if(movingObject.z_index != targetLayer):
		movingObject.z_index = targetLayer
	return(movingObject.get("position").distance_to(Vector2(targetOffset[0],targetOffset[1])) > 0.5)

#load image element matching acceptable type criteria
func loadNewElement(elementType,parentObject,parentLocation,parentScale,parentLayerOffset,acceptableTypes,acceptableVariants,elementOverride):
	var loadDirectory = "Images/Objects"
	if(elementType == LOBACKGROUND):
		loadDirectory = "Images/Backgrounds"
	var chosenElement = elementOverride
	if(chosenElement == null):
		var allElementsList = getDirectoryContentsList(loadDirectory,true)
		chosenElement = allElementsList[randi() % allElementsList.size()]
	var allTypesList = getDirectoryContentsList(loadDirectory + "/" + chosenElement,true)
	#print(allTypesList)
	#if no preferred types specified, accept any
	var chosenType = acceptableTypes[randi() % acceptableTypes.size()]
	if(len(acceptableTypes) == 0):
		chosenType = allTypesList[randi() % allTypesList.size()]
	#print("chosen type is " + str(chosenType))
	if(str(chosenType) in allTypesList):
		var variantImageList = getDirectoryContentsList(loadDirectory + "/" + chosenElement  + "/" + str(chosenType),false)
		#print(variantImageList)
		var chosenVariant = str(acceptableVariants[randi() % acceptableVariants.size()]) + ".png"
		if(len(acceptableVariants) == 0):
			chosenVariant = variantImageList[randi() % variantImageList.size()]
		#print("chosen variant is " + str(chosenVariant))
		if(chosenVariant in variantImageList):
			var imageInstance = load("SpriteProcessing/ContextImage.tscn").instance()
			imageInstance.updateImage(loadDirectory + "/" + chosenElement + "/" + str(chosenType) + "/" + chosenVariant)
			imageInstance.name = chosenElement + "_" + str(chosenType) + "_" + chosenVariant.replace(".png","")
			parentObject.add_child(imageInstance)
			imageInstance.offset = Vector2(-imageInstance.originPoint[0],-imageInstance.originPoint[1])
			imageInstance.set("position",Vector2(parentLocation[0],parentLocation[1]))
			imageInstance.set("scale",Vector2(parentScale[0],parentScale[1]))
			imageInstance.z_index = parentLayerOffset
			print(imageInstance.name)
			return imageInstance

#iterate to a maximum number, returning when a wrap occurs
func wrapIteration(iterator,iterationMax):
	iterator += 1
	var resetWrap = (iterator >= iterationMax)
	if(resetWrap):
		iterator = 0
	return [iterator,resetWrap]

#background setup
func _ready():
	randomize()
	randomNumberGenerate = RandomNumberGenerator.new()
	randomNumberGenerate.randomize()
	loadNewElement(LOBACKGROUND,self.get_node("Objects"),[0,0],[1,1],0,[0],[0],null)
	iterationObjectNode = self.get_node("Objects")
	
#load objects into attachments, following attach type rules
func loadObjectsToAttachments(attachPoint,parentObject):
	if(attachPoint.attachedObject == null):
		if(attachPoint.attachTypeEnum == 0):
			attachPoint.attachedObject = loadNewElement(LOOBJECT,parentObject,attachPoint.attachPosition,attachPoint.attachScale,attachPoint.attachLayer,attachPoint.acceptedCategories,attachPoint.acceptedVariants,null)
		if(attachPoint.attachTypeEnum == 1 and attachPoint.createdObject == false):
			attachPoint.attachedObject = loadNewElement(LOOBJECT,parentObject,attachPoint.attachPosition,attachPoint.attachScale,attachPoint.attachLayer,attachPoint.acceptedCategories,attachPoint.acceptedVariants,null)

#recursively load objects into attachments where applicable
func recursiveObjectLoad(targetObject):
	if(targetObject.attachmentPoints.size() > 0):
		for attachPoint in targetObject.attachmentPoints:
			loadObjectsToAttachments(attachPoint,targetObject)
	if(targetObject.get_child_count() > 0):
		for childObject in targetObject.get_children():
			if(childObject.attachmentPoints.size() > 0):
				print("recursive load")
				recursiveObjectLoad(targetObject)

#process loaded images
func _process(delta):
	#iterate by step through background objects and the objects inside the background objects
	if(iterationObjectNode.get_child_count() > 0):
		var backgroundObject = iterationObjectNode.get_child(layerOneIteration)
		if(backgroundObject.attachmentPoints.size() > 0):
			#load elements in to background
			for attachPoint in backgroundObject.attachmentPoints:
				loadObjectsToAttachments(attachPoint,backgroundObject)
		#if elements have been loaded in to background, process loaded elements
		if(backgroundObject.get_child_count() > 0):
			var layerTwoObject = backgroundObject.get_child(layerTwoIteration)
			#movement for the layer two object
			if(layerTwoObject.targetMovePoint == null):
				var randomNavPointNumber = randi() % backgroundObject.attachmentPoints.size()
				var randomNavPoint = backgroundObject.attachmentPoints[randomNavPointNumber]
				if(randomNavPoint.attachTypeEnum == 2 and randomNavPoint.attachedObject == null):
					if((len(layerTwoObject.acceptableTargetMovePoints) == 0) or ((randomNavPointNumber in layerTwoObject.acceptableTargetMovePoints) == true)):
						randomNavPoint.attachedObject = layerTwoObject
						layerTwoObject.targetMovePointPrevious = layerTwoObject.targetMovePoint
						layerTwoObject.targetMovePoint = randomNavPoint
						layerTwoObject.acceptableTargetMovePoints = randomNavPoint.neigborNavPoints
			else:
				#if there is hardly any distance left to move, pick a new navigation target
				if(moveWithOriginPoints(layerTwoObject.targetMovePoint.attachPosition,layerTwoObject.targetMovePoint.attachLayer,layerTwoObject) == false):
					#but also randomly don't pick a target
					if(randi() % 50 == 1):
						layerTwoObject.targetMovePoint.attachedObject = null
						layerTwoObject.targetMovePoint = null
			#object loading for the layer two object
			recursiveObjectLoad(layerTwoObject)
			#if elements have been loaded in to iteration object, process those elements
			if(layerTwoObject.get_child_count() > 0):
				for imageChild in layerTwoObject.get_children():
					pass
			#iterate and wrap objects in background node iteration, if a wrap occurs, iterate the background
			var layerTwoWrapResult = wrapIteration(layerTwoIteration,backgroundObject.get_child_count())
			layerTwoIteration = layerTwoWrapResult[0]
			if(layerTwoWrapResult[1] == true):
				var layerOneWrapResult = wrapIteration(layerOneIteration,iterationObjectNode.get_child_count())
				layerOneIteration = layerOneWrapResult[0]