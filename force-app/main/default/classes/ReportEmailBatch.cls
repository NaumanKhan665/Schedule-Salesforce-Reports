public class ReportEmailBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {

    public String reportId;
    public List<String> emailAddresses;
    public String emailSubject;
    public String emailBody;

    public ReportEmailBatch(String reportId, List<String> emailAddresses, String emailSubject, String emailBody) {
        this.reportId = reportId;
        this.emailAddresses = emailAddresses;
        this.emailSubject = emailSubject;
        this.emailBody = emailBody;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // We're using the report Id to get a single record for batching
        return Database.getQueryLocator([
            SELECT Id, Name
            FROM Report
            WHERE Id = :reportId
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Report> reports) {
        try {
            if (reports.isEmpty()) {
                System.debug('No report found with Id: ' + reportId);
                return;
            }

            Report report = reports[0];
            List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
            ApexPages.PageReference pageRef = new ApexPages.PageReference('/' + report.Id + '?csv=1&isdtp=p1');

            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName(report.Name + '.csv');

            if (!Test.isRunningTest()) {
                attachment.setBody(pageRef.getContent());  // This is the callout
            }

            attachment.setContentType('text/csv');
            attachments.add(attachment);

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setUseSignature(false);
            mail.setToAddresses(emailAddresses);
            mail.setSubject(emailSubject);
            mail.setHtmlBody(emailBody);
            mail.setFileAttachments(attachments);

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            system.debug('Email sent Succesfuuly');

        } catch (Exception e) {
            System.debug('Error during report email batch: ' + e.getMessage());
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Optionally notify success/failure
    }
}
