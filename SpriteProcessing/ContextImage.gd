extends Sprite

#what image variants this image can be switched to
var acceptableImageVariants = []
#array of ImageAttachPoints to be read from pixel data for each new image
var attachmentPoints = []
#origin point for image
var originPoint = [0,0]
#target move point
var targetMovePoint = null
#previous target move point
var targetMovePointPrevious = null
#next acceptable target move points
var acceptableTargetMovePoints = []
#image change data
var imageLoadMethod = null
var imageLoadElement = null
var imageLoadType = null

#pixel processing mode enumerators
enum {PPNONE,PPATTACHPOINT,PPORIGINPOINT,PPACCEPTVARIANTS}
#attachment argument mode enumerators
enum {AIMAGETYPES,AIMAGEVARIANTS,ANEIGHBORPOINTS}

#round pixel data for reading rgb as 0 to 100
func roundPixelData(pixelRGB):
	return [stepify(pixelRGB[0],0.01)*100,stepify(pixelRGB[1],0.01)*100,stepify(pixelRGB[2],0.01)*100]

#return true if RGB matches signal string
func checkSignalInPixel(pixelRGB,signalString):
	return(str(pixelRGB) == signalString)

#split hex to array of 3
func splitHexToArray(htmlHEX):
	return([int(htmlHEX.substr(0,2)),int(htmlHEX.substr(2,2)),int(htmlHEX.substr(4,2))])
	
#function to add to array if not already existing
func appendAllHexIfNotExisting(destinationArray,arrayToAppend):
	for arrayItem in arrayToAppend:
		if((arrayItem in destinationArray) == false):
			destinationArray.append(arrayItem)

func updateImage(newImage):
	#clear children
	for markedChild in self.get_children():
		markedChild.queue_free()
		self.remove_child(markedChild)
	#clear attachment point data
	self.attachmentPoints = []
	#load image into node texture from argument
	self.texture = load(newImage) 
	#make locked copy of image data to read pixels
	var readPixelCopy = self.texture.get_data()
	readPixelCopy.lock()
	var readPixelHEX = splitHexToArray(readPixelCopy.get_pixel(0,0).to_html(false))
	#signal for switching to next argument type while in a read mode
	var nextArgumentSignal = "[99, 99, 99]"
	#signal to start or stop reading pixel data
	var dataSignal = "[98, 98, 98]"
	#signal to read in the origin point from a pixel
	var originPointSignal = "[97, 97, 97]"
	#signal to start reading in a single attach point from pixels
	var attachPointSignal = "[96, 96, 96]"
	#signal to start reading in acceptable image variants
	var acceptableVariantsSignal = "[95, 95, 95]"
	if(checkSignalInPixel(readPixelHEX,dataSignal)):
		readPixelHEX = []
		var pixelReadHeight = 0
		var pixelReadWidth = 1
		#how incoming pixels are to be interpreted
		var pixelReadMode = PPNONE
		#arrays for accumulating arguments
		var attachPointArguments = []
		var originPointArguments = []
		var acceptedVariantArguments = []
		#check all pixels until next occurrence of dataSignal
		while(pixelReadHeight < readPixelCopy.get_height() and checkSignalInPixel(readPixelHEX,dataSignal) == false):
			#if there is not currently a pixel read mode, look for a signal to switch to one
			if(pixelReadMode == PPNONE):
				if(checkSignalInPixel(readPixelHEX,attachPointSignal)):
					 pixelReadMode = PPATTACHPOINT
				elif(checkSignalInPixel(readPixelHEX,originPointSignal)):
					 pixelReadMode = PPORIGINPOINT
				elif(checkSignalInPixel(readPixelHEX,acceptableVariantsSignal)):
					 pixelReadMode = PPACCEPTVARIANTS
			else:
				#capture data using current pixel read mode
				#capture origin point data
				if(pixelReadMode == PPORIGINPOINT):
					#second signal indicates end of input and time to gather and process origin point data
					if(checkSignalInPixel(readPixelHEX,originPointSignal)):
						#set origin point from pixel, where R and G are X and Y as a percent of image size
						if(len(originPointArguments) > 0):
							var positionX = round((originPointArguments[0][0] * 0.01)*readPixelCopy.get_width())
							var positionY = round((originPointArguments[0][1] * 0.01)*readPixelCopy.get_height())
							self.originPoint = [positionX,positionY]
						originPointArguments = []
						pixelReadMode = PPNONE
					else:
						originPointArguments.append(readPixelHEX)
				#capture acceptable image variant data
				if(pixelReadMode == PPACCEPTVARIANTS):
					#second signal indicates end of input and time to gather and process origin point data
					if(checkSignalInPixel(readPixelHEX,acceptableVariantsSignal)):
						#read in r g b of any number of pixels as acceptable variants for this sprite to switch to
						if(len(acceptedVariantArguments) > 0):
							var acceptedVariantsList = []
							for acceptedVariantIterator in range(0,len(acceptedVariantArguments)):
								appendAllHexIfNotExisting(acceptedVariantsList,acceptedVariantArguments[acceptedVariantIterator])
							self.acceptableImageVariants = acceptedVariantsList
							acceptedVariantArguments = []
							pixelReadMode = PPNONE
					else:
						acceptedVariantArguments.append(readPixelHEX)
				#capture attach point data
				if(pixelReadMode == PPATTACHPOINT):
					#second signal indicates end of input and time to gather and process attachment point data
					if(checkSignalInPixel(readPixelHEX,attachPointSignal)):
						#create attachment point using currently passed in data, if there is enough
						#data is x and y position and relative image layer in pixel 1, where 50 maps to 0, 49 maps to -1 etc
						#x and y scale and attachment type enumerator is stored in pixel 2
						#[99, 99, 99] acts as a delimiter between three following arbitrary length sets of arguments
						#the first is accepted image types, the second is accepted variants of image type
						#and the third is neigboring navigation points for if this is a navigation attachment point
						if(len(attachPointArguments) > 2):
							#print("got attach point data")
							#position variables
							var positionX = round((attachPointArguments[0][0] * 0.01)*readPixelCopy.get_width())-self.originPoint[0]
							var positionY = round((attachPointArguments[0][1] * 0.01)*readPixelCopy.get_height())-self.originPoint[1]
							#relative layer, where 50 maps to 0
							var relativeLayer = attachPointArguments[0][2] - 50
							#scale variables where 10 in the hex is turned into 1 for normal size
							var scaleX = attachPointArguments[1][0] * 0.1
							var scaleY = attachPointArguments[1][1] * 0.1
							#the type number for this point
							var pointTypeNumber = attachPointArguments[1][2]
							#gather accepted types, variants and nav neighbors for this point
							var acceptedTypesList = []
							var acceptedVariantsList = []
							var navNeighborsList = []
							var attachReadStage = AIMAGETYPES
							for acceptedTypeVariantIterator in range(2,len(attachPointArguments)):
								#read for delimiter and change type, variant or neigbor navigation read mode
								if(checkSignalInPixel(attachPointArguments[acceptedTypeVariantIterator],nextArgumentSignal)):
									attachReadStage += 1
								elif(attachReadStage == AIMAGETYPES):
									appendAllHexIfNotExisting(acceptedTypesList,attachPointArguments[acceptedTypeVariantIterator])
								elif(attachReadStage == AIMAGEVARIANTS):
									appendAllHexIfNotExisting(acceptedVariantsList,attachPointArguments[acceptedTypeVariantIterator])
								elif(attachReadStage == ANEIGHBORPOINTS):
									appendAllHexIfNotExisting(navNeighborsList,attachPointArguments[acceptedTypeVariantIterator])
							#set up point using data read in from pixels
							var newAttachPoint = ImageAttachPoint.new()
							newAttachPoint.setupPoint([positionX, positionY], [scaleX, scaleY], pointTypeNumber, acceptedTypesList, relativeLayer, acceptedVariantsList,navNeighborsList)
							attachmentPoints.append(newAttachPoint)
						attachPointArguments = []
						pixelReadMode = PPNONE
					else:
						attachPointArguments.append(readPixelHEX)
			#read next pixel, get ready to read pixel after, if reached end of row then go to next row
			readPixelHEX = splitHexToArray(readPixelCopy.get_pixel(pixelReadWidth,pixelReadHeight).to_html(false))
			pixelReadWidth += 1
			if(pixelReadWidth >= readPixelCopy.get_width()):
				pixelReadWidth = 0
				pixelReadHeight += 1
