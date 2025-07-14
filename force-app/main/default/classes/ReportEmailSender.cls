public class ReportEmailSender {
    
    // Method to send report via email to external users
    public static void sendReportToExternalUsers(String reportId, List<String> emailAddresses, String emailSubject) {
        try {
            // Get report details
            Report reportDetails = [SELECT Id, Name, Description FROM Report WHERE Id = :reportId LIMIT 1];
            
            // Run the report
            Reports.reportResults results = Reports.ReportManager.runReport(reportId, true);
            
            // Generate CSV content from report results
            String csvContent = generateCSVFromReport(results);
            
            // Create blob for attachment
            Blob csvBlob = Blob.valueOf(csvContent);
            
            // Send email with CSV attachment
            sendEmailWithAttachment(emailAddresses, emailSubject, reportDetails.Name, csvBlob, reportDetails.Name + '.csv');
            
        } catch (Exception e) {
            System.debug('Error sending report: ' + e.getMessage());
            throw new AuraHandledException('Error sending report: ' + e.getMessage());
        }
    }
    
    // Method to generate CSV content from report results
    private static String generateCSVFromReport(Reports.reportResults results) {
        String csvContent = '';
        
        // Get report metadata
        Reports.ReportMetadata metadata = results.getReportMetadata();
        Reports.ReportFactWithDetails factDetails = (Reports.ReportFactWithDetails)results.getFactMap().get('T!T');
        
        // Build CSV header from detail columns
        List<String> headers = new List<String>();
        List<String> detailColumns = metadata.getDetailColumns();
        
        for (String columnKey : detailColumns) {
            // Clean up the column key to make it more readable
            String columnLabel = columnKey.replace('_', ' ').replace('.', ' ');
            headers.add('"' + columnLabel + '"');
        }
        csvContent += String.join(headers, ',') + '\n';
        
        // Build CSV rows
        if (factDetails != null && factDetails.getRows() != null) {
            for (Reports.ReportDetailRow row : factDetails.getRows()) {
                List<String> rowValues = new List<String>();
                for (Reports.ReportDataCell cell : row.getDataCells()) {
                    String cellValue = cell.getLabel() != null ? cell.getLabel() : '';
                    // Escape quotes and wrap in quotes
                    cellValue = '"' + cellValue.replace('"', '""') + '"';
                    rowValues.add(cellValue);
                }
                csvContent += String.join(rowValues, ',') + '\n';
            }
        }
        
        return csvContent;
    }
    
    // Method to send email with attachment
    private static void sendEmailWithAttachment(List<String> emailAddresses, String subject, String reportName, Blob attachmentBlob, String attachmentName) {
        // Create email message
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        
        // Set email properties
        email.setToAddresses(emailAddresses);
        email.setSubject(subject);
        email.setHtmlBody(buildEmailBody(reportName));
        
        // Create attachment
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(attachmentName);
        attachment.setBody(attachmentBlob);
        attachment.setContentType('text/csv');
        
        // Attach file to email
        email.setFileAttachments(new Messaging.EmailFileAttachment[]{attachment});
        
        // Send email
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
        
        system.debug('Email sent');
    }
    
    // Method to build email body
    private static String buildEmailBody(String reportName) {
        String emailBody = '<html><body>';
        emailBody += '<h2>Salesforce Report: ' + reportName + '</h2>';
        emailBody += '<p>Please find the attached report generated from Salesforce.</p>';
        emailBody += '<p>Report generated on: ' + DateTime.now().format('MMM dd, yyyy \'at\' HH:mm') + '</p>';
        emailBody += '<p>If you have any questions about this report, please contact your Salesforce administrator.</p>';
        emailBody += '</body></html>';
        
        return emailBody;
    }
    
    // Batch method to send multiple reports
    public static void sendMultipleReports(Map<String, List<String>> reportIdToEmails, String subjectPrefix) {
        for (String reportId : reportIdToEmails.keySet()) {
            List<String> emails = reportIdToEmails.get(reportId);
            Report reportDetails = [SELECT Name FROM Report WHERE Id = :reportId LIMIT 1];
            String subject = subjectPrefix + ' - ' + reportDetails.Name;
            
            sendReportToExternalUsers(reportId, emails, subject);
        }
    }
    
    // Scheduled method for automated report sending
    public static void scheduleReportSending() {
        // This can be called from a scheduled job
        // Example: Send weekly reports every Monday at 9 AM
        
        // Define your report configurations
        List<ReportConfig> reportConfigs = getReportConfigurations();
        
        for (ReportConfig config : reportConfigs) {
            sendReportToExternalUsers(config.reportId, config.emailAddresses, config.emailSubject);
        }
    }
    
    // Helper method to get report configurations
    private static List<ReportConfig> getReportConfigurations() {
        // You can store this in Custom Settings or Custom Metadata
        List<ReportConfig> configs = new List<ReportConfig>();
        
        // Example configuration - replace with your actual report IDs and emails
        configs.add(new ReportConfig(
            '00O5g000004TJ8w', // Report ID
            new List<String>{'user1@external.com', 'user2@external.com'}, // Email addresses
            'Weekly Sales Report' // Email subject
        ));
        
        return configs;
    }
    
    // Inner class for report configuration
    public class ReportConfig {
        public String reportId;
        public List<String> emailAddresses;
        public String emailSubject;
        
        public ReportConfig(String reportId, List<String> emailAddresses, String emailSubject) {
            this.reportId = reportId;
            this.emailAddresses = emailAddresses;
            this.emailSubject = emailSubject;
        }
    }
}