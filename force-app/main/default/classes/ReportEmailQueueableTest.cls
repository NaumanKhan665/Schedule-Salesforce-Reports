@isTest
private class ReportEmailQueueableTest {

    class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getMethod() == 'POST') {
                res.setBody('{"id": "12345"}');
                res.setStatusCode(200);
            } else if (req.getMethod() == 'GET') {
                res.setBodyAsBlob(Blob.valueOf('Excel Dummy Data'));
                res.setStatusCode(200);
            }
            return res;
        }
    }

    @isTest
    static void testCsvFormat() {
        String fakeReportId = '00Oxx0000000000'; // Fake Report Id
        ReportEmailQueueable job = new ReportEmailQueueable(fakeReportId, new List<String>{'csv@example.com'}, 'CSV Subject', 'CSV Body', 'csv');
        job.testReportName = 'Test CSV Report';

        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();
    }

    @isTest
    static void testXlsxFormat() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        String fakeReportId = '00Oxx0000000001';
        ReportEmailQueueable job = new ReportEmailQueueable(fakeReportId, new List<String>{'xlsx@example.com'}, 'XLSX Subject', 'XLSX Body', 'xlsx');
        job.testReportName = 'Test XLSX Report';

        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();
    }

    @isTest
    static void testXlsFormat() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        String fakeReportId = '00Oxx0000000002';
        ReportEmailQueueable job = new ReportEmailQueueable(fakeReportId, new List<String>{'xls@example.com'}, 'XLS Subject', 'XLS Body', 'xls');
        job.testReportName = 'Test XLS Report';

        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();
    }
}