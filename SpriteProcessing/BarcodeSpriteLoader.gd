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
func moveWithOriginPoints(targetOffset,targetScale,targetSpeed,targetLayer,movingObject):
	var interpPosition = lerp(movingObject.get("position"), Vector2(targetOffset[0], targetOffset[1]), targetSpeed)
	var interpScale = lerp(movingObject.get("scale"), Vector2(targetScale[0], targetScale[1]), 0.3)
	movingObject.set("position",Vector2(interpPosition[0],interpPosition[1]))
	movingObject.set("scale",Vector2(interpScale[0],interpScale[1]))
	if(movingObject.z_index != targetLayer):
		movingObject.z_index = targetLayer
	return(movingObject.get("position").distance_to(Vector2(targetOffset[0],targetOffset[1])) > 0.2)

#load choose type and variant for a new image or image change
func chooseTypeAndVariant(loadMethodSwitch,acceptableTypes,acceptableVariants,elementOverride,typeOverride,variantFilterDictionary):
	var loadDirectory = "Images/Objects"
	if(loadMethodSwitch == LOBACKGROUND):
		loadDirectory = "Images/Backgrounds"
	var chosenElement = elementOverride
	if(chosenElement == null):
		var allElementsList = getDirectoryContentsList(loadDirectory,true)
		chosenElement = allElementsList[randi() % allElementsList.size()]
	var allTypesList = getDirectoryContentsList(loadDirectory + "/" + chosenElement,true)
	#print(allTypesList)
	#choose type from override, acceptable types list or any available
	var chosenType = typeOverride
	if(chosenType == null):
		if(len(acceptableTypes) == 0):
			chosenType = allTypesList[randi() % allTypesList.size()]
		else:
			chosenType = acceptableTypes[randi() % acceptableTypes.size()]
	#print("chosen type is " + str(chosenType))
	if(str(chosenType) in allTypesList):
		#get all available variants
		var variantImageList = getDirectoryContentsList(loadDirectory + "/" + chosenElement  + "/" + str(chosenType),false)
		#print(variantImageList)
		var chosenVariant = null
		#try to get filtered list of acceptable variants from any previous load of this image 
		#this is stored and retrieved from 'root parent' using rootImage and variantChoiceFilterLists dictionary
		var filteredAcceptableVariants = []
		if(variantFilterDictionary != null):
			if((str(chosenElement) + str(chosenType)) in variantFilterDictionary):
				#get the filter list of variants from the root image dictionary for the chosen combination of element and type
				var variantFilterList = variantFilterDictionary[(str(chosenElement) + str(chosenType))]
				if(len(variantFilterList) > 0 and len(acceptableVariants) > 0):
					for variantNumber in variantFilterList:
						#if the variant for the image animation sequence would fit on the parent, add it to the filtered list
						if(variantNumber in acceptableVariants):
							filteredAcceptableVariants.append(variantNumber)
		#if no filter could be made from matching parent acceptable variants with animation sequence acceptable variants
		#then only use the parent acceptable variants and forget the animation sequence
		if(len(filteredAcceptableVariants) == 0):
			filteredAcceptableVariants = acceptableVariants
		#try to pick a variant from the final list
		if(len(filteredAcceptableVariants) > 0): 
			chosenVariant = str(filteredAcceptableVariants[randi() % filteredAcceptableVariants.size()]) + ".png"
		#if the variant has gone through all filters but is for an image that does not exist,
		#then fall back to picking a random variation from the type
		if(((chosenVariant in variantImageList) == false) and (len(variantImageList) > 0)):
			chosenVariant = str(variantImageList[randi() % variantImageList.size()])
		#print("chosen variant is " + str(chosenVariant))
		if(chosenVariant in variantImageList):
			return([loadDirectory,chosenElement,chosenType,chosenVariant])
		else:
			return null
		

func updateContextImageData(imageInstance,loadDirectory,chosenElement,chosenType,chosenVariant,parentLocation,parentScale,parentLayerOffset,loadMethodSwitch):
	imageInstance.updateImage(loadDirectory + "/" + chosenElement + "/" + str(chosenType) + "/" + chosenVariant)
	imageInstance.name = chosenElement + "_" + str(chosenType) + "_" + chosenVariant.replace(".png","") + "_" + str(randi() % 100)
	imageInstance.offset = Vector2(-imageInstance.originPoint[0],-imageInstance.originPoint[1])
	imageInstance.set("position",Vector2(parentLocation[0],parentLocation[1]))
	imageInstance.set("scale",Vector2(parentScale[0],parentScale[1]))
	imageInstance.z_index = parentLayerOffset
	imageInstance.imageLoadMethod = loadMethodSwitch
	imageInstance.imageLoadElement = chosenElement
	imageInstance.imageLoadType = chosenType
	#send the list of images that this image could switch to for animation sequences to the 'root' object, either self or a parent
	imageInstance.rootImage.variantChoiceFilterLists[str(chosenElement) + str(chosenType)] = imageInstance.acceptableImageVariants
	return imageInstance

