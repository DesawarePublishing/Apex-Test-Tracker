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
/*
	Configuration is implemented for private use and use in managed packages.
	It's not currently public facing in the managed package (may reimplement later using custom metadata)
*/

public with sharing class CI_ConfigWrapper {

	private static Map<String, CI_Configuration__c> testConfigObjectMap = new Map<String, CI_Configuration__c>();

	public static CI_Configuration__c loadConfig(String namespace)
	{
		if(Test.isRunningTest())
		{
			// On test, a test may have inserted a record or not
			// If it has, use the inserted version going forward
			if(testConfigObjectMap.containsKey(namespace)) 
				return testConfigObjectMap.get(namespace);
			CI_Configuration__c config = CI_Configuration__c.getInstance(namespace);
			if(config!=null) testConfigObjectMap.put(namespace, config);
			return config; 
		}
		else
		{
			return CI_Configuration__c.getInstance(namespace);
		}
	}
	
	public static void saveConfig(CI_Configuration__c configObject)
	{
		if(!Test.isRunningTest()) upsert configObject;
		else 
		{
			testConfigObjectMap.put(configObject.name, configObject);
		}
	}
}