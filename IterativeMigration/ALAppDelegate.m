/*
 Copyright (c) 2013, Art & Logic
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 The views and conclusions contained in the software and documentation are those
 of the authors and should not be interpreted as representing official policies,
 either expressed or implied, of the FreeBSD Project.
*/

#import "ALAppDelegate.h"

#import "ALIterativeMigrator.h"
#import "Person.h"

@interface ALAppDelegate (/*Private*/)

@property (readonly, strong, nonatomic) NSManagedObjectContext* managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel* managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator* persistentStoreCoordinator;

@end


@implementation ALAppDelegate

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
   // Seed the database
   [self seedDatabase:self.managedObjectContext];

   // Log the person in the database
   [self logPerson:self.managedObjectContext];

   self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
   self.window.backgroundColor = [UIColor whiteColor];
   [self.window makeKeyAndVisible];
   return YES;
}

#pragma mark - Core Data stack

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the
// persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
   if (_managedObjectContext != nil) {
      return _managedObjectContext;
   }
   
   NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
   if (coordinator != nil)
   {
      _managedObjectContext = [[NSManagedObjectContext alloc] init];
      [_managedObjectContext setPersistentStoreCoordinator:coordinator];
   }
   return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
   if (_managedObjectModel != nil)
   {
      return _managedObjectModel;
   }
   NSURL *modelURL = [[NSBundle mainBundle]
                      URLForResource:@"IterativeMigration"
                      withExtension:@"momd"];
   _managedObjectModel = [[NSManagedObjectModel alloc]
                          initWithContentsOfURL:modelURL];
   return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the
// application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
   if (_persistentStoreCoordinator != nil)
   {
      return _persistentStoreCoordinator;
   }

   NSURL* directoryURL = [[[NSFileManager defaultManager]
                           URLsForDirectory:NSDocumentDirectory
                           inDomains:NSUserDomainMask] lastObject];
   NSURL* storeURL =
    [directoryURL URLByAppendingPathComponent:@"IterativeMigration.sqlite"];
   
   
   _persistentStoreCoordinator =
   [[NSPersistentStoreCoordinator alloc]
    initWithManagedObjectModel:[self managedObjectModel]];

   NSError *error = nil;

   // Custom code for iteratively migrating the persistent store.
   // modelNames is an ordered list of all *.mom files in the top level
   // of the main bundle through which the persistent store should be
   // iteratively migrated.
   NSArray* modelNames = @[
      @"IterativeMigration",
      @"IterativeMigration 2",
      @"IterativeMigration 3",
      @"IterativeMigration 4"];
   if (![ALIterativeMigrator iterativeMigrateURL:storeURL
                                          ofType:NSSQLiteStoreType
                                         toModel:[self managedObjectModel]
                               orderedModelNames:modelNames
                                           error:&error])
   {
      NSLog(@"Error migrating to latest model: %@\n %@", error, [error userInfo]);
      abort();
   }

   if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                  configuration:nil
                                                            URL:storeURL
                                                        options:nil
                                                          error:&error])
   {
      NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
      abort();
   }
   
   return _persistentStoreCoordinator;
}

#pragma mark - Core Data testing

- (void)seedDatabase:(NSManagedObjectContext*)managedObjectContext
{
   NSFetchRequest* request = [[NSFetchRequest alloc] init];
   [request setEntity:[NSEntityDescription entityForName:@"Person"
                                  inManagedObjectContext:managedObjectContext]];

   NSArray* result = [managedObjectContext executeFetchRequest:request
                                                         error:NULL];

   if (0 == [result count])
   {
      Person* person = [NSEntityDescription
                        insertNewObjectForEntityForName:@"Person"
                        inManagedObjectContext:managedObjectContext];
      NSArray* attributeNames = [[[person entity] attributesByName] allKeys];

      person.firstName = @"Sally";
      person.lastName = @"Friedrichs";
      if ([attributeNames containsObject:@"nickname"])
      {
         person.nickname = @"Sal";
      }
      
      if ([attributeNames containsObject:@"nameNormalized"])
      {
         person.nameNormalized = @"sally friedrichs";
      }

      if ([attributeNames containsObject:@"birthdate"])
      {
         person.birthdate = [[NSDate alloc] initWithTimeIntervalSince1970:0];
      }

      [self saveContext];
   }
}

- (void)logPerson:(NSManagedObjectContext*)managedObjectContext
{
   NSFetchRequest* request = [[NSFetchRequest alloc] init];
   [request setEntity:[NSEntityDescription entityForName:@"Person"
                                  inManagedObjectContext:managedObjectContext]];
   
   NSArray* result = [managedObjectContext executeFetchRequest:request
                                                         error:NULL];
   if ([result count] > 0)
   {
      Person* person = [result objectAtIndex:0];
      NSArray* attributeNames = [[[person entity] attributesByName] allKeys];

      for (NSString* attributeName in attributeNames)
      {
         NSLog(@"Person %@: %@", attributeName, [person valueForKey:attributeName]);
      }
   }
}

- (void)saveContext
{
   NSError* error = nil;
   NSManagedObjectContext* managedObjectContext = self.managedObjectContext;
   if (nil != managedObjectContext)
   {
      if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error])
      {
         NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
         abort();
      }
   }
}

@end
