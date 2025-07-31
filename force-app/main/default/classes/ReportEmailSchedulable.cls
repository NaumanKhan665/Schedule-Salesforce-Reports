public class ReportEmailSchedulable implements Schedulable {
    private String reportId;
    private List<String> emailAddresses;
    private String emailSubject;
    private String emailBody;
   private string fileFormat;
    public ReportEmailSchedulable(String reportId, List<String> emailAddresses, String emailSubject, String emailBody,String fileFormat) {
        this.reportId = reportId;
        this.emailAddresses = emailAddresses;
        this.emailSubject = emailSubject;
        this.emailBody = emailBody;
         this.fileFormat = fileFormat;  
    }

    public void execute(SchedulableContext context) {
        try {
           
             if (Test.isRunningTest() && this.reportId == 'FAIL_BATCH') {
            throw new AuraHandledException('Simulated batch failure'); 

        }
            //Database.executeBatch(new ReportEmailBatch(reportId, emailAddresses, emailSubject, emailBody,fileFormat), 1);
            System.enqueueJob(new ReportEmailQueueable(reportId, emailAddresses, emailSubject, emailBody,fileFormat));
 
            System.debug('Class Run successfulll ');

        } catch (Exception e) {
            System.debug('Error enqueuing report email queueable: ' + e.getMessage());
            sendErrorNotificationToAdmin(e.getMessage());
        }
         try {
            String jobId = context.getTriggerId();

            // Query CronTrigger to get the next fire time
            CronTrigger ct = [SELECT NextFireTime FROM CronTrigger WHERE Id = :jobId LIMIT 1];
String editjobId = jobId.substring(0, 15);
            // Update schedule record
            List<Report_Schedule__c> schedules = [
    SELECT Id 
    FROM Report_Schedule__c 
    WHERE Job_Id__c = :editjobId AND Is_Active__c = TRUE 
    LIMIT 1
];

          if (!schedules.isEmpty()) {
            schedules[0].Next_Fire_Time__c = ct.NextFireTime;
            update schedules;
            System.debug('NextFireTime updated on schedule record.');
        } else {
            System.debug('No matching schedule record found for Job_Id__c: ' + editjobId);
        }
            system.debug('Time'+ schedules[0].Next_Fire_Time__c);
        } catch (Exception e) {
            System.debug('Failed to update next fire time: ' + e.getMessage());
        }
    }

    private void sendErrorNotificationToAdmin(String errorMessage) {
        try {
            String adminEmail = getAdminEmail();
            if (String.isNotBlank(adminEmail)) {
                Messaging.SingleEmailMessage errorEmail = new Messaging.SingleEmailMessage();
                errorEmail.setToAddresses(new String[]{adminEmail});
                errorEmail.setSubject('Scheduled Report Email Error');
                errorEmail.setHtmlBody(buildErrorEmailBody(errorMessage));

                Messaging.sendEmail(new Messaging.SingleEmailMessage[]{errorEmail});
            }
        } catch (Exception e) {
            System.debug('Error sending admin notification: ' + e.getMessage());
        }
    }

    public String getAdminEmail() {
        return null; // Implement via Custom Metadata or Settings
    }

    public String buildErrorEmailBody(String errorMessage) {
        return '<html><body>' +
            '<h2>Scheduled Report Email Error</h2>' +
            '<p><strong>Report Id:</strong> ' + reportId + '</p>' +
            '<p><strong>Email Subject:</strong> ' + emailSubject + '</p>' +
            '<p><strong>Recipients:</strong> ' + String.join(emailAddresses, ', ') + '</p>' +
            '<p><strong>Error Message:</strong> ' + errorMessage + '</p>' +
            '<p><strong>Time:</strong> ' + DateTime.now().format('MMM dd, yyyy \'at\' HH:mm:ss') + '</p>' +
            '</body></html>';
    }
}