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

/*
	Standard pattern for implementing scheduled Apex so as not to lock updates of other classes
*/

global without sharing class CI_ScheduledDispatcher Implements Schedulable {

	public Interface IScheduleDispatched 
    { 
        void execute(SchedulableContext sc); 
    } 
    
    global void execute(SchedulableContext sc) 
    {
        Type targettype = Type.forName('CI_Support');   
        if(targettype!=null) {
            IScheduleDispatched obj = (IScheduleDispatched)targettype.NewInstance();
            obj.execute(sc);   
        } 
    }
    
    public static String GetSchedulerExpression(Datetime dt) {
        return ('' + dt.second() + ' ' + dt.minute() + ' ' + dt.hour() + ' ' + dt.day() + ' ' + dt.month() + ' ? ' + dt.year());
    }
    
    /*
    	Callable from anonymous Apex to perform immediate validation. Useful after manually running tests
    */
    global static void executeNow()
    {
    	CI_ScheduledDispatcher schedObj = new CI_ScheduledDispatcher();
    	schedObj.execute(null);
    }
    
}