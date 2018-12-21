<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <alerts>
        <fullName>TestTracker_Notification_on_Default_NS</fullName>
        <description>Apex Test Tracker Notification on Default Namespace</description>
        <protected>false</protected>
        <recipients>
            <type>creator</type>
        </recipients>
        <senderType>CurrentUser</senderType>
        <template>Apex_Test_Tracker/Default_TestTracker_Notification</template>
    </alerts>
    <rules>
        <fullName>Notify on error record</fullName>
        <actions>
            <name>TestTracker_Notification_on_Default_NS</name>
            <type>Alert</type>
        </actions>
        <active>true</active>
        <description>Notifies user when an error record is generated</description>
        <formula>ISBLANK( ClassID__c )</formula>
        <triggerType>onCreateOnly</triggerType>
    </rules>
</Workflow>
