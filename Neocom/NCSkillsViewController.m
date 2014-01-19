//
//  NCSkillsViewController.m
//  Neocom
//
//  Created by Артем Шиманский on 14.01.14.
//  Copyright (c) 2014 Artem Shimanski. All rights reserved.
//

#import "NCSkillsViewController.h"
#import "NSArray+Neocom.h"
#import "NSNumberFormatter+Neocom.h"
#import "NSString+Neocom.h"
#import "UIActionSheet+Block.h"
#import "NCSkillCell.h"
#import "UIImageView+Neocom.h"

@interface NCSkillsViewControllerData : NSObject<NSCoding>
@property (nonatomic, assign) NCCharacterAttributes* characterAttributes;
@property (nonatomic, assign) EVECharacterSheet* characterSheet;
@property (nonatomic, assign) EVESkillQueue* skillQueue;

@property (nonatomic, strong) NSDictionary* skillQueueSection;
@property (nonatomic, strong) NSArray* allSkillsSections;
@property (nonatomic, strong) NSArray* knownSkillsSections;
@property (nonatomic, strong) NSArray* notKnownSkillsSections;
@property (nonatomic, strong) NSArray* canTrainSkillsSections;

- (void) loadDataInTask:(NCTask*) task;

@end

@interface NCSkillsViewController ()
@property (nonatomic, strong) NCSkillPlan* skillPlan;
@end

@implementation NCSkillsViewControllerData

- (void) loadDataInTask:(NCTask*) task {
	NSMutableDictionary* allSkills = [[NSMutableDictionary alloc] init];
	
	[[EVEDBDatabase sharedDatabase] execSQLRequest:@"SELECT a.* FROM invTypes as a, invGroups as b where a.groupID=b.groupID and b.categoryID=16 and a.published = 1"
									   resultBlock:^(sqlite3_stmt *stmt, BOOL *needsMore) {
										   if ([task isCancelled])
											   *needsMore = NO;
										   NCSkillData* skillData = [[NCSkillData alloc] initWithStatement:stmt];
										   skillData.trainedLevel = -1;
										   allSkills[@(skillData.typeID)] = skillData;
									   }];

	
	NSMutableArray* knownSkills = [NSMutableArray array];
	
	for (EVECharacterSheetSkill* characterSheetSkill in self.characterSheet.skills) {
		NCSkillData* skillData = allSkills[@(characterSheetSkill.typeID)];
		if (skillData) {
			skillData.trainedLevel = characterSheetSkill.level;
			skillData.skillPoints = characterSheetSkill.skillpoints;
			skillData.characterAttributes = self.characterAttributes;
			[knownSkills addObject:skillData];
		}
	}
	if ([task isCancelled])
		return;
	
	[knownSkills sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"typeName" ascending:YES]]];
	
	NSMutableArray* rows = [NSMutableArray new];
	
	for (EVESkillQueueItem *item in self.skillQueue.skillQueue) {
		NCSkillData* skillData = allSkills[@(item.typeID)];
		if (!skillData)
			continue;
		
		skillData.targetLevel = MAX(skillData.targetLevel, item.level);
		if (item.queuePosition == 0)
			skillData.active = YES;
		
		NCSkillData* queueSkillData = [[NCSkillData alloc] initWithInvType:skillData];
		queueSkillData.targetLevel = item.level;
		queueSkillData.currentLevel = item.level - 1;
		queueSkillData.skillPoints = skillData.skillPoints;
		queueSkillData.trainedLevel = skillData.trainedLevel;
		queueSkillData.active = skillData.active;
		queueSkillData.characterAttributes = self.characterAttributes;
		[rows addObject:queueSkillData];
	}

	NSDictionary* skillQueueSection = @{@"title": [NSString stringWithFormat:NSLocalizedString(@"%@ (%d skills in queue)", nil), [NSString stringWithTimeLeft:[self.skillQueue timeLeft]], rows.count],
										@"rows": rows};

	if ([task isCancelled])
		return;
	
	NSMutableArray* knownSkillsSections = [NSMutableArray new];
	
	for (NSArray* skills in [knownSkills arrayGroupedByKey:@"groupID"]) {
		float skillPoints = 0;
		for (NCSkillData* skill in skills) {
			skillPoints += skill.skillPoints;
		}
		NSString* title = [NSString stringWithFormat:NSLocalizedString(@"%@ (%@ skillpoints)", nil),
						   [[skills[0] group] groupName],
						   [NSNumberFormatter neocomLocalizedStringFromNumber:@(skillPoints)]];
		[knownSkillsSections addObject:@{@"title": title, @"rows": skills}];
	}
	[knownSkillsSections sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES]]];
	
	if ([task isCancelled])
		return;
	
	NSMutableArray* allSkillsSections = [NSMutableArray new];
	for (NSArray* skills in [[[allSkills allValues] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"typeName" ascending:YES]]] arrayGroupedByKey:@"groupID"]) {
		float skillPoints = 0;
		for (NCSkillData* skill in skills) {
			skillPoints += skill.skillPoints;
		}
		NSString* title = [NSString stringWithFormat:NSLocalizedString(@"%@ (%@ skillpoints)", nil),
						   [[skills[0] group] groupName],
						   [NSNumberFormatter neocomLocalizedStringFromNumber:@(skillPoints)]];
		[allSkillsSections addObject:@{@"title": title, @"rows": skills}];
	}
	[allSkillsSections sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES]]];
	
	if ([task isCancelled])
		return;
	
	NSPredicate* predicate = nil;
	
	NSMutableArray* canTrainSkillsSection = [NSMutableArray new];
	predicate = [NSPredicate predicateWithFormat:@"trainedLevel < 5 AND trainedLevel >= 0"];
	for (NSDictionary* section in allSkillsSections) {
		NSArray* canTrain = [section[@"rows"] filteredArrayUsingPredicate:predicate];
		if (canTrain.count > 0) {
			[canTrainSkillsSection addObject:@{@"title": section[@"title"], @"rows": canTrain}];
		}
	}
	
	if ([task isCancelled])
		return;
	
	NSMutableArray* notKnownSkillsSections = [NSMutableArray new];
	predicate = [NSPredicate predicateWithFormat:@"trainedLevel < 0"];
	for (NSDictionary* section in allSkillsSections) {
		NSArray* canTrain = [section[@"rows"] filteredArrayUsingPredicate:predicate];
		if (canTrain.count > 0) {
			[notKnownSkillsSections addObject:@{@"title": section[@"title"], @"rows": canTrain}];
		}
	}
	
	self.allSkillsSections = allSkillsSections;
	self.knownSkillsSections = knownSkillsSections;
	self.canTrainSkillsSections = canTrainSkillsSection;
	self.notKnownSkillsSections = notKnownSkillsSections;
	self.skillQueueSection = skillQueueSection;
}

