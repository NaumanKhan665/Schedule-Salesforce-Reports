// ReportEmailBatch.cls
public class ReportEmailBatch implements Database.Batchable<String>, Database.Stateful {
    private String reportId;
    private List<String> emailAddresses;
    private String emailSubject;
    private String emailBody;
    private String csvContent = '';
    private String reportName;
    private Integer totalBatches = 0;
    private Integer processedBatches = 0;
    private Boolean hasError = false;
    private String errorMessage = '';
    
    // Constructor with email body parameter
    public ReportEmailBatch(String reportId, List<String> emailAddresses, String emailSubject, String emailBody) {
        this.reportId = reportId;
        this.emailAddresses = emailAddresses;
        this.emailSubject = emailSubject;
        this.emailBody = emailBody;
        system.debug('repoer ID'+this.reportId);
        // Get report name for email
        try {
            List<Report> reports = [SELECT Id, Name FROM Report WHERE Id = :reportId LIMIT 1];
            if (!reports.isEmpty()) {
                this.reportName = reports[0].Name;
            } else {
                this.reportName = 'Unknown Report';
            }
        } catch (Exception e) {
            this.reportName = 'Error Loading Report';
            System.debug('Error fetching report name: ' + e.getMessage());
        }
    }
    
    // Backward compatibility constructor (without email body)
    public ReportEmailBatch(String reportId, List<String> emailAddresses, String emailSubject) {
        this(reportId, emailAddresses, emailSubject, '');
    }
    
    // Start method - returns an iterable for batch processing
    public Iterable<String> start(Database.BatchableContext context) {
        try {
            // Run the report to get metadata and total row count
            Reports.reportResults results = Reports.ReportManager.runReport(reportId, true);
            Reports.ReportMetadata metadata = results.getReportMetadata();
            
            // Build CSV header
            List<String> headers = new List<String>();
            List<String> detailColumns = metadata.getDetailColumns();
            
            for (String columnKey : detailColumns) {
                String columnLabel = columnKey.replace('_', ' ').replace('.', ' ');
                headers.add('"' + columnLabel + '"');
            }
            csvContent = String.join(headers, ',') + '\n';
            
            // Get total row count to determine batch size
            Reports.ReportFactWithDetails factDetails = (Reports.ReportFactWithDetails)results.getFactMap().get('T!T');
            Integer totalRows = 0;
            if (factDetails != null && factDetails.getRows() != null) {
                totalRows = factDetails.getRows().size();
            }
            
            // Calculate number of batches needed (process 10,000 rows per batch)
            Integer batchSize = 10000;
            totalBatches = (totalRows + batchSize - 1) / batchSize; // Ceiling division
            
            // Create batch identifiers
            List<String> batchIds = new List<String>();
            for (Integer i = 0; i < totalBatches; i++) {
                batchIds.add(String.valueOf(i));
            }
            
            System.debug('Total rows: ' + totalRows + ', Total batches: ' + totalBatches);
            return batchIds;
            
        } catch (Exception e) {
            hasError = true;
            errorMessage = e.getMessage();
            System.debug('Error in start method: ' + e.getMessage());
            return new List<String>(); // Return empty list to prevent further processing
        }
    }
    
    // Execute method - processes each batch
    public void execute(Database.BatchableContext context, List<String> batchIds) {
        try {
            for (String batchId : batchIds) {
                Integer batchIndex = Integer.valueOf(batchId);
                String batchCsvContent = processBatch(batchIndex);
                csvContent += batchCsvContent;
                processedBatches++;
                
                System.debug('Processed batch ' + (batchIndex + 1) + ' of ' + totalBatches);
            }
            
        } catch (Exception e) {
            hasError = true;
            errorMessage = e.getMessage();
            System.debug('Error in execute method: ' + e.getMessage());
        }
    }
    
    // Finish method - sends the email with complete CSV
    public void finish(Database.BatchableContext context) {
        try {
            if (hasError) {
                System.debug('Batch processing completed with errors: ' + errorMessage);
                sendErrorNotificationToAdmin(errorMessage);
                return;
            }
            
            if (String.isBlank(csvContent) || csvContent.split('\n').size() <= 1) {
                System.debug('No data to send - CSV content is empty');
                return;
            }
            
            // Create blob for attachment
            Blob csvBlob = Blob.valueOf(csvContent);
            
            // Send email with CSV attachment
            sendEmailWithAttachment(emailAddresses, emailSubject, reportName, csvBlob, reportName + '.csv', emailBody);
            
            System.debug('Batch report email sent successfully for report: ' + reportId);
            System.debug('Total batches processed: ' + processedBatches + ' of ' + totalBatches);
            
        } catch (Exception e) {
            System.debug('Error in finish method: ' + e.getMessage());
            sendErrorNotificationToAdmin(e.getMessage());
        }
    }
    
