/*The MIT License (MIT)

Copyright (c) 2015-2022 Desaware Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

public without sharing class CI_Support implements CI_ScheduledDispatcher.IScheduleDispatched {

	// Unit tests can't run tests, so we use static variables to hold mock ApexTestResult objects
	// that aren't in the database, for testing purposes.

	@testVisible
	private static List<ApexTestResult> mockNewerTestResults;

	@testVisible
	private static List<ApexTestResult> mockOlderTestResults;

	// Get a list of all presumed Apex test classes
	// (See Advanced Apex book for discussion)
	public static Map<ID, ApexClass> getApexTestClasses(String namespace)
	{
		if(namespace=='default') namespace = null;
		Map<ID, ApexClass> results = new Map<ID, ApexClass>(
			[Select ID, Name, NameSpacePrefix from ApexClass 
			where Status='Active' 
			And NameSpacePrefix = :namespace 
			And Name Like '%test%' ]);
		return results;
	}
	
	// Get test results, possibly filtered by date
	// Only pull results from known classes (in case there are any tests in classes that don't have the name test in them)
	public static List<ApexTestResult> getTestResults(DateTime specifyTime, Boolean getAfter, Set<ID> testClassIDs)
	{
		String whereTerm = '';
		if(specifyTime!=null)
		{
			whereTerm = (getAfter)? 'Where TestTimestamp >= :specifyTime And ':
									'Where TestTimestamp < :specifyTime And ';
		}
		whereTerm += ' ApexClassId in :testClassIDs ';
		
		// Reserve SOQL queries for test results - subtract the max result record count from limits, then divide by two as we call this function twice
		Integer reserve = (Limits.getLimitQueryRows() - testClassIDs.size() * 10)/2;
		if(reserve < 10000) reserve = 10000;	// But be sure to allow a generous minimum
		
		String queryTerm = 'Select ApexClassId, MethodName, Outcome, Message, TestTimestamp from ApexTestResult ' + whereTerm + ' Order By TestTimestamp Desc Limit :reserve';
		
		List<ApexTestResult> result = (List<ApexTestResult>)Database.Query(queryTerm);
		
		//result = [Select ApexClassId, ApexClass.Name, MethodName, Outcome, Message, TestTimestamp from ApexTestResult where TestTimestamp <= :specifyTime Order By TestTimestamp Desc];
		
		if(Test.isRunningTest())
		{
			result= (getAfter)? mockNewerTestResults :mockOlderTestResults;
			if(result==null) result = new List<ApexTestResult>();
		}
		return result;
	}
	
	public static void queueTests(Set<ID> testClassIds)
	{
		// Are any currently running?
		List<String> runningStatus = 
			new List<String>{'Holiding','Queued','Preparing','Processing'};
		List<ApexTestQueueItem> currentItems = [Select ApexClassId from ApexTestQueueItem where Status in :runningStatus ];

		// Don't request run of any test current running or scheduled
		for(ApexTestQueueItem runningItem: currentItems)
		{
			testClassIds.remove(runningItem.ApexClassId);
		}
		if(testClassIds.size()==0) return;	// Nothing left to run

		List<ApexTestQueueItem> queueItems = new List<ApexTestQueueItem>();
		for (ID classId: testClassIds) 
		{
			queueItems.add(new ApexTestQueueItem(ApexClassId = classID));
		}
		// Can't schedule tests during a test
		if(!Test.isRunningTest()) insert queueItems;
	}
	
	
	// Main continuous integration operation
	// null or 'default' for the local namespace
	// ignoreTestDelay to always run tests without waiting (normally we only run every 23 hours)
	// 		ignoreTestDelay is currently only for internal integrations - is not exposed in the managed package
	public static void performCI(String namespace, Boolean ignoreTestDelay)
	{
		if(namespace==null) namespace = 'default';
		
		CI_Configuration__c config = CI_ConfigWrapper.loadConfig(namespace);
		// If not yet configured, configure defaults
		if(config==null)
		{
			config = new CI_Configuration__c(
				name=namespace, Last_Test_Request__c=null, 
				Notification_Email__c = UserInfo.getUserEmail(),
				Archive_Days__c = 14,
				Test_Delay__c = 23);
			try
			{
				CI_ConfigWrapper.saveConfig(config);
			}
			catch(Exception ex)
			{
				return;	// Exteremely unlikely
			}
		}	

		// Double use config object as a synchronization object - again, extremely unlikely
		// this code would be run on two threads at once.
		try
		{
			if(!Test.isRunningTest())
				config = [Select name, Last_Test_Request__c, Test_Delay__c,
						Notification_EMail__c, Archive_Days__c 
						from CI_Configuration__c where name=:namespace for update ];
		}
		catch(Exception ex)
		{
			// Failure means another thread is processing, so exit
			return;
		}
		
		// Get the list of test classes
		Map<ID, ApexClass> testClasses = getApexTestClasses(namespace);

		if(config.Last_Test_Request__c == null)
		{	// First time through - just run the tests
			config.Last_Test_Request__c = DateTime.Now();
			queueTests(testClasses.keyset());	// Run all tests
			CI_ConfigWrapper.saveConfig(config);
			return;
		}
		
		// Get results before and after last run
		List<ApexTestResult> oldResults = getTestResults(config.Last_Test_Request__c, false, testClasses.keyset());
		List<ApexTestResult> recentResults = getTestResults(config.Last_Test_Request__c, true, testClasses.keyset());

		// Will hold most recent test result time for each class
		Map<ID, DateTime> latestClassResults = new Map<ID, DateTime>();


		// Get latest result for each test
		// Keyed by classname.methodname
		// First get the most recent results for each test
		Map<String, ApexTestResult> latestRecentResults = new Map<String, ApexTestResult>();
		 
		for(ApexTestResult testResult: recentResults)
		{
			String key = testClasses.get(testResult.ApexClassID).Name + '.' + testResult.MethodName;
			if(!latestRecentResults.containsKey(key)) latestRecentResults.put(key, testResult);
			if(!latestClassResults.containsKey(testResult.ApexClassId)) latestClassResults.put(testResult.ApexClassId, testResult.TestTimestamp);
		}				

		// Now get the most recent results that are prior to the time of the last test run
		Map<String, ApexTestResult> latestOldResults = new Map<String, ApexTestResult>();
		for(ApexTestResult testResult: oldResults)
		{
			String key = testClasses.get(testResult.ApexClassID).Name + '.' + testResult.MethodName;
			if(!latestOldResults.containsKey(key)) latestOldResults.put(key, testResult);
			if(!latestClassResults.containsKey(testResult.ApexClassId)) latestClassResults.put(testResult.ApexClassId, testResult.TestTimestamp);
		}				

		// Report results of tests that previously passed, but
		// failed their most recent test
		
		// Look for tests to run again
		Set<ID> runTestClassIds = testClasses.keyset();
		
		if(!ignoreTestDelay)
		{	// Remove recently run classes
			if(config.Test_Delay__c==null || config.Test_Delay__c<=0) config.Test_Delay__c = 1;
			DateTime earliestToRun = 
				DateTime.Now().addHours(-config.Test_Delay__c.intValue());
			for(ID classId: latestClassResults.keyset())
			{
				if(latestClassResults.get(classId) >= earliestToRun)
					runTestClassIds.Remove(classId);
			}
		}
		
		processTestResults(latestRecentResults, latestoldResults, config);

		// Clean up old test result records - we don't want to clutter the database with infinitely
		// accumulating data
		Integer archiveDays = (config.Archive_Days__c==null || config.Archive_Days__c<1)? 1: config.Archive_Days__c.intValue(); 
		DateTime oldestSummary = DateTime.Now().AddDays(-archiveDays);
		List<CI_TestResult__c> recordsToDelete = [Select ID from CI_TestResult__c where ClassID__c = null And CreatedDate < :oldestSummary Limit 200];
		if(recordsToDelete.size()>0) delete recordsToDelete;
		
		config.Last_Test_Request__c = DateTime.Now();
		CI_ConfigWrapper.saveConfig(config);
		queueTests(runTestClassIds);	// Run all tests

	}
	
	
	// Analyze the test results and detemine if there are any new failures
	public static void processTestResults(
		Map<String, ApexTestResult> latestResults,
		Map<String, ApexTestResult> olderResults,
		CI_Configuration__c config
		)
	{
		// Grab all current test results. There will only be one for each class/method, so we don't
		// have to worry about limits. Only look at the requested namespace
		List<CI_TestResult__c> savedTestRecords = 
			[Select ID, ClassID__c, Test_Name__c, Pass__c, CreatedDate 
			from CI_TestResult__c 
			where ClassID__c!=null AND Namespace__c = :config.Name Order By CreatedDate Desc];

		Map<String, CI_TestResult__c> savedTestRecordMap = 
			new Map<String, CI_TestResult__c>();

		// Build a map of the saved results keyed by the classname.methodname
		for(CI_TestResult__c testResult: savedTestRecords)
		{
			if(!savedTestRecordMap.containsKey(testResult.Test_Name__c))
				savedTestRecordMap.put(testResult.Test_Name__c, testResult);
		}
		
		// Build a true list of test results prior to the last test date
		// CI_TestResult__c objects will not have been created on new test classes, or may have been
		// deleted, so this lets us "fake" it by creating the equivalent CI_TestResult__c objects
		for(string testName: olderResults.keyset())
		{
			if(savedTestRecordMap.containsKey(testName))
			{
				CI_TestResult__c savedItem = savedTestRecordMap.get(testName);
				ApexTestResult olderResult = olderResults.get(testName);
				if(savedItem.CreatedDate < olderResult.TestTimestamp)
				{
					savedTestRecordMap.put(testName, 
						createCITestResult(testName, config.name, olderResult)); 
				}
			}
			
		}
		// Look for new failures
		List<CI_TestResult__c> newErrorList = new List<CI_TestResult__c>();
		
		for(string testName: latestResults.keyset())
		{
			// Create a new result for each test
			ApexTestResult currentResult = latestResults.get(testName);
			CI_TestResult__c newResultRecord = createCITestResult(testName, config.Name, currentResult);
			if(savedTestRecordMap.containsKey(testName))
			{
				// Found a prior result - compare pass/fail - only record new errors
				CI_TestResult__c priorResult = savedTestRecordMap.get(testName);
				if(!newResultRecord.Pass__c && priorResult.Pass__c)
				{
					newErrorList.add(newResultRecord);
				}
			}
			else
			{
				// No prior result - record errors
				if(!newResultRecord.Pass__c) newErrorList.add(newResultRecord);
			}
			savedTestRecordMap.put(testName, newResultRecord);
		}
		
		// Which old records need to be deleted?
		Map<ID, CI_TestResult__c> allExistingRecords = new Map<ID, CI_TestResult__c>(savedTestRecords); 		
		// If the ID exists in the current list, don't delete it
		for(CI_TestResult__c currentRecord: savedTestRecordMap.values())
		{
			allExistingRecords.remove(currentRecord.id);
		}
		delete allExistingRecords.values();	// Delete obsolete records
		upsert savedTestRecordMap.values();	// Upsert current records

		// Create summary record
		String errorMessage = '';
		
		for(CI_TestResult__c testResult: newErrorList)
		{
			if(!testResult.Pass__c)
				errorMessage += testResult.Test_Name__c + ': ' + testResult.Message__c + '\n';
		}
		errorMessage = errorMessage.abbreviate(128000);
		if(String.isBlank(errorMessage)) return;
		CI_TestResult__c newSummary = 
			new CI_TestResult__c(Message__c = errorMessage);
		insert newSummary;
	}
	
	// Create a CI_TestResult__c record from a test result
	private static CI_TestResult__c createCITestResult(string testName, string namespace, ApexTestResult testResult)
	{
		return new CI_TestResult__c(Test_Name__c = testName, 
							ClassID__c = testResult.ApexClassID, 
							Pass__c = testResult.Outcome=='Pass',
							Namespace__c = namespace,
							Message__c = testResult.Message);
	}

	/*
		Supports testing against multiple namespaces - Again, not something that is implemented at this time.
		Primarily useful for integrations into managed packages to test multiple related packages, such
		as a package and extension package 
	*/
	public static void execute(SchedulableContext sc)
	{
		Map<String, CI_Configuration__c> allConfigs = CI_Configuration__c.getAll();
		for(String namespace: allConfigs.keyset())
		{
			performCI(namespace, false);
		}
		// If there's no existing default config, create one.
		
		if(!allConfigs.containsKey('default')) performCI(null, false);	
	}


}