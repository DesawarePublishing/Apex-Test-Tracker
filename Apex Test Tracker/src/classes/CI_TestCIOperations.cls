/*The MIT License (MIT)

Copyright (c) 2015 Desaware Inc.

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
public class CI_TestCIOperations {
    static testMethod void highLevelTest() {

		Test.startTest();
        System.schedule('ci_schedule_test_job', 
	    	CI_ScheduledDispatcher.GetSchedulerExpression(
		    	DateTime.Now().addSeconds(10)), 
	            new CI_ScheduledDispatcher());
        Test.stopTest();
    }

	// Test with actual config created
    static testMethod void highLevelTest2() {
    	String managedPrefix = getManagedPrefix();

		CI_Configuration__c	config = new CI_Configuration__c(
				name= (managedPrefix==null)? 'default': managedPrefix, 
				Last_Test_Request__c=DateTime.now().addHours(-12), 
				Notification_Email__c = UserInfo.getUserEmail(),
				Archive_Days__c = 14,
				Test_Delay__c = 23);
		insert config;
		
		Test.startTest();
        System.schedule('ci_schedule_test_job2', 
	    	CI_ScheduledDispatcher.GetSchedulerExpression(
		    	DateTime.Now().addSeconds(10)), 
	            new CI_ScheduledDispatcher());
        Test.stopTest();
    }    
    
    public static string getManagedPrefix()
    {
		Schema.DescribeSObjectResult objres = CI_TestResult__c.SObjectType.getDescribe();
		string objName = objres.getName();
		if(objName==objres.getLocalName()) return null;
		return objName.left(objName.indexOf('__'));	
    }
}