#pragma mark - NSCoding

- (void) encodeWithCoder:(NSCoder *)aCoder {
	if (self.characterSheet)
		[aCoder encodeObject:self.characterSheet forKey:@"characterSheet"];
	if (self.characterAttributes)
		[aCoder encodeObject:self.characterAttributes forKey:@"characterAttributes"];
	if (self.skillQueue)
		[aCoder encodeObject:self.skillQueue forKey:@"skillQueue"];
	
}

- (id) initWithCoder:(NSCoder *)aDecoder {
	if (self = [super init]) {
		self.characterSheet = [aDecoder decodeObjectForKey:@"characterSheet"];
		self.characterAttributes = [aDecoder decodeObjectForKey:@"characterAttributes"];
		self.skillQueue = [aDecoder decodeObjectForKey:@"skillQueue"];
		[self loadDataInTask:nil];
	}
	return self;
}

@end

@implementation NCSkillsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onChangeMode:(id)sender {
	/*if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		switch (self.segmentedControl.selectedSegmentIndex) {
			case 0:
				self.skillsDataSource.mode = SkillsDataSourceModeKnownSkills;
				break;
			case 1:
				self.skillsDataSource.mode = SkillsDataSourceModeAllSkills;
				break;
			case 2:
				self.skillsDataSource.mode = SkillsDataSourceModeNotKnownSkills;
				break;
			case 3:
				self.skillsDataSource.mode = SkillsDataSourceModeCanTrain;
				break;
			default:
				break;
		}
	}
	else*/ {
		[[UIActionSheet actionSheetWithStyle:UIActionSheetStyleBlackOpaque
									   title:nil
						   cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
					  destructiveButtonTitle:nil
						   otherButtonTitles:@[NSLocalizedString(@"Skill Queue", nil), NSLocalizedString(@"My Skills", nil), NSLocalizedString(@"All Skills", nil), NSLocalizedString(@"Not Known", nil), NSLocalizedString(@"Can Train", nil)]
							 completionBlock:^(UIActionSheet *actionSheet, NSInteger selectedButtonIndex) {
								 if (selectedButtonIndex == actionSheet.cancelButtonIndex)
									 return;
								 UIButton* button = (UIButton*) self.navigationItem.titleView;
								 
								 [button setTitle:[actionSheet buttonTitleAtIndex:selectedButtonIndex] forState:UIControlStateNormal];
								 [button setTitle:[actionSheet buttonTitleAtIndex:selectedButtonIndex] forState:UIControlStateHighlighted];
								 switch (selectedButtonIndex) {
									 case 0:
										 self.mode = NCSkillsViewControllerModeTrainingQueue;
										 [self.navigationItem setRightBarButtonItems:@[self.editButtonItem, [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(onAction:)]]
																			animated:YES];
										 break;
									 case 1:
										 self.mode = NCSkillsViewControllerModeKnownSkills;
										 [self.navigationItem setRightBarButtonItems:nil animated:YES];
										 break;
									 case 2:
										 self.mode = NCSkillsViewControllerModeAllSkills;
										 [self.navigationItem setRightBarButtonItems:nil animated:YES];
										 break;
									 case 3:
										 self.mode = NCSkillsViewControllerModeNotKnownSkills;
										 [self.navigationItem setRightBarButtonItems:nil animated:YES];
										 break;
									 case 4:
										 self.mode = NCSkillsViewControllerModeCanTrainSkills;
										 [self.navigationItem setRightBarButtonItems:nil animated:YES];
										 break;
									 default:
										 break;
								 }
								 [self.tableView reloadData];
							 } cancelBlock:nil] showFromRect:[sender bounds] inView:sender animated:YES];
	}
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	NCSkillsViewControllerData* data = self.cacheRecord.data;
	switch (self.mode) {
		case NCSkillsViewControllerModeTrainingQueue:
			return 2.0;
		case NCSkillsViewControllerModeKnownSkills:
			return data.knownSkillsSections.count;
		case NCSkillsViewControllerModeAllSkills:
			return data.allSkillsSections.count;
		case NCSkillsViewControllerModeNotKnownSkills:
			return data.notKnownSkillsSections.count;
		case NCSkillsViewControllerModeCanTrainSkills:
			return data.canTrainSkillsSections.count;
		default:
			return 0;
	}
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NCSkillsViewControllerData* data = self.cacheRecord.data;
	switch (self.mode) {
		case NCSkillsViewControllerModeTrainingQueue:
			return section == 0 ? [data.skillQueueSection[@"rows"] count] : self.skillPlan.trainingQueue.skills.count;
		case NCSkillsViewControllerModeKnownSkills:
			return [data.knownSkillsSections[section][@"rows"] count];
		case NCSkillsViewControllerModeAllSkills:
			return [data.allSkillsSections[section][@"rows"] count];
		case NCSkillsViewControllerModeNotKnownSkills:
			return [data.notKnownSkillsSections[section][@"rows"] count];
		case NCSkillsViewControllerModeCanTrainSkills:
			return [data.canTrainSkillsSections[section][@"rows"] count];
		default:
			return 0;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NCSkillData* row;
	
	NCSkillsViewControllerData* data = self.cacheRecord.data;
	switch (self.mode) {
		case NCSkillsViewControllerModeTrainingQueue:
			row = indexPath.section == 0 ? data.skillQueueSection[@"rows"][indexPath.row] : self.skillPlan.trainingQueue.skills[indexPath.row];
			break;
		case NCSkillsViewControllerModeKnownSkills:
			row = data.knownSkillsSections[indexPath.section][@"rows"][indexPath.row];
			break;
		case NCSkillsViewControllerModeAllSkills:
			row = data.allSkillsSections[indexPath.section][@"rows"][indexPath.row];
			break;
		case NCSkillsViewControllerModeNotKnownSkills:
			row = data.notKnownSkillsSections[indexPath.section][@"rows"][indexPath.row];
			break;
		case NCSkillsViewControllerModeCanTrainSkills:
			row = data.canTrainSkillsSections[indexPath.section][@"rows"][indexPath.row];
			break;
		default:
			break;
	}
	
	
	NCSkillCell* cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
	
	if (row.trainedLevel >= 0) {
		float progress = 0;
		
		if (row.targetLevel == row.trainedLevel + 1) {
			float startSkillPoints = [row skillPointsAtLevel:row.trainedLevel];
			float targetSkillPoints = [row skillPointsAtLevel:row.targetLevel];
			
			progress = (row.skillPoints - startSkillPoints) / (targetSkillPoints - startSkillPoints);
			if (progress > 1.0)
				progress = 1.0;
		}
		
		cell.skillPointsLabel.text = [NSString stringWithFormat:NSLocalizedString(@"SP: %@ (%@ SP/h)", nil),
									  [NSNumberFormatter neocomLocalizedStringFromNumber:@(row.skillPoints)],
									  [NSNumberFormatter neocomLocalizedStringFromNumber:@([data.characterAttributes skillpointsPerSecondForSkill:row] * 3600)]];
		cell.levelLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Level %d", nil), MAX(row.targetLevel, row.trainedLevel)];
		[cell.levelImageView setGIFImageWithContentsOfURL:[[NSBundle mainBundle] URLForResource:[NSString stringWithFormat:@"level_%d%d%d", row.trainedLevel, row.targetLevel, row.active] withExtension:@"gif"]];
		cell.dateLabel.text = row.trainingTime > 0 ? [NSString stringWithFormat:@"%@ (%.0f%%)", [NSString stringWithTimeLeft:row.trainingTime], progress * 100] : nil;
	}
	else {
		cell.skillPointsLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%@ SP/h", nil), [NSNumberFormatter neocomLocalizedStringFromNumber:@([data.characterAttributes skillpointsPerSecondForSkill:row] * 3600)]];
		cell.levelLabel.text = nil;
		cell.levelImageView.image = nil;
		cell.dateLabel.text = nil;
	}
	cell.titleLabel.text = row.skillName;

	return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	NCSkillsViewControllerData* data = self.cacheRecord.data;
	switch (self.mode) {
		case NCSkillsViewControllerModeTrainingQueue:
			if (section == 0)
				return data.skillQueueSection[@"title"];
			else {
				if (self.skillPlan.trainingQueue.skills.count > 0)
					return [NSString stringWithFormat:NSLocalizedString(@"%@ (%d skills)", nil), [NSString stringWithTimeLeft:self.skillPlan.trainingQueue.trainingTime], self.skillPlan.trainingQueue.skills.count];
				else
					return NSLocalizedString(@"Skill plan in empty", nil);
			}
		case NCSkillsViewControllerModeKnownSkills:
			return data.knownSkillsSections[section][@"title"];
		case NCSkillsViewControllerModeAllSkills:
			return data.allSkillsSections[section][@"title"];
		case NCSkillsViewControllerModeNotKnownSkills:
			return data.notKnownSkillsSections[section][@"title"];
		case NCSkillsViewControllerModeCanTrainSkills:
			return data.canTrainSkillsSections[section][@"title"];
		default:
			return 0;
	}
}

#pragma mark - NCTableViewController

- (void) reloadDataWithCachePolicy:(NSURLRequestCachePolicy)cachePolicy {
	__block NSError* error = nil;
	NCAccount* account = [NCAccount currentAccount];
	self.skillPlan = account.activeSkillPlan;
	
	if (!account) {
		[self didFinishLoadData:nil withCacheDate:nil expireDate:nil];
		return;
	}
	
	NCSkillsViewControllerData* data = [NCSkillsViewControllerData new];
	[[self taskManager] addTaskWithIndentifier:NCTaskManagerIdentifierAuto
										 title:NCTaskManagerDefaultTitle
										 block:^(NCTask *task) {
											 [account reloadWithCachePolicy:cachePolicy
																	  error:&error
															progressHandler:^(CGFloat progress, BOOL *stop) {
																task.progress = progress;
																if (task.isCancelled)
																	*stop = YES;
															}];
											 if ([task isCancelled])
												 return;
											 data.characterSheet = account.characterSheet;
											 data.skillQueue = account.skillQueue;
											 data.characterAttributes = account.characterAttributes;
											 [data loadDataInTask:task];
										 }
							 completionHandler:^(NCTask *task) {
								 if (!task.isCancelled) {
									 if (error) {
										 [self didFailLoadDataWithError:error];
									 }
									 else {
										 [self didFinishLoadData:data withCacheDate:[NSDate date] expireDate:[NSDate dateWithTimeIntervalSinceNow:[self defaultCacheExpireTime]]];
									 }
								 }
							 }];
}

- (void) didChangeAccount:(NCAccount *)account {
	[super didChangeAccount:account];
	[self reloadDataWithCachePolicy:NSURLRequestUseProtocolCachePolicy];
}

#pragma mark - Private

@end
