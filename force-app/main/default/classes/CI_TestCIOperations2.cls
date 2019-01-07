/*The MIT License (MIT)

Copyright (c) 2015-2019 Desaware Inc.

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

@istest
public class CI_TestCIOperations2 {

    static testMethod void testApexResults1() {
	
		String managedPrefix = CI_TestCIOperations.getManagedPrefix();

		// Tell system we've already run tests once, so it will look at results
		CI_Configuration__c	config = new CI_Configuration__c(
				name= (managedPrefix==null)? 'default': managedPrefix, 
				Last_Test_Request__c=DateTime.now().addHours(-12), 
				Notification_Email__c = UserInfo.getUserEmail(),
				Archive_Days__c = 14,
				Test_Delay__c = 23);		
		CI_ConfigWrapper.saveConfig(config);
		
		// Get test class info
		Map<ID, ApexClass> testClasses = CI_Support.getApexTestClasses(managedPrefix);
		
		List<ApexTestResult> newerResults = new List<ApexTestResult>(); 
		List<ApexTestResult> olderResults = new List<ApexTestResult>(); 
		
		// Create new tests only
		for(ApexClass testClass: testClasses.values())
		{
			newerResults.add(
				new ApexTestResult(ApexClassID = testClass.id, 
				methodName='test1', Outcome='Pass', 
				TestTimeStamp = DateTime.Now().addHours(-24)));
		}
		
		CI_Support.mockNewerTestResults = newerResults;
		
		CI_Support.performCI(managedPrefix, false);
		
		List<CI_TestResult__c> savedTestRecords = 
			[Select ID, ClassID__c, Test_Name__c, Pass__c 
			from CI_TestResult__c 
			where ClassID__c in :testClasses.keyset()];

		system.AssertEquals(testclasses.size(), savedTestRecords.size());
    }

    static testMethod void testApexResults2() {
	
		String managedPrefix = CI_TestCIOperations.getManagedPrefix();

		// Tell system we've already run tests once, so it will look at results
		CI_Configuration__c	config = new CI_Configuration__c(
				name= (managedPrefix==null)? 'default': managedPrefix, 
				Last_Test_Request__c=DateTime.now().addHours(-12), 
				Notification_Email__c = UserInfo.getUserEmail(),
				Archive_Days__c = 14,
				Test_Delay__c = 23);		
		CI_ConfigWrapper.saveConfig(config);
		
		// Get test class info
		Map<ID, ApexClass> testClasses = CI_Support.getApexTestClasses(managedPrefix);
		
		List<ApexTestResult> newerResults = new List<ApexTestResult>(); 
		List<ApexTestResult> olderResults = new List<ApexTestResult>(); 
		
		// Create new tests only
		for(ApexClass testClass: testClasses.values())
		{
			newerResults.add(
				new ApexTestResult(ApexClassID = testClass.id, 
				methodName='test1', Outcome='Fail', 
				TestTimeStamp = DateTime.Now().addHours(-12)));
		}
		
		CI_Support.mockNewerTestResults = newerResults;

		// Create new tests only
		for(ApexClass testClass: testClasses.values())
		{
			olderResults.add(
				new ApexTestResult(ApexClassID = testClass.id, 
				methodName='test1', Outcome='Pass',  
				TestTimeStamp = DateTime.Now().addHours(-36)));
		}
		
		CI_Support.mockOlderTestResults = olderResults;

		CI_Support.performCI(managedPrefix, false);
		
		List<CI_TestResult__c> savedTestRecords = 
			[Select ID, ClassID__c, Test_Name__c, Pass__c 
			from CI_TestResult__c 
			where ClassID__c in :testClasses.keyset()];

		system.AssertEquals(testClasses.size(), savedTestRecords.size());

		savedTestRecords = 
			[Select ID, Message__c 
			from CI_TestResult__c 
			where ClassID__c = null];
 
		system.AssertEquals(1, savedTestRecords.size());
		system.Assert(savedTestRecords[0].Message__c !=null);
 
    }

    static testMethod void testApexResults3() {
	
		String managedPrefix = CI_TestCIOperations.getManagedPrefix();

		// Tell system we've already run tests once, so it will look at results
		CI_Configuration__c	config = new CI_Configuration__c(
				name= (managedPrefix==null)? 'default': managedPrefix, 
				Last_Test_Request__c=DateTime.now().addHours(-12), 
				Notification_Email__c = UserInfo.getUserEmail(),
				Archive_Days__c = 14,
				Test_Delay__c = 23);		
		CI_ConfigWrapper.saveConfig(config);
		
		// Get test class info
		Map<ID, ApexClass> testClasses = CI_Support.getApexTestClasses(managedPrefix);
		
		List<ApexTestResult> newerResults = new List<ApexTestResult>(); 
		
		List<ApexTestResult> olderResults = new List<ApexTestResult>(); 
		
		// Create new tests only
		for(ApexClass testClass: testClasses.values())
		{
			olderResults.add(
				new ApexTestResult(ApexClassID = testClass.id, 
				methodName='test1', Outcome='Pass',  
				TestTimeStamp = DateTime.Now().addHours(-36)));
		}
		
		CI_Support.mockOlderTestResults = olderResults;

		// This should create initial test records
		CI_Support.performCI(managedPrefix, false);

		// Create new tests only
		for(ApexClass testClass: testClasses.values())
		{
			newerResults.add(
				new ApexTestResult(ApexClassID = testClass.id, 
				methodName='test1', Outcome='Fail', 
				TestTimeStamp = DateTime.Now().addSeconds(1)));
		}
		
		CI_Support.mockOlderTestResults = null;
		CI_Support.mockNewerTestResults = newerResults;

		// This should compare against saved records
		CI_Support.performCI(managedPrefix, false);
		
		List<CI_TestResult__c> savedTestRecords = 
			[Select ID, ClassID__c, Test_Name__c, Pass__c 
			from CI_TestResult__c 
			where ClassID__c in :testClasses.keyset()];

		system.AssertEquals(testClasses.size(), savedTestRecords.size());

		savedTestRecords = 
			[Select ID, Message__c 
			from CI_TestResult__c 
			where ClassID__c = null];
 
		system.AssertEquals(1, savedTestRecords.size());
 
    }
}