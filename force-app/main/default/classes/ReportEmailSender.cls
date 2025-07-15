public class ReportEmailSender {
    
    // Main method to send report via email with automatic batch processing detection
    public static void sendReportToExternalUsers(String reportId, List<String> emailAddresses, String emailSubject, String emailBody) {
        try {
            // Check if report requires batch processing
            if (requiresBatchProcessing(reportId)) {
                // Use batch apex for large reports
                ReportEmailBatch batchJob = new ReportEmailBatch(reportId, emailAddresses, emailSubject, emailBody);
                Database.executeBatch(batchJob, 1); // Process 1 batch at a time
                
                System.debug('Report email started as batch job for report: ' + reportId);
            } else {
                // Use original synchronous method for smaller reports
                sendReportSynchronously(reportId, emailAddresses, emailSubject, emailBody);
            }
            
        } catch (Exception e) {
            System.debug('Error sending report: ' + e.getMessage());
            throw new AuraHandledException('Error sending report: ' + e.getMessage());
        }
    }
    
    // Original synchronous method for smaller reports
    private static void sendReportSynchronously(String reportId, List<String> emailAddresses, String emailSubject, String emailBody) {
        try {
            // Get report details
            Report reportDetails = [SELECT Id, Name, Description FROM Report WHERE Id = :reportId LIMIT 1];
            
            // Run the report
            Reports.reportResults results = Reports.ReportManager.runReport(reportId, true);
            
            // Generate CSV content from report results
            String csvContent = generateCSVFromReport(results);
            
            // Create blob for attachment
            Blob csvBlob = Blob.valueOf(csvContent);
            
            // Send email with CSV attachment and custom body
            sendEmailWithAttachment(emailAddresses, emailSubject, reportDetails.Name, csvBlob, reportDetails.Name + '.csv', emailBody);
            
        } catch (Exception e) {
            System.debug('Error sending report synchronously: ' + e.getMessage());
            throw new AuraHandledException('Error sending report: ' + e.getMessage());
        }
    }
    
    // Method to check if report requires batch processing
    private static Boolean requiresBatchProcessing(String reportId) {
        try {
            // Run a quick check to see if the report has more than 45,000 rows
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
    
    // Backward compatibility method (without custom email body)
    public static void sendReportToExternalUsers(String reportId, List<String> emailAddresses, String emailSubject) {
        sendReportToExternalUsers(reportId, emailAddresses, emailSubject, '');
    }
    
    // Method to force batch processing (for testing or manual override)
    public static void sendReportToExternalUsersBatch(String reportId, List<String> emailAddresses, String emailSubject, String emailBody) {
        try {
            ReportEmailBatch batchJob = new ReportEmailBatch(reportId, emailAddresses, emailSubject, emailBody);
            Database.executeBatch(batchJob, 1);
            
            System.debug('Report email forced to batch processing for report: ' + reportId);
            
        } catch (Exception e) {
            System.debug('Error sending report via batch: ' + e.getMessage());
            throw new AuraHandledException('Error sending report via batch: ' + e.getMessage());
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
    
    // Method to send email with attachment and custom body
    private static void sendEmailWithAttachment(List<String> emailAddresses, String subject, String reportName, Blob attachmentBlob, String attachmentName, String emailBody) {
        // Create email message
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        
        // Set email properties
        email.setToAddresses(emailAddresses);
        email.setSubject(subject);
        
        // Build email body
        String CreateEmailBody = buildCustomEmailBody(reportName, emailBody);
        email.setHtmlBody(CreateEmailBody);
        
        // Create attachment
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(attachmentName);
        attachment.setBody(attachmentBlob);
        attachment.setContentType('text/csv');
        
        // Attach file to email
        email.setFileAttachments(new Messaging.EmailFileAttachment[]{attachment});
        
        // Send email
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
        
        system.debug('Email sent to: ' + String.join(emailAddresses, ', '));
    }
    
    // Method to build custom email body
    private static String buildCustomEmailBody(String reportName, String emailBody) {
        String Body = '<html><body>';
        Body += '<h2>Salesforce Report: ' + reportName + '</h2>';

        if (String.isNotBlank(emailBody)) {
            // Convert plain text to HTML
            String htmlCustomBody = emailBody.replaceAll('\n', '<br/>');
            Body += '<div style="margin: 20px 0;">' + htmlCustomBody + '</div>';
        }

        Body += '<p>Report generated on: ' + DateTime.now().format('MMM dd, yyyy \'at\' HH:mm') + '</p>';
        Body += '</body></html>';

        return Body;
    }
    
    // Updated batch method to send multiple reports
    public static void sendMultipleReports(Map<String, List<String>> reportIdToEmails, String subjectPrefix, String customEmailBody) {
        for (String reportId : reportIdToEmails.keySet()) {
            List<String> emails = reportIdToEmails.get(reportId);
            Report reportDetails = [SELECT Name FROM Report WHERE Id = :reportId LIMIT 1];
            String subject = subjectPrefix + ' - ' + reportDetails.Name;
            
            sendReportToExternalUsers(reportId, emails, subject, customEmailBody);
        }
    }
    
    // Backward compatibility for batch method
    public static void sendMultipleReports(Map<String, List<String>> reportIdToEmails, String subjectPrefix) {
        sendMultipleReports(reportIdToEmails, subjectPrefix, '');
    }
    
    // Scheduled method for automated report sending
    public static void scheduleReportSending() {
        // This can be called from a scheduled job
        // Example: Send weekly reports every Monday at 9 AM
        
        // Define your report configurations
        List<ReportConfig> reportConfigs = getReportConfigurations();
        
        for (ReportConfig config : reportConfigs) {
            sendReportToExternalUsers(config.reportId, config.emailAddresses, config.emailSubject, config.emailBody);
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
            'Weekly Sales Report', // Email subject
            'Please review the attached weekly sales report. Contact us if you have any questions.' // Email body
        ));
        
        return configs;
    }
    
    // Updated inner class for report configuration
    public class ReportConfig {
        public String reportId;
        public List<String> emailAddresses;
        public String emailSubject;
        public String emailBody;
        
        public ReportConfig(String reportId, List<String> emailAddresses, String emailSubject, String emailBody) {
            this.reportId = reportId;
            this.emailAddresses = emailAddresses;
            this.emailSubject = emailSubject;
            this.emailBody = emailBody;
        }
        
        // Backward compatibility constructor
        public ReportConfig(String reportId, List<String> emailAddresses, String emailSubject) {
            this.reportId = reportId;
            this.emailAddresses = emailAddresses;
            this.emailSubject = emailSubject;
            this.emailBody = '';
        }
    }
}