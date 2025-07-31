public class ReportEmailQueueable implements Queueable, Database.AllowsCallouts {
    Public String reportId;
    public List<String> emailAddresses;
    public String emailSubject;
    public String emailBody;
    public String fileFormat;

     @TestVisible private String testReportName;
    public ReportEmailQueueable(String reportId, List<String> emailAddresses, String emailSubject, String emailBody, String fileFormat) {
        this.reportId = reportId;
        this.emailAddresses = emailAddresses;
        this.emailSubject = emailSubject;
        this.emailBody = emailBody;
        this.fileFormat = fileFormat;
    }

    public void execute(QueueableContext context) {
         Report report;
        if (Test.isRunningTest()) {
           report = (Report) Schema.getGlobalDescribe().get('Report').newSObject();
        report.Id = reportId;
        } else {
            List<Report> reports = [SELECT Id, Name FROM Report WHERE Id = :reportId LIMIT 1];
            report = reports[0];
        }
               
        
        
        try {
            if (fileFormat == 'xlsx') {
            sendAsXlsx(report);
        } else if (fileFormat == 'xls') {
            sendAsXls(report);
        } else if (fileFormat == 'csv') {
            sendAsCsv(report);
        }
        system.debug(fileFormat+'send succesfuly');
        } catch (Exception e) {
            system.debug('Error sending report as ' + fileFormat + ': ' + e.getMessage());
        }
        
    }

    private void sendAsCsv(Report report) {
        try {
            ApexPages.PageReference pageRef = new ApexPages.PageReference('/' + report.Id + '?csv=1&isdtp=p1');
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName(report.Name + '.csv');
            if (!Test.isRunningTest()) {
                attachment.setBody(pageRef.getContent());
            }
            attachment.setContentType('text/csv');

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setUseSignature(false);
            mail.setToAddresses(emailAddresses);
            mail.setSubject(emailSubject);
            mail.setHtmlBody(emailBody);
            mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{attachment});

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        } catch (Exception e) {
            System.debug('Error sending CSV: ' + e.getMessage());
        }
    }

    private void sendAsXls(Report report) {
  
        try{
   
            // Step 1: POST to run the report
      String postEndpoint =URL.getOrgDomainUrl().toExternalForm() + '/services/data/v60.0/analytics/reports/' + report.Id + '/instances';


            HttpRequest postReq = new HttpRequest();
            postReq.setEndpoint(postEndpoint);
            postReq.setMethod('POST');
            postReq.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
            postReq.setHeader('Content-Type', 'application/json');
              
            postReq.setBody('{}');
            Http http = new Http();
            HttpResponse postRes = http.send(postReq);

            if (postRes.getStatusCode() != 200) {
                System.debug('❌ Failed to POST report. Status: ' + postRes.getStatusCode());
                return;
            }

          
            Map<String, Object> postResult = (Map<String, Object>) JSON.deserializeUntyped(postRes.getBody());
            String instanceId = (String) postResult.get('id');
              system.debug('id'+postResult);
            if (String.isBlank(instanceId)) {
                System.debug('❌ No instanceId returned from report POST.');
                return;
            }

            // Step 2: GET Excel with Accept header
            String getEndpoint = URL.getOrgDomainUrl().toExternalForm() +'/services/data/v60.0/analytics/reports/' + report.Id + '?export=1&format=excel&detailsOnly=true';

            HttpRequest getReq = new HttpRequest();
            getReq.setEndpoint(getEndpoint);
            getReq.setMethod('GET');
            getReq.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
             getReq.setHeader('Accept', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
            getReq.setTimeout(120000); 
            HttpResponse getRes = http.send(getReq);

            if (getRes.getStatusCode() == 200) {
                Blob excelBlob = getRes.getBodyAsBlob();

                Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                attachment.setFileName(report.Name + '.xls');
                attachment.setContentType('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
                attachment.setBody(excelBlob);

                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(emailAddresses);
                email.setSubject(emailSubject);
                 email.setHtmlBody(emailBody);
                email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });

             //   Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
                System.debug('✅ Excel report emailed successfully.'+ Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email }));
            } else {
                System.debug('❌ Failed to GET Excel. Status: ' + getRes.getStatusCode() + '\n' + getRes.getBody());
            }
       
        } catch (Exception ex) {
            System.debug('❌ Exception in ExcelReportExportQueueable: ' + ex.getMessage());
        }
    
    }
    

   
     private void sendAsXlsx(Report report) {
      try{
   
            // Step 1: POST to run the report
      String postEndpoint = URL.getOrgDomainUrl().toExternalForm() +'/services/data/v60.0/analytics/reports/' + report.Id + '/instances';


            HttpRequest postReq = new HttpRequest();
            postReq.setEndpoint(postEndpoint);
            postReq.setMethod('POST');
            postReq.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
            postReq.setHeader('Content-Type', 'application/json');
              
            postReq.setBody('{}');
            Http http = new Http();
            HttpResponse postRes = http.send(postReq);

            if (postRes.getStatusCode() != 200) {
                System.debug('❌ Failed to POST report. Status: ' + postRes.getStatusCode());
                return;
            }

          
            Map<String, Object> postResult = (Map<String, Object>) JSON.deserializeUntyped(postRes.getBody());
            String instanceId = (String) postResult.get('id');
              system.debug('id'+postResult);
            if (String.isBlank(instanceId)) {
                System.debug('❌ No instanceId returned from report POST.');
                return;
            }

            // Step 2: GET Excel with Accept header
            String getEndpoint = URL.getOrgDomainUrl().toExternalForm() +'/services/data/v60.0/analytics/reports/' + report.Id + '?export=1&format=excel&detailsOnly=true';

            HttpRequest getReq = new HttpRequest();
            getReq.setEndpoint(getEndpoint);
            getReq.setMethod('GET');
            getReq.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
             getReq.setHeader('Accept', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
            getReq.setTimeout(120000); 
            HttpResponse getRes = http.send(getReq);

            if (getRes.getStatusCode() == 200) {
                Blob excelBlob = getRes.getBodyAsBlob();

                Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                attachment.setFileName(report.Name + '.xlsx');
                attachment.setContentType('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
                attachment.setBody(excelBlob);

                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(emailAddresses);
                email.setSubject(emailSubject);
               email.setHtmlBody(emailBody);
                email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });

             //   Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
                System.debug('✅ Excel report emailed successfully.'+ Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email }));
            } else {
                System.debug('❌ Failed to GET Excel. Status: ' + getRes.getStatusCode() + '\n' + getRes.getBody());
            }
       
        } catch (Exception ex) {
            System.debug('❌ Exception in ExcelReportExportQueueable: ' + ex.getMessage());
        }
    
    
       }

        
    

        
    

   
}