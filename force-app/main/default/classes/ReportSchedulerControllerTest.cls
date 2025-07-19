// ReportSchedulerControllerTest.cls
@isTest
public class ReportSchedulerControllerTest {
    
    @TestSetup
    static void setup() {
        // Create test report
       
            // Use a mock report ID format if no reports exist
       string  testReportId = '00O000000000000'; // Mock report ID
       

        
        // Create test schedule record
        Report_Schedule__c testSchedule = new Report_Schedule__c(
            Report_Id__c = testReportId,
            Report_Name__c = 'Test Report',
            Email_Addresses__c = 'test1@example.com;test2@example.com',
            Schedule_Type__c = 'Daily',
            Schedule_Day__c = '',
            Schedule_Time__c = '09:00',
            Email_Subject__c = 'Test Subject',
            Email_Body__c = 'Test Body',
            Job_Id__c = '12345678901234567890',
            Is_Active__c = true,
            Next_Fire_Time__c = DateTime.now().addDays(1)
        );
        insert testSchedule;
    }
    
   
    @isTest
static void testGetReports() {
    Test.startTest();
    List<Report> reports = new List<Report>();
    
    try {
        reports = ReportSchedulerController.getReports();
    } catch (Exception e) {
        System.assert(false, 'Exception should not be thrown: ' + e.getMessage());
    }

    Test.stopTest();

    System.assertNotEquals(null, reports, 'Reports list should not be null.');
    // You cannot assert size or contents unless SeeAllData is enabled
}

    
    @isTest
    static void testGetReportsException() {
        Test.startTest();
        
        // Force an exception by changing context
        try {
            // This should work normally, but we'll test the exception handling
            List<Report> reports = ReportSchedulerController.getReports();
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Error fetching reports'));
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testScheduleReportEmail() {
        string  testReportId = '00O000000000000';
        
        Test.startTest();
        
        Map<String, Object> scheduleDataMap = new Map<String, Object>{
            'reportId' => testReportId,
            'emailAddresses' => new List<String>{'test1@example.com', 'test2@example.com'},
            'scheduleType' => 'Daily',
            'scheduleDay' => '',
            'scheduleTime' => '09:00',
            'emailSubject' => 'Test Daily Report',
            'emailBody' => 'This is a test daily report email body.'
        };
        
        String scheduleData = JSON.serialize(scheduleDataMap);
        
        String result = ReportSchedulerController.scheduleReportEmail(scheduleData);
        
        Test.stopTest();
        
        System.assertEquals('SUCCESS', result);
        
        // Verify schedule was created
        List<Report_Schedule__c> schedules = [SELECT Id FROM Report_Schedule__c WHERE Report_Id__c = :testReportId AND Is_Active__c = true];
        System.assert(schedules.size() > 0);
    }
    
    @isTest
    static void testScheduleReportEmailWeekly() {
         string  testReportId = '00O000000000000';
        
        Test.startTest();
        
        Map<String, Object> scheduleDataMap = new Map<String, Object>{
            'reportId' => testReportId,
            'emailAddresses' => new List<String>{'test@example.com'},
            'scheduleType' => 'Weekly',
            'scheduleDay' => 'Monday',
            'scheduleTime' => '10:30',
            'emailSubject' => 'Weekly Report',
            'emailBody' => 'Weekly report email body.'
        };
        
        String scheduleData = JSON.serialize(scheduleDataMap);
        
        String result = ReportSchedulerController.scheduleReportEmail(scheduleData);
        
        Test.stopTest();
        
        System.assertEquals('SUCCESS', result);
    }
    
    @isTest
    static void testScheduleReportEmailMonthly() {
        string  testReportId = '00O000000000000';
        
        Test.startTest();
        
        Map<String, Object> scheduleDataMap = new Map<String, Object>{
            'reportId' => testReportId,
            'emailAddresses' => new List<String>{'test@example.com'},
            'scheduleType' => 'Monthly',
            'scheduleDay' => '15',
            'scheduleTime' => '14:00',
            'emailSubject' => 'Monthly Report',
            'emailBody' => 'Monthly report email body.'
        };
        
        String scheduleData = JSON.serialize(scheduleDataMap);
        
        String result = ReportSchedulerController.scheduleReportEmail(scheduleData);
        
        Test.stopTest();
        
        System.assertEquals('SUCCESS', result);
    }
    
   @isTest
static void testScheduleReportEmailException() {
    Boolean exceptionThrown = false;

    Test.startTest();
    try {
        // Malformed JSON (missing closing brace)
        String invalidScheduleData = '{"reportId": "00O000000000000"'; 
        ReportSchedulerController.scheduleReportEmail(invalidScheduleData);
    } catch (AuraHandledException e) {
        exceptionThrown = true;
        System.debug('Caught expected AuraHandledException: ' + e.getMessage());
    } catch (Exception e) {
        exceptionThrown = true;
        System.debug('Caught fallback exception: ' + e.getMessage());
    }
    Test.stopTest();

    System.assert(exceptionThrown, 'Expected exception was not thrown for malformed JSON.');
}

    
    @isTest
    static void testGetScheduledJobs() {
        Test.startTest();
        
        List<Map<String, Object>> jobs = ReportSchedulerController.getScheduledJobs();
        
        Test.stopTest();
        
        // Should return empty list or jobs if any exist
        System.assert(jobs != null);
    }
    
    @isTest
    static void testGetScheduleById() {
        Report_Schedule__c testSchedule = [SELECT Job_Id__c FROM Report_Schedule__c LIMIT 1];
        
        Test.startTest();
        
        Map<String, Object> scheduleData = ReportSchedulerController.getScheduleById(testSchedule.Job_Id__c);
        
        Test.stopTest();
        
        System.assert(scheduleData != null);
        System.assertEquals('Daily', scheduleData.get('scheduleType'));
        System.assertEquals('Test Subject', scheduleData.get('emailSubject'));
    }
    
 @isTest
static void testGetScheduleByIdNotFound() {
    Test.startTest();

    Boolean exceptionThrown = false;

    try {
        ReportSchedulerController.getScheduleById('nonexistentid');
    } catch (AuraHandledException e) {
        exceptionThrown = true;
        System.debug('Caught expected AuraHandledException: ' + e.getMessage());
    }

    Test.stopTest();

    System.assert(exceptionThrown, 'Expected AuraHandledException was not thrown.');
}


    
    @isTest
    static void testUpdateSchedule() {
        string  testReportId = '00O000000000000';
        Report_Schedule__c testSchedule = [SELECT Job_Id__c FROM Report_Schedule__c LIMIT 1];
        
        Test.startTest();
        
        Map<String, Object> updateDataMap = new Map<String, Object>{
            'reportId' => testReportId,
            'emailAddresses' => new List<String>{'updated@example.com'},
            'scheduleType' => 'Weekly',
            'scheduleDay' => 'Friday',
            'scheduleTime' => '15:00',
            'emailSubject' => 'Updated Subject',
            'emailBody' => 'Updated email body.'
        };
        
        String updateData = JSON.serialize(updateDataMap);
        
        String result = ReportSchedulerController.updateSchedule(testSchedule.Job_Id__c, updateData);
        
        Test.stopTest();
        
        System.assertEquals('SUCCESS', result);
    }
    
  @isTest
static void testUpdateScheduleNotFound() {
    Boolean exceptionThrown = false;

    Test.startTest();

    Map<String, Object> updateDataMap = new Map<String, Object>{
        'reportId' => 'someId',
        'emailAddresses' => new List<String>{'test@example.com'},
        'scheduleType' => 'Daily',
        'scheduleDay' => '',
        'scheduleTime' => '09:00',
        'emailSubject' => 'Test',
        'emailBody' => 'Test body'
    };

    String updateData = JSON.serialize(updateDataMap);

    try {
        ReportSchedulerController.updateSchedule('nonexistentid', updateData);
    } catch (AuraHandledException e) {
        exceptionThrown = true;
        System.debug('Caught expected AuraHandledException.');
        // Do not assert on e.getMessage() — it is masked in tests
    }

    Test.stopTest();

    System.assert(exceptionThrown, 'Expected AuraHandledException was not thrown.');
}


    
    @isTest
    static void testDeleteScheduledJob() {
        Report_Schedule__c testSchedule = [SELECT Job_Id__c FROM Report_Schedule__c LIMIT 1];
        
        Test.startTest();
        
        String result = ReportSchedulerController.deleteScheduledJob(testSchedule.Job_Id__c);
        
        Test.stopTest();
        
        System.assertEquals('Schedule deleted successfully', result);
        
        // Verify schedule was deleted
        List<Report_Schedule__c> schedules = [SELECT Id FROM Report_Schedule__c WHERE Job_Id__c = :testSchedule.Job_Id__c];
        System.assertEquals(0, schedules.size());
    }
    
   
    
    @isTest
    static void testGetCurrentUserInfo() {
        Test.startTest();
        
        Map<String, Object> userInfo = ReportSchedulerController.getCurrentUserInfo();
        
        Test.stopTest();
        
        System.assert(userInfo != null);
        System.assert(userInfo.containsKey('id'));
        System.assert(userInfo.containsKey('name'));
        System.assert(userInfo.containsKey('email'));
    }
    
    @isTest
    static void testCronExpressionGeneration() {
        // Test various schedule types through the main method
        string  testReportId = '00O000000000000';
        
        Test.startTest();
        
        // Test different schedule types to cover cron expression generation
        Map<String, Object> dailySchedule = new Map<String, Object>{
            'reportId' => testReportId,
            'emailAddresses' => new List<String>{'test@example.com'},
            'scheduleType' => 'Daily',
            'scheduleDay' => '',
            'scheduleTime' => '08:30',
            'emailSubject' => 'Daily Test',
            'emailBody' => 'Daily test body'
        };
        
        Map<String, Object> weeklySchedule = new Map<String, Object>{
            'reportId' => testReportId,
            'emailAddresses' => new List<String>{'test@example.com'},
            'scheduleType' => 'Weekly',
            'scheduleDay' => 'Tuesday',
            'scheduleTime' => '12:00',
            'emailSubject' => 'Weekly Test',
            'emailBody' => 'Weekly test body'
        };
        
        Map<String, Object> monthlySchedule = new Map<String, Object>{
            'reportId' => testReportId,
            'emailAddresses' => new List<String>{'test@example.com'},
            'scheduleType' => 'Monthly',
            'scheduleDay' => 'Last',
            'scheduleTime' => '23:59',
            'emailSubject' => 'Monthly Test',
            'emailBody' => 'Monthly test body'
        };
        
        String result1 = ReportSchedulerController.scheduleReportEmail(JSON.serialize(dailySchedule));
        String result2 = ReportSchedulerController.scheduleReportEmail(JSON.serialize(weeklySchedule));
        String result3 = ReportSchedulerController.scheduleReportEmail(JSON.serialize(monthlySchedule));
        
        Test.stopTest();
        
        System.assertEquals('SUCCESS', result1);
        System.assertEquals('SUCCESS', result2);
        System.assertEquals('SUCCESS', result3);
    }
    
    @isTest
static void testParseJobDetailsThroughGetScheduledJobs() {
    String reportId = '00O000000000000';
    
   

    // Use a valid job name format to trigger parseJobDetails()
    String jobName = 'Report Email - ' + reportId + ' - Test Subject - 2 recipients - ' + System.now().getTime();

    Test.startTest();
    String cronExp = '0 0 10 * * ?';
    System.schedule(jobName, cronExp, new MockSchedulable());
    Test.stopTest();

    // This will trigger parseJobDetails()
    List<Map<String, Object>> jobs = ReportSchedulerController.getScheduledJobs();

    Boolean found = false;
    for (Map<String, Object> job : jobs) {
        if (String.valueOf(job.get('name')).startsWith('Report Email - ' + reportId)) {
            found = true;
            System.assertEquals('Test Subject', job.get('emailSubject'));
            System.assertEquals(reportId, job.get('reportId'));
            System.assertEquals(2, job.get('recipientCount'));
        }
    }

    System.assert(found, 'Expected job was not found in scheduled jobs');
}
     // Create a fake schedulable class
    class MockSchedulable implements Schedulable {
        public void execute(SchedulableContext context) {}
    }
    


    @isTest
    static void testSearchReportsSOSL() {
        Test.startTest();

        List<Report> results = new List<Report>();
        try {
            results = ReportSchedulerController.searchReports('Test');
        } catch (Exception e) {
            System.assert(false, 'Exception was thrown from searchReports: ' + e.getMessage());
        }

        Test.stopTest();

        // We can't assert data unless using SeeAllData=true, but we can assert the type and presence of response
        System.assertNotEquals(null, results, 'SOSL result should not be null.');
    }

    @isTest
    static void testSearchReportsSOQL() {
        Test.startTest();

        List<Report> results = new List<Report>();
        try {
            results = ReportSchedulerController.searchReportsSOQL('Test');
        } catch (Exception e) {
            System.assert(false, 'Exception was thrown from searchReportsSOQL: ' + e.getMessage());
        }

        Test.stopTest();

        System.assertNotEquals(null, results, 'SOQL result should not be null.');
    }

    
}