    // Helper method to process individual batch
    private String processBatch(Integer batchIndex) {
        try {
            // Run report with batch-specific parameters
            Reports.reportResults results = Reports.ReportManager.runReport(reportId, true);
            Reports.ReportFactWithDetails factDetails = (Reports.ReportFactWithDetails)results.getFactMap().get('T!T');
            
            String batchCsvContent = '';
            
            if (factDetails != null && factDetails.getRows() != null) {
                List<Reports.ReportDetailRow> allRows = factDetails.getRows();
                
                // Calculate start and end indices for this batch
                Integer startIndex = batchIndex * 10000;
                Integer endIndex = Math.min(startIndex + 10000, allRows.size());
                
                // Process only the rows for this batch
                for (Integer i = startIndex; i < endIndex; i++) {
                    Reports.ReportDetailRow row = allRows[i];
                    List<String> rowValues = new List<String>();
                    
                    for (Reports.ReportDataCell cell : row.getDataCells()) {
                        String cellValue = cell.getLabel() != null ? cell.getLabel() : '';
                        // Escape quotes and wrap in quotes
                        cellValue = '"' + cellValue.replace('"', '""') + '"';
                        rowValues.add(cellValue);
                    }
                    batchCsvContent += String.join(rowValues, ',') + '\n';
                }
            }
            
            return batchCsvContent;
            
        } catch (Exception e) {
            System.debug('Error processing batch ' + batchIndex + ': ' + e.getMessage());
            return '';
        }
    }
    
    // Method to send email with attachment
    private void sendEmailWithAttachment(List<String> emailAddresses, String subject, String reportName, Blob attachmentBlob, String attachmentName, String emailBody) {
        try {
            // Create email message
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            // Set email properties
            email.setToAddresses(emailAddresses);
            email.setSubject(subject);
            
            // Build email body
            String emailBodyContent = buildEmailBody(reportName, emailBody);
            email.setHtmlBody(emailBodyContent);
            
            // Create attachment
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName(attachmentName);
            attachment.setBody(attachmentBlob);
            attachment.setContentType('text/csv');
            
            // Attach file to email
            email.setFileAttachments(new Messaging.EmailFileAttachment[]{attachment});
            
            // Send email
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
            
            System.debug('Email sent to: ' + String.join(emailAddresses, ', '));
            
        } catch (Exception e) {
            System.debug('Error sending email: ' + e.getMessage());
            throw e;
        }
    }
    
    // Method to build email body
    private String buildEmailBody(String reportName, String emailBody) {
        String body = '<html><body>';
        body += '<h2>Salesforce Report: ' + reportName + '</h2>';

        if (String.isNotBlank(emailBody)) {
            // Convert plain text to HTML
            String htmlCustomBody = emailBody.replaceAll('\n', '<br/>');
            body += '<div style="margin: 20px 0;">' + htmlCustomBody + '</div>';
        }

        body += '<p>Report generated on: ' + DateTime.now().format('MMM dd, yyyy \'at\' HH:mm') + '</p>';
        
        body += '</body></html>';

        return body;
    }
    
    // Method to send error notifications to admin
    private void sendErrorNotificationToAdmin(String errorMessage) {
        try {
            // Get admin email from custom settings or use a default
            String adminEmail = getAdminEmail();
            
            if (String.isNotBlank(adminEmail)) {
                Messaging.SingleEmailMessage errorEmail = new Messaging.SingleEmailMessage();
                errorEmail.setToAddresses(new String[]{adminEmail});
                errorEmail.setSubject('Batch Report Email Error');
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
        emailBody += '<h2>Batch Report Email Error</h2>';
        emailBody += '<p><strong>Error occurred while processing batch report email</strong></p>';
        emailBody += '<p><strong>Report ID:</strong> ' + reportId + '</p>';
        emailBody += '<p><strong>Report Name:</strong> ' + reportName + '</p>';
        emailBody += '<p><strong>Email Subject:</strong> ' + emailSubject + '</p>';
        emailBody += '<p><strong>Recipients:</strong> ' + String.join(emailAddresses, ', ') + '</p>';
        emailBody += '<p><strong>Batches Processed:</strong> ' + processedBatches + ' of ' + totalBatches + '</p>';
        emailBody += '<p><strong>Error Message:</strong> ' + errorMessage + '</p>';
        emailBody += '<p><strong>Time:</strong> ' + DateTime.now().format('MMM dd, yyyy \'at\' HH:mm:ss') + '</p>';
        emailBody += '</body></html>';
        
        return emailBody;
    }
}