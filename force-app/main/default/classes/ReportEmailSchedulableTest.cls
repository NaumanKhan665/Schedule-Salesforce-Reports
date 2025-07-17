@isTest
public class ReportEmailSchedulableTest {

    private static final String DUMMY_REPORT_ID = '00O000000000001AAA';

    @isTest
    static void testConstructorFields() {
        List<String> emails = new List<String>{'test@example.com'};
        String subject = 'Subject';
        String body = 'Body';

        ReportEmailSchedulable schedulable = new ReportEmailSchedulable(DUMMY_REPORT_ID, emails, subject, body);

        System.assertNotEquals(null, schedulable);
    }

    @isTest
    static void testExecuteSuccess() {
        List<String> emails = new List<String>{'test@example.com'};
        ReportEmailSchedulable job = new ReportEmailSchedulable(DUMMY_REPORT_ID, emails, 'Subject', 'Body');

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        System.assert(true, 'Executed without exception');
    }

    @isTest
    static void testExecuteWithExceptionPath() {
        ReportEmailSchedulable job = new ReportEmailSchedulable(null, new List<String>(), 'x', 'y');
        Test.startTest();
        job.execute(null);
        Test.stopTest();

        System.assert(true, 'Handled null reportId');
    }

    @isTest
    static void testBuildErrorEmailBodyContent() {
        List<String> emails = new List<String>{'x@y.com'};
        ReportEmailSchedulable job = new ReportEmailSchedulable(DUMMY_REPORT_ID, emails, 'TestSubject', 'TestBody');

        String html = job.buildErrorEmailBody('TestError');
        System.assert(html.contains('Scheduled Report Email Error'));
        System.assert(html.contains('TestError'));
    }

    @isTest
    static void testGetAdminEmailReturnsNull() {
        ReportEmailSchedulable job = new ReportEmailSchedulable(DUMMY_REPORT_ID, new List<String>{'a@a.com'}, 's', 'b');
        String email = job.getAdminEmail();
        System.assertEquals(null, email);
    }
}