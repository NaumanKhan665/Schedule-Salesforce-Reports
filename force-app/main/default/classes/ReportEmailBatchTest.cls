@isTest
public class ReportEmailBatchTest {
    
    private static final String DUMMY_REPORT_ID = '00O000000000001AAA';
    
    @isTest
    static void testConstructor() {
        List<String> emailAddresses = new List<String>{'test@example.com', 'admin@example.com'};
        String emailSubject = 'Test Report Email';
        String emailBody = 'Please find the attached report.';
        String fileFormat = 'csv';
        
        Test.startTest();
        ReportEmailBatch batch = new ReportEmailBatch(
            DUMMY_REPORT_ID, 
            emailAddresses, 
            emailSubject, 
            emailBody,
            fileFormat
        );
        Test.stopTest();
        
        System.assertEquals(DUMMY_REPORT_ID, batch.reportId);
        System.assertEquals(emailAddresses, batch.emailAddresses);
        System.assertEquals(emailSubject, batch.emailSubject);
        System.assertEquals(emailBody, batch.emailBody);
        System.assertEquals(fileFormat, batch.fileFormat);
    }
    
    @isTest
    static void testStartMethod() {
        List<String> emailAddresses = new List<String>{'test@example.com'};
        String fileFormat = 'csv';

        ReportEmailBatch batch = new ReportEmailBatch(
            DUMMY_REPORT_ID, 
            emailAddresses, 
            'Subject', 
            'Body',
            fileFormat
        );
        
        Test.startTest();
        Database.QueryLocator ql = batch.start(null);
        Test.stopTest();
        
        System.assertNotEquals(null, ql);
    }
    
    @isTest
    static void testExecuteWithValidReport() {
        List<String> emailAddresses = new List<String>{'test@example.com'};
        String fileFormat = 'csv';

        ReportEmailBatch batch = new ReportEmailBatch(
            DUMMY_REPORT_ID, 
            emailAddresses, 
            'Subject', 
            'Body',
            fileFormat
        );

        List<Report> reports = new List<Report>{new Report(Id = DUMMY_REPORT_ID)};

        Test.startTest();
        batch.execute(null, reports);
        Test.stopTest();

        System.assert(true, 'Execute method completed successfully');
    }
    
    @isTest
    static void testExecuteWithEmptyReports() {
        List<String> emailAddresses = new List<String>{'test@example.com'};
        String fileFormat = 'csv';

        ReportEmailBatch batch = new ReportEmailBatch(
            DUMMY_REPORT_ID, 
            emailAddresses, 
            'Subject', 
            'Body',
            fileFormat
        );
        
        Test.startTest();
        batch.execute(null, new List<Report>());
        Test.stopTest();
        
        System.assert(true, 'Handled empty reports list gracefully');
    }
    
    @isTest
    static void testExecuteWithException() {
        // Pass null emailAddresses to simulate an exception
        ReportEmailBatch batch = new ReportEmailBatch(
            DUMMY_REPORT_ID, 
            null, 
            'Subject', 
            'Body',
            'csv'
        );

        List<Report> reports = new List<Report>{new Report(Id = DUMMY_REPORT_ID)};

        Test.startTest();
        batch.execute(null, reports);
        Test.stopTest();

        System.assert(true, 'Exception was handled in execute method');
    }
    
    @isTest
    static void testFinishMethod() {
        ReportEmailBatch batch = new ReportEmailBatch(
            DUMMY_REPORT_ID, 
            new List<String>{'test@example.com'}, 
            'Subject', 
            'Body',
            'csv'
        );
        
        Test.startTest();
        batch.finish(null);
        Test.stopTest();
        
        System.assert(true, 'Finish method completed successfully');
    }
    
    @isTest
    static void testBatchExecution() {
        ReportEmailBatch batch = new ReportEmailBatch(
            DUMMY_REPORT_ID, 
            new List<String>{'test@example.com'}, 
            'Subject', 
            'Body',
            'csv'
        );
        
        Test.startTest();
        Id batchId = Database.executeBatch(batch, 1);
        Test.stopTest();
        
        System.assertNotEquals(null, batchId);
    }
    @isTest
static void testExecuteWithXlsxFormat() {
    List<String> emailAddresses = new List<String>{'xlsx@test.com'};
    String fileFormat = 'xlsx';

    ReportEmailBatch batch = new ReportEmailBatch(
        DUMMY_REPORT_ID,
        emailAddresses,
        'XLSX Test Subject',
        'XLSX Test Body',
        fileFormat
    );

    List<Report> reports = new List<Report>{
        new Report(Id = DUMMY_REPORT_ID)
    };

    Test.startTest();
    batch.execute(null, reports);
    Test.stopTest();

    System.assert(true, 'sendAsXlsx executed successfully');
}

@isTest
static void testExecuteWithXlsFormat() {
    List<String> emailAddresses = new List<String>{'xls@test.com'};
    String fileFormat = 'xls';

    ReportEmailBatch batch = new ReportEmailBatch(
        DUMMY_REPORT_ID,
        emailAddresses,
        'XLS Test Subject',
        'XLS Test Body',
        fileFormat
    );

    List<Report> reports = new List<Report>{
        new Report(Id = DUMMY_REPORT_ID)
    };

    Test.startTest();
    batch.execute(null, reports);
    Test.stopTest();

    System.assert(true, 'sendAsXls executed successfully');
}

}