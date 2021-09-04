class_name ImageAttachPoint

#where this attach point is located
var attachPosition = [0,0]
#how big objects should be when attached to this point
var attachScale = [1,1]
#relative layer to attach to
var attachLayer = 0
#type enumerator for this attach point
#0 is a point that must have a component attached to it and will add a new one if it becomes unoccupied
#1 is a point that creates one component and then does not create any more if cleared
#2 is a point that components can move to, but does not create components
var attachTypeEnum = 0
#which category numbers can occupy this attach point
var acceptedCategories = []
#which variant numbers can occupy this attach point
var acceptedVariants = []
#which object has been loaded in to this attach point, if any
var attachedObject = null
#record when an object has been created on this point
var createdObject = false
#for navigation attach points, the list of navigation points that can be moved to from this point
var neigborNavPoints = []

func setupPoint(attachXY,attachScaleXY,attachTypeNumber,acceptedCategoriesList,relativeAttachLayer,acceptedVariantsList,neighborNavigationPoints):
	self.attachTypeEnum = attachTypeNumber
	self.acceptedCategories = acceptedCategoriesList
	self.attachPosition = attachXY
	self.attachLayer = relativeAttachLayer
	self.acceptedVariants = acceptedVariantsList
	self.neigborNavPoints = neighborNavigationPoints
	self.attachScale = attachScaleXY
	#print("point type number is " + str(self.attachTypeEnum) + ", categories are " + str(self.acceptedCategories) + ", accepted variants are " + str(self.acceptedVariants) + ", attach layer is " + str(self.attachLayer) + " and position is " + str(self.attachPosition))
