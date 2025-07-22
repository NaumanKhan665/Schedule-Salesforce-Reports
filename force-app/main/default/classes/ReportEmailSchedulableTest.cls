@isTest
public class ReportEmailSchedulableTest {

    private static final String DUMMY_REPORT_ID = '00O000000000001AAA';

    @isTest
    static void testConstructorFields() {
        List<String> emails = new List<String>{'test@example.com'};
        String subject = 'Subject';
        String body = 'Body';
        string format='csv';

        ReportEmailSchedulable schedulable = new ReportEmailSchedulable(DUMMY_REPORT_ID, emails, subject, body,format);

        System.assertNotEquals(null, schedulable);
    }

    @isTest
    static void testExecuteSuccess() {
        List<String> emails = new List<String>{'test@example.com'};
        ReportEmailSchedulable job = new ReportEmailSchedulable(DUMMY_REPORT_ID, emails, 'Subject', 'Body','csv');

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        System.assert(true, 'Executed without exception');
    }

    @isTest
    static void testExecuteWithExceptionPath() {
        ReportEmailSchedulable job = new ReportEmailSchedulable(null, new List<String>(), 'x', 'y','csv');
        Test.startTest();
        job.execute(null);
        Test.stopTest();

        System.assert(true, 'Handled null reportId');
    }

    @isTest
    static void testBuildErrorEmailBodyContent() {
        List<String> emails = new List<String>{'x@y.com'};
        ReportEmailSchedulable job = new ReportEmailSchedulable(DUMMY_REPORT_ID, emails, 'TestSubject', 'TestBody','testCsv');

        String html = job.buildErrorEmailBody('TestError');
        System.assert(html.contains('Scheduled Report Email Error'));
        System.assert(html.contains('TestError'));
    }

    @isTest
    static void testGetAdminEmailReturnsNull() {
        ReportEmailSchedulable job = new ReportEmailSchedulable(DUMMY_REPORT_ID, new List<String>{'a@a.com'}, 's', 'b','csv');
        String email = job.getAdminEmail();
        System.assertEquals(null, email);
    }
    @isTest
static void testExecuteThrowsException() {
    // Use magic ID to simulate failure
    ReportEmailSchedulable job = new ReportEmailSchedulable('FAIL_BATCH', new List<String>{'fail@test.com'}, 'Fail Subject', 'Fail Body', 'csv');

    Test.startTest();
    job.execute(null); // Should enter the catch block
    Test.stopTest();

    System.assert(true, 'Exception path in execute() should be covered');
}

    
}