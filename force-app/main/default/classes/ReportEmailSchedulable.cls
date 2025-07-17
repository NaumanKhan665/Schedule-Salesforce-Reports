public class ReportEmailSchedulable implements Schedulable {
    private String reportId;
    private List<String> emailAddresses;
    private String emailSubject;
    private String emailBody;

    public ReportEmailSchedulable(String reportId, List<String> emailAddresses, String emailSubject, String emailBody) {
        this.reportId = reportId;
        this.emailAddresses = emailAddresses;
        this.emailSubject = emailSubject;
        this.emailBody = emailBody;
    }

    public void execute(SchedulableContext context) {
        try {
            Database.executeBatch(new ReportEmailBatch(reportId, emailAddresses, emailSubject, emailBody), 1);
             System.debug('Class Run successfulll ');

        } catch (Exception e) {
            System.debug('Error enqueuing report email queueable: ' + e.getMessage());
            sendErrorNotificationToAdmin(e.getMessage());
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

    private String getAdminEmail() {
        return null; // Implement via Custom Metadata or Settings
    }

    private String buildErrorEmailBody(String errorMessage) {
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
