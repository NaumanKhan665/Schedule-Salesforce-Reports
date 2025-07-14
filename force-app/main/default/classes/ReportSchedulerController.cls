// ReportSchedulerController.cls
public with sharing class ReportSchedulerController {
    
    @AuraEnabled(cacheable=true)
    public static List<Report> getReports() {
        try {
            return [
                SELECT Id, Name, Description, FolderName 
                FROM Report 
                WHERE IsDeleted = false 
                ORDER BY Name ASC 
                LIMIT 1000
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching reports: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String scheduleReportEmail(String scheduleData) {
        try {
            // Parse the schedule data
            Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(scheduleData);
            
            String reportId = (String) dataMap.get('reportId');
            List<Object> emailAddressesObj = (List<Object>) dataMap.get('emailAddresses');
            String scheduleType = (String) dataMap.get('scheduleType');
            String scheduleDay = (String) dataMap.get('scheduleDay');
            String scheduleTime = (String) dataMap.get('scheduleTime');
            String emailSubject = (String) dataMap.get('emailSubject');
            
            // Convert email addresses to List<String>
            List<String> emailAddresses = new List<String>();
            for (Object emailObj : emailAddressesObj) {
                emailAddresses.add((String) emailObj);
            }
            
            // Create or update the scheduled job
            String jobId = createScheduledJob(reportId, emailAddresses, scheduleType, scheduleDay, scheduleTime, emailSubject);
            
            // Store the schedule configuration for future reference
            saveScheduleConfiguration(reportId, emailAddresses, scheduleType, scheduleDay, scheduleTime, emailSubject, jobId);
            
            return 'SUCCESS';
            
        } catch (Exception e) {
            System.debug('Error scheduling report email: ' + e.getMessage());
            throw new AuraHandledException('Error scheduling report email: ' + e.getMessage());
        }
    }
    
    private static String createScheduledJob(String reportId, List<String> emailAddresses, String scheduleType, 
                                           String scheduleDay, String scheduleTime, String emailSubject) {
        
        // Generate cron expression based on schedule type
        String cronExpression = generateCronExpression(scheduleType, scheduleDay, scheduleTime);
        
        // Create the schedulable job
        ReportEmailSchedulable schedulableJob = new ReportEmailSchedulable(reportId, emailAddresses, emailSubject);
        
        // Generate a unique job name that includes the report ID and recipient count
        String jobName = 'Report Email - ' + reportId + ' - ' + emailSubject + ' - ' + emailAddresses.size() + ' recipients - ' + System.now().getTime();
        
        // Schedule the job
        String jobId = System.schedule(jobName, cronExpression, schedulableJob);
        
        return jobId;
    }
    
    private static String generateCronExpression(String scheduleType, String scheduleDay, String scheduleTime) {
        // Parse time (format: HH:mm)
        String[] timeParts = scheduleTime.split(':');
        String hour = timeParts[0];
        String minute = timeParts[1];
        
        String cronExpression = '';
        
        switch on scheduleType {
            when 'Daily' {
                // Daily at specified time
                cronExpression = '0 ' + minute + ' ' + hour + ' * * ?';
            }
            when 'Weekly' {
                // Weekly on specified day at specified time
                String dayOfWeek = getDayOfWeekNumber(scheduleDay);
                cronExpression = '0 ' + minute + ' ' + hour + ' ? * ' + dayOfWeek;
            }
            when 'Monthly' {
                // Monthly on specified day at specified time
                String dayOfMonth = scheduleDay.equals('Last') ? 'L' : scheduleDay;
                cronExpression = '0 ' + minute + ' ' + hour + ' ' + dayOfMonth + ' * ?';
            }
        }
        
        return cronExpression;
    }
    
    private static String getDayOfWeekNumber(String dayName) {
        Map<String, String> dayMap = new Map<String, String>{
            'Sunday' => '1',
            'Monday' => '2',
            'Tuesday' => '3',
            'Wednesday' => '4',
            'Thursday' => '5',
            'Friday' => '6',
            'Saturday' => '7'
        };
        return dayMap.get(dayName);
    }
    
    private static void saveScheduleConfiguration(String reportId, List<String> emailAddresses, String scheduleType, 
                                                String scheduleDay, String scheduleTime, String emailSubject, String jobId) {
        try {
            // You can save this to a custom object for tracking
            // For now, just log the configuration
            System.debug('Schedule Configuration Saved:');
            System.debug('Report ID: ' + reportId);
            System.debug('Email Addresses: ' + String.join(emailAddresses, ', '));
            System.debug('Schedule Type: ' + scheduleType);
            System.debug('Schedule Day: ' + scheduleDay);
            System.debug('Schedule Time: ' + scheduleTime);
            System.debug('Email Subject: ' + emailSubject);
            System.debug('Job ID: ' + jobId);
            
            // Optional: Insert into a custom object to track scheduled jobs
            /*
            Report_Schedule__c scheduleRecord = new Report_Schedule__c(
                Report_Id__c = reportId,
                Email_Addresses__c = String.join(emailAddresses, ';'),
                Schedule_Type__c = scheduleType,
                Schedule_Day__c = scheduleDay,
                Schedule_Time__c = scheduleTime,
                Email_Subject__c = emailSubject,
                Job_Id__c = jobId,
                Is_Active__c = true
            );
            insert scheduleRecord;
            */
            
        } catch (Exception e) {
            System.debug('Error saving schedule configuration: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<Map<String, Object>> getScheduledJobs() {
        try {
            List<Map<String, Object>> scheduledJobs = new List<Map<String, Object>>();
            
            // Query CronTrigger to get scheduled jobs
            List<CronTrigger> cronJobs = [
                SELECT Id, CronJobDetail.Name, CronExpression, State, NextFireTime, PreviousFireTime,
                       CronJobDetail.JobType, CreatedById, CreatedBy.Name
                FROM CronTrigger 
                WHERE CronJobDetail.Name LIKE 'Report Email%'
                AND State IN ('WAITING', 'ACQUIRED', 'EXECUTING')
                ORDER BY NextFireTime ASC
            ];
            
            for (CronTrigger job : cronJobs) {
                Map<String, Object> jobInfo = new Map<String, Object>();
                jobInfo.put('id', job.Id);
                jobInfo.put('name', job.CronJobDetail.Name);
                jobInfo.put('cronExpression', job.CronExpression);
                jobInfo.put('state', job.State);
                jobInfo.put('nextFireTime', job.NextFireTime);
                jobInfo.put('previousFireTime', job.PreviousFireTime);
                jobInfo.put('submittedBy', job.CreatedBy.Name);
                jobInfo.put('submittedById', job.CreatedById);
                
                // Parse additional details from job name or stored configuration
                Map<String, Object> jobDetails = parseJobDetails(job.CronJobDetail.Name);
                jobInfo.putAll(jobDetails);
                
                scheduledJobs.add(jobInfo);
            }
            
            return scheduledJobs;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching scheduled jobs: ' + e.getMessage());
        }
    }
    
    private static Map<String, Object> parseJobDetails(String jobName) {
        Map<String, Object> details = new Map<String, Object>();
        
        // Parse job name to extract report info
        // Expected format: "Report Email - [ReportId] - [Subject] - [X recipients] - [Timestamp]"
        String[] parts = jobName.split(' - ');
        
        if (parts.size() >= 4) {
            String reportId = parts[1];
            String emailSubject = parts[2];
            String recipientInfo = parts[3]; // "X recipients"
            
            // Extract recipient count
            Integer recipientCount = 0;
            try {
                if (recipientInfo.contains(' recipients')) {
                    String countStr = recipientInfo.replace(' recipients', '');
                    recipientCount = Integer.valueOf(countStr);
                }
            } catch (Exception e) {
                recipientCount = 0;
            }
            
            // Query the actual report name using the report ID
            try {
                List<Report> reports = [SELECT Id, Name FROM Report WHERE Id = :reportId LIMIT 1];
                if (!reports.isEmpty()) {
                    details.put('reportName', reports[0].Name);
                    details.put('reportId', reportId);
                } else {
                    details.put('reportName', 'Report Not Found');
                    details.put('reportId', reportId);
                }
            } catch (Exception e) {
                details.put('reportName', 'Error Loading Report');
                details.put('reportId', reportId);
            }
            
            details.put('emailSubject', emailSubject);
            details.put('recipientCount', recipientCount);
        } else {
            details.put('reportName', 'Unknown Report');
            details.put('emailSubject', 'Unknown Subject');
            details.put('recipientCount', 0);
        }
        
        return details;
    }
    
    @AuraEnabled
    public static Map<String, Object> getCurrentUserInfo() {
        try {
            Map<String, Object> userInfo = new Map<String, Object>();
            userInfo.put('id', System.UserInfo.getUserId());
            userInfo.put('name', System.UserInfo.getUserName());
            userInfo.put('email', System.UserInfo.getUserEmail());
            
            return userInfo;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching user info: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String deleteScheduledJob(String jobId) {
        try {
            System.debug(jobId);
            System.abortJob(jobId);
            return 'Job deleted successfully';
        } catch (Exception e) {
            System.debug('Error Deleting schedule class: ' + e.getMessage());
            throw new AuraHandledException('Error deleting scheduled job: ' + e.getMessage());
        }
    }
}