#function for creating a new image attached to a parent image
func createNewImageInParent(loadMethodSwitch,parentObject,parentLocation,parentScale,parentLayerOffset,acceptableTypes,acceptableVariants,elementOverride,imageIsRoot):
	var directoryElementTypeVariant = chooseTypeAndVariant(loadMethodSwitch,acceptableTypes,acceptableVariants,elementOverride,null,null)
	if(directoryElementTypeVariant != null):
		var imageInstance = load("SpriteProcessing/ContextImage.tscn").instance()
		parentObject.add_child(imageInstance)
		updateContextImageData(imageInstance,directoryElementTypeVariant[0],directoryElementTypeVariant[1],directoryElementTypeVariant[2],directoryElementTypeVariant[3],parentLocation,parentScale,parentLayerOffset,loadMethodSwitch)
		#if not meant to be the root image, then get the real root image from the parent
		if(imageIsRoot == false):
			imageInstance.rootImage = parentObject.rootImage
		#print(imageInstance.name)
		return imageInstance
		
#function for updating an existing image
func updateElementImage(updateTarget):
	var directoryElementTypeVariant = chooseTypeAndVariant(updateTarget.imageLoadMethod,[],updateTarget.acceptableImageVariants,updateTarget.imageLoadElement,updateTarget.imageLoadType,updateTarget.rootImage.variantChoiceFilterLists)
	if(directoryElementTypeVariant != null):
		updateContextImageData(updateTarget,directoryElementTypeVariant[0],directoryElementTypeVariant[1],directoryElementTypeVariant[2],directoryElementTypeVariant[3],updateTarget.get("position"),updateTarget.get("scale"),updateTarget.z_index,updateTarget.imageLoadMethod)

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
	createNewImageInParent(LOBACKGROUND,self.get_node("Objects"),[0,0],[1,1],0,[0],[0],null,true)
	iterationObjectNode = self.get_node("Objects")
	
#load objects into attachments, following attach type rules
func loadObjectsToAttachments(attachPoint,parentObject,elementOverride,imagesAreOwnRoots):
	if(attachPoint.attachedObject == null):
		if(attachPoint.attachTypeEnum == 0):
			attachPoint.attachedObject = createNewImageInParent(LOOBJECT,parentObject,attachPoint.attachPosition,attachPoint.attachScale,attachPoint.attachLayer,attachPoint.acceptedCategories,attachPoint.acceptedVariants,elementOverride,imagesAreOwnRoots)
		if(attachPoint.attachTypeEnum == 1 and attachPoint.createdObject == false):
			attachPoint.attachedObject = createNewImageInParent(LOOBJECT,parentObject,attachPoint.attachPosition,attachPoint.attachScale,attachPoint.attachLayer,attachPoint.acceptedCategories,attachPoint.acceptedVariants,elementOverride,imagesAreOwnRoots)

#recursively load objects into attachments where applicable
func recursiveObjectLoad(targetObject):
	if(targetObject.attachmentPoints.size() > 0):
		for attachPoint in targetObject.attachmentPoints:
			loadObjectsToAttachments(attachPoint,targetObject,targetObject.imageLoadElement,false)
	if(targetObject.get_child_count() > 0):
		for childObject in targetObject.get_children():
			if(childObject.attachmentPoints.size() > 0):
				print("recursive load")
				recursiveObjectLoad(targetObject)

#movement between attachment points
func attachPointMovement(movingObject,parentObject):
	if(movingObject.targetMovePoint == null):
		var randomNavPointNumber = randi() % parentObject.attachmentPoints.size()
		var randomNavPoint = parentObject.attachmentPoints[randomNavPointNumber]
		if(randomNavPoint.attachTypeEnum == 2 and randomNavPoint.attachedObject == null):
			if((len(movingObject.acceptableTargetMovePoints) == 0) or ((randomNavPointNumber in movingObject.acceptableTargetMovePoints) == true)):
				randomNavPoint.attachedObject = movingObject
				movingObject.targetMovePointPrevious = movingObject.targetMovePoint
				movingObject.targetMovePoint = randomNavPoint
				movingObject.acceptableTargetMovePoints = randomNavPoint.neigborNavPoints
	else:
		#if there is hardly any distance left to move, pick a new navigation target
		if(moveWithOriginPoints(movingObject.targetMovePoint.attachPosition,movingObject.targetMovePoint.attachScale,movingObject.targetMovePoint.navMoveSpeed,movingObject.targetMovePoint.attachLayer,movingObject) == false):
			#chance of not picking a target
			if(randi() % 30 == 1):
				movingObject.targetMovePoint.attachedObject = null
				movingObject.targetMovePoint = null

#process loaded images
func _process(delta):
	#iterate by step through background objects and the objects inside the background objects
	if(iterationObjectNode.get_child_count() > 0):
		var backgroundObject = iterationObjectNode.get_child(layerOneIteration)
		if(backgroundObject.attachmentPoints.size() > 0):
			#load elements in to background, each image will be its own root image
			for attachPoint in backgroundObject.attachmentPoints:
				loadObjectsToAttachments(attachPoint,backgroundObject,null,true)
		#if elements have been loaded in to background, process loaded elements
		if(backgroundObject.get_child_count() > 0):
			var layerTwoObject = backgroundObject.get_child(layerTwoIteration)
			#movement for the layer two object
			attachPointMovement(layerTwoObject,backgroundObject)
			#image changes for the layer two object
			if(randi() % 10 == 1):
				updateElementImage(layerTwoObject)
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
