// ReportEmailSchedulable.cls (Updated to use Batch Apex)
public class ReportEmailSchedulable implements Schedulable {
    private String reportId;
    private List<String> emailAddresses;
    private String emailSubject;
    private String emailBody;
    
    // Constructor with email body parameter
    public ReportEmailSchedulable(String reportId, List<String> emailAddresses, String emailSubject, String emailBody) {
        this.reportId = reportId;
        this.emailAddresses = emailAddresses;
        this.emailSubject = emailSubject;
        this.emailBody = emailBody;
    }
    
    // Backward compatibility constructor (without email body)
    public ReportEmailSchedulable(String reportId, List<String> emailAddresses, String emailSubject) {
        this.reportId = reportId;
        this.emailAddresses = emailAddresses;
        this.emailSubject = emailSubject;
        this.emailBody = ''; // Default to empty string
    }
    
    public void execute(SchedulableContext context) {
        try {
            // Check if report has large dataset that requires batch processing
            if (requiresBatchProcessing()) {
                // Use batch apex for large reports
                ReportEmailBatch batchJob = new ReportEmailBatch(reportId, emailAddresses, emailSubject, emailBody);
                Database.executeBatch(batchJob, 1); // Process 1 batch at a time to avoid limits
                
                System.debug('Scheduled report email started as batch job for report: ' + reportId);
            } else {
                // Use original method for smaller reports
                ReportEmailSender.sendReportToExternalUsers(reportId, emailAddresses, emailSubject, emailBody);
                
                System.debug('Scheduled report email sent successfully for report: ' + reportId);
            }
            
        } catch (Exception e) {
            System.debug('Error in scheduled report email: ' + e.getMessage());
            
            // Send error notification to admin
            sendErrorNotificationToAdmin(e.getMessage());
        }
    }
    
    // Method to check if report requires batch processing
    private Boolean requiresBatchProcessing() {
        try {
            // Run a quick check to see if the report has more than 45,000 rows
            // This is a conservative threshold to stay under the 50,000 limit
            Reports.reportResults results = Reports.ReportManager.runReport(reportId, false); // false = don't include details
            Reports.ReportFactWithDetails factDetails = (Reports.ReportFactWithDetails)results.getFactMap().get('T!T');
            
            if (factDetails != null && factDetails.getRows() != null) {
                Integer rowCount = factDetails.getRows().size();
                System.debug('Report row count: ' + rowCount);
                return rowCount > 45000; // Use batch processing for large reports
            }
            
            return false;
            
        } catch (Exception e) {
            System.debug('Error checking report size, defaulting to batch processing: ' + e.getMessage());
            return true; // Default to batch processing if we can't determine size
        }
    }
    
    // Method to send error notifications to admin
    private void sendErrorNotificationToAdmin(String errorMessage) {
        try {
            // Get admin email from custom settings or use a default
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
    
    // Helper method to get admin email
    private String getAdminEmail() {
        // You can implement this to get admin email from:
        // - Custom Settings
        // - Custom Metadata
        // - User record with specific profile/role
        // For now, returning null (no notification)
        return null;
    }
    
    // Helper method to build error email body
    private String buildErrorEmailBody(String errorMessage) {
        String emailBody = '<html><body>';
        emailBody += '<h2>Scheduled Report Email Error</h2>';
        emailBody += '<p><strong>Error occurred while sending scheduled report email</strong></p>';
        emailBody += '<p><strong>Report ID:</strong> ' + reportId + '</p>';
        emailBody += '<p><strong>Email Subject:</strong> ' + emailSubject + '</p>';
        emailBody += '<p><strong>Recipients:</strong> ' + String.join(emailAddresses, ', ') + '</p>';
        emailBody += '<p><strong>Error Message:</strong> ' + errorMessage + '</p>';
        emailBody += '<p><strong>Time:</strong> ' + DateTime.now().format('MMM dd, yyyy \'at\' HH:mm:ss') + '</p>';
        emailBody += '</body></html>';
        
        return emailBody;
    }
}