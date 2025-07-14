// Schedulable class for report email sending
public class ReportEmailSchedulable implements Schedulable {
    private String reportId;
    private List<String> emailAddresses;
    private String emailSubject;
    
    public ReportEmailSchedulable(String reportId, List<String> emailAddresses, String emailSubject) {
        this.reportId = reportId;
        this.emailAddresses = emailAddresses;
        this.emailSubject = emailSubject;
    }
    
    public void execute(SchedulableContext context) {
        try {
            // Call your existing ReportEmailSender method
            ReportEmailSender.sendReportToExternalUsers(reportId, emailAddresses, emailSubject);
            
            System.debug('Scheduled report email sent successfully');
            
        } catch (Exception e) {
            System.debug('Error in scheduled report email: ' + e.getMessage());
            
            // Optional: Send error notification to admin
            // You can implement error handling/notification here
        }
    }
}