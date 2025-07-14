
// 2. Enhanced Batch Class
public class EnhancedBulkReportEmailSender implements Database.Batchable<Scheduled_Report__c>, Database.Stateful {
    
    private Integer totalProcessed = 0;
    private Integer totalErrors = 0;
    
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id, Report_Id__c, Report_Name__c, Recipients__c, 
                   Schedule_Type__c, Schedule_Time__c, Schedule_Day__c,
                   Last_Sent__c, Next_Send__c
            FROM Scheduled_Report__c
            WHERE Is_Active__c = true 
            AND Next_Send__c <= :DateTime.now()
        ]);
    }
    
    public void execute(Database.BatchableContext context, List<Scheduled_Report__c> scheduledReports) {
        List<Scheduled_Report__c> reportsToUpdate = new List<Scheduled_Report__c>();
        
        for (Scheduled_Report__c sr : scheduledReports) {
            try {
                // Send the report
                sendSingleReport(sr);
                
                // Update last sent and next send times
                sr.Last_Sent__c = DateTime.now();
                sr.Next_Send__c = calculateNextSendTime(sr);
                reportsToUpdate.add(sr);
                
                totalProcessed++;
                
            } catch (Exception e) {
                System.debug('Error sending report ' + sr.Report_Name__c + ': ' + e.getMessage());
                totalErrors++;
            }
        }
        
        if (!reportsToUpdate.isEmpty()) {
            update reportsToUpdate;
        }
    }
    
    public void finish(Database.BatchableContext context) {
        System.debug('Batch completed. Processed: ' + totalProcessed + ', Errors: ' + totalErrors);
    }
    
    private void sendSingleReport(Scheduled_Report__c scheduledReport) {
        try {
            // Get report details
            Report reportDetails = [
                SELECT Id, Name, Description 
                FROM Report 
                WHERE Id = :scheduledReport.Report_Id__c
            ];
            
            // Parse recipients
            List<String> emailAddresses = scheduledReport.Recipients__c.split(',');
            for (Integer i = 0; i < emailAddresses.size(); i++) {
                emailAddresses[i] = emailAddresses[i].trim();
            }
            
            // Run the report
            Reports.reportResults results = Reports.ReportManager.runReport(scheduledReport.Report_Id__c, true);
            
            // Generate CSV content
            String csvContent = generateCSVFromReport(results);
            Blob csvBlob = Blob.valueOf(csvContent);
            
            // Create and send email
            Messaging.SingleEmailMessage email = createEmailWithAttachment(
                emailAddresses,
                'Scheduled Report - ' + reportDetails.Name,
                reportDetails.Name,
                csvBlob,
                reportDetails.Name + '.csv'
            );
            
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
            
        } catch (Exception e) {
            throw new AuraHandledException('Error sending report: ' + e.getMessage());
        }
    }
    
    private DateTime calculateNextSendTime(Scheduled_Report__c sr) {
        DateTime now = DateTime.now();
        DateTime nextSend = DateTime.newInstance(now.date(), sr.Schedule_Time__c);
        
        if (sr.Schedule_Type__c == 'Daily') {
            nextSend = nextSend.addDays(1);
        } else if (sr.Schedule_Type__c == 'Weekly') {
            nextSend = nextSend.addDays(7);
        } else if (sr.Schedule_Type__c == 'Monthly') {
            nextSend = nextSend.addMonths(1);
        }
        
        return nextSend;
    }
    
    private String generateCSVFromReport(Reports.reportResults results) {
        String csvContent = '';
        
        try {
            Reports.ReportMetadata metadata = results.getReportMetadata();
            Reports.ReportFactWithDetails factDetails = (Reports.ReportFactWithDetails)results.getFactMap().get('T!T');
            
            // Build CSV header
            List<String> headers = new List<String>();
            List<String> detailColumns = metadata.getDetailColumns();
            
            for (String columnKey : detailColumns) {
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
                        cellValue = '"' + cellValue.replace('"', '""') + '"';
                        rowValues.add(cellValue);
                    }
                    csvContent += String.join(rowValues, ',') + '\n';
                }
            }
            
        } catch (Exception e) {
            System.debug('Error generating CSV: ' + e.getMessage());
            csvContent = 'Error generating report data: ' + e.getMessage();
        }
        
        return csvContent;
    }
    
    private Messaging.SingleEmailMessage createEmailWithAttachment(
        List<String> emailAddresses,
        String subject,
        String reportName,
        Blob attachmentBlob,
        String attachmentName
    ) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        
        email.setToAddresses(emailAddresses);
        email.setSubject(subject);
        email.setHtmlBody(buildEmailBody(reportName));
        
        // Create attachment
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(attachmentName);
        attachment.setBody(attachmentBlob);
        attachment.setContentType('text/csv');
        
        email.setFileAttachments(new Messaging.EmailFileAttachment[]{attachment});
        
        return email;
    }
    
    private String buildEmailBody(String reportName) {
        String emailBody = '<html><body>';
        emailBody += '<h2>Salesforce Report: ' + reportName + '</h2>';
        emailBody += '<p>Please find the attached report generated from Salesforce.</p>';
        emailBody += '<p>Report generated on: ' + DateTime.now().format('MMM dd, yyyy \'at\' HH:mm') + '</p>';
        emailBody += '<p>If you have any questions about this report, please contact your Salesforce administrator.</p>';
        emailBody += '</body></html>';
        
        return emailBody;
    }
}

