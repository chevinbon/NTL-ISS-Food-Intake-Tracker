//
//  FoodProductFilter.h
//  ISSFoodIntakeTracker
//
//  Created by duxiaoyang on 7/12/13.
//  Copyright (c) 2013 tc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "SynchronizableModel.h"

@class StringWrapper;

//This represents the filter for filtering food products.
@interface FoodProductFilter : SynchronizableModel

//Represent the time period in which the food product is favorite of the user (i.e. consumed more than two times/week within the time period). The time period is specified in unit of days. Usually its value would be 7 (for past week), or 30(for past month). Null value indicates all times.
@property (nonatomic, strong) NSNumber * favoriteWithinTimePeriod;

//Represent the name of the product. This will be used to do a text LIKE/CONTAINS matching for the food product name.
@property (nonatomic, strong) NSString * name;

//Represent the sort option. Default value should be A_TO_Z.
@property (nonatomic, strong) NSNumber * sortOption;

//Represents the food categories. The categories will be used to do IN matching for the food product category.
@property (nonatomic, strong) NSSet *categories;

//Represents the food origins. The origins will be used to do IN matching for the food product origin.
@property (nonatomic, strong) NSSet *origins;

//Represents whether food product is adhoc only or not
@property (nonatomic, strong) NSNumber *adhocOnly;

@end

//Auto generated NSSet methods for categories and origins
@interface FoodProductFilter (CoreDataGeneratedAccessors)

//Add category value
- (void)addCategoriesObject:(StringWrapper *)value;

//Remove category value
- (void)removeCategoriesObject:(StringWrapper *)value;

//Add category values
- (void)addCategories:(NSSet *)values;

//Remove category values
- (void)removeCategories:(NSSet *)values;


//Add origin value
- (void)addOriginsObject:(StringWrapper *)value;

//Remove origin value
- (void)removeOriginsObject:(StringWrapper *)value;

//Add origin values
- (void)addOrigins:(NSSet *)values;

//Remove origin values
- (void)removeOrigins:(NSSet *)values;

@end