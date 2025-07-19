// ReportSchedulerController.cls
public with sharing class ReportSchedulerController {
      @AuraEnabled(cacheable=true)
    public static List<Report> searchReports(String searchTerm) {
        try {
            // Sanitize search term
            String sanitizedSearchTerm = String.escapeSingleQuotes(searchTerm);
            
            // Build SOSL query to search reports
            String searchQuery = 'FIND \'' + sanitizedSearchTerm + '*\' IN NAME FIELDS ' +
                               'RETURNING Report(Id, Name, FolderName, Description, CreatedDate ' +
                               'WHERE IsDeleted = FALSE) ' +
                               'LIMIT 20';
            
            List<List<SObject>> searchResults = search.query(searchQuery);
            
            if (searchResults.size() > 0) {
                List<Report> reports = (List<Report>) searchResults[0];
                return reports;
            }
            
            return new List<Report>();
            
        } catch (Exception e) {
            throw new AuraHandledException('Error searching reports: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Report> searchReportsSOQL(String searchTerm) {
        try {
            // Alternative method using SOQL with LIKE operator
            String sanitizedSearchTerm = String.escapeSingleQuotes(searchTerm);
            String likePattern = '%' + sanitizedSearchTerm + '%';
            
            List<Report> reports = [
                SELECT Id, Name, FolderName, Description, CreatedDate 
                FROM Report 
                WHERE Name LIKE :likePattern 
                AND IsDeleted = FALSE
                ORDER BY Name ASC
                LIMIT 20
            ];
            
            return reports;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error searching reports: ' + e.getMessage());
        }
    }
    

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
    
    // Updated method calls in scheduleReportEmail
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
        String emailBody = (String) dataMap.get('emailBody'); // Now using this
        
        // Convert email addresses to List<String>
        List<String> emailAddresses = new List<String>();
        for (Object emailObj : emailAddressesObj) {
            emailAddresses.add((String) emailObj);
        }
        
        // Create or update the scheduled job - now passing emailBody
        String jobId = createScheduledJob(reportId, emailAddresses, scheduleType, scheduleDay, scheduleTime, emailSubject, emailBody);
        
        // Store the schedule configuration for future reference - now passing emailBody
        saveScheduleConfiguration(reportId, emailAddresses, scheduleType, scheduleDay, scheduleTime, emailSubject, emailBody, jobId);
        
        return 'SUCCESS';
        
    } catch (Exception e) {
        System.debug('Error scheduling report email: ' + e.getMessage());
        throw new AuraHandledException('Error scheduling report email: ' + e.getMessage());
    }
}

// Updated createScheduledJob method in ReportSchedulerController.cls
private static String createScheduledJob(String reportId, List<String> emailAddresses, String scheduleType, 
                                       String scheduleDay, String scheduleTime, String emailSubject, String emailBody) {
    
    // Generate cron expression based on schedule type
    String cronExpression = generateCronExpression(scheduleType, scheduleDay, scheduleTime);
    
    // Create the schedulable job with email body
    ReportEmailSchedulable schedulableJob = new ReportEmailSchedulable(reportId, emailAddresses, emailSubject, emailBody);
    
    // Generate a unique job name that includes the report ID and recipient count
    String jobName = 'Report Email - ' + reportId + ' - ' + emailSubject + ' - ' + emailAddresses.size() +' recipients - '+ scheduleDay + ' - ' + System.now().getTime();
    
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
                                            String scheduleDay, String scheduleTime, String emailSubject, String emailBody, String jobId) {
    try {
        // Get report name for better display
        String reportName = 'Unknown Report';
        try {
            List<Report> reports = [SELECT Id, Name FROM Report WHERE Id = :reportId LIMIT 1];
            if (!reports.isEmpty()) {
                reportName = reports[0].Name;
            }
        } catch (Exception e) {
            System.debug('Error fetching report name: ' + e.getMessage());
        }
        
        // Calculate next fire time
        DateTime nextFireTime = calculateNextFireTime(scheduleType, scheduleDay, scheduleTime);
        
        // Create and insert the schedule record
        Report_Schedule__c scheduleRecord = new Report_Schedule__c(
            Report_Id__c = reportId,
            Report_Name__c = reportName,
            Email_Addresses__c = String.join(emailAddresses, ';'),
            Schedule_Type__c = scheduleType,
            Schedule_Day__c = scheduleDay,
            Schedule_Time__c = scheduleTime,
            Email_Subject__c = emailSubject,
            Email_Body__c = emailBody, // Add this field to your custom object
            Job_Id__c = jobId,
            Is_Active__c = true,
            Next_Fire_Time__c = nextFireTime
        );
        insert scheduleRecord;
        
        System.debug('Schedule configuration saved successfully: ' + scheduleRecord.Id);
        
    } catch (Exception e) {
        System.debug('Error saving schedule configuration: ' + e.getMessage());
        throw new AuraHandledException('Error saving schedule configuration: ' + e.getMessage());
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
                jobInfo.put('id', String.valueOf(job.Id).substring(0, 15)); // ✅ Correct

                //jobInfo.put('id', job.Id);
            
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
@AuraEnabled
public static Map<String, Object> getScheduleById(String scheduleId) {
    try {
        List<Report_Schedule__c> schedules = [
            SELECT Id, Report_Id__c, Report_Name__c, Email_Addresses__c, Schedule_Type__c, 
                   Schedule_Day__c, Schedule_Time__c, Email_Subject__c, Job_Id__c,Email_Body__c,
                   Next_Fire_Time__c
            FROM Report_Schedule__c 
            WHERE  Job_Id__c = :scheduleId AND Is_Active__c = true
            LIMIT 1
        ];
       
        if (schedules.isEmpty()) {
             
            throw new AuraHandledException('Schedule not found');
        }
        
        Report_Schedule__c schedule = schedules[0];
        
        Map<String, Object> scheduleData = new Map<String, Object>();
        scheduleData.put('id', schedule.Id);
         
        scheduleData.put('reportId', schedule.Report_Id__c);
        scheduleData.put('emailAddresses', schedule.Email_Addresses__c.split(';'));
        scheduleData.put('scheduleType', schedule.Schedule_Type__c);
        scheduleData.put('scheduleDay', schedule.Schedule_Day__c);
        scheduleData.put('scheduleTime', schedule.Schedule_Time__c);
        scheduleData.put('emailSubject', schedule.Email_Subject__c);
        scheduleData.put('jobId', schedule.Job_Id__c);
        scheduleData.put('emailBody', schedule.Email_Body__c);


        
        return scheduleData;
       
    } catch (Exception e) {
        throw new AuraHandledException('Error fetching schedule: ' + e.getMessage());
    }
}

@AuraEnabled
public static String updateSchedule(String scheduleId, String scheduleData) {
    try {
        // Parse the schedule data
        Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(scheduleData);
        
        String reportId = (String) dataMap.get('reportId');
        List<Object> emailAddressesObj = (List<Object>) dataMap.get('emailAddresses');
        String scheduleType = (String) dataMap.get('scheduleType');
        String scheduleDay = (String) dataMap.get('scheduleDay');
        String scheduleTime = (String) dataMap.get('scheduleTime');
        String emailSubject = (String) dataMap.get('emailSubject');
        String emailBody = (String) dataMap.get('emailBody'); // Now using this
        
        // Convert email addresses to List<String>
        List<String> emailAddresses = new List<String>();
        for (Object emailObj : emailAddressesObj) {
            emailAddresses.add((String) emailObj);
        }
        
        // Get existing schedule
        List<Report_Schedule__c> existingSchedules = [
            SELECT Id, Job_Id__c
            FROM Report_Schedule__c 
            WHERE Job_Id__c = :scheduleId AND Is_Active__c = true
            LIMIT 1
        ];
        
        if (existingSchedules.isEmpty()) {
            throw new AuraHandledException('Schedule not found');
        }
        
        Report_Schedule__c existingSchedule = existingSchedules[0];
        
        // Delete the old scheduled job
        if (String.isNotBlank(existingSchedule.Job_Id__c)) {
            try {
                System.abortJob(existingSchedule.Job_Id__c);
            } catch (Exception e) {
                System.debug('Error aborting old job: ' + e.getMessage());
            }
        }
        
        String recordId = existingSchedule.Id;
        
        // Create new scheduled job - now passing emailBody
        String newJobId = createScheduledJob(reportId, emailAddresses, scheduleType, scheduleDay, scheduleTime, emailSubject, emailBody);
        
        // Update the schedule record - now passing emailBody
        updateScheduleRecord(recordId, reportId, emailAddresses, scheduleType, scheduleDay, scheduleTime, emailSubject, emailBody, newJobId);
        
        return 'SUCCESS';
        
    } catch (Exception e) {
        System.debug('Error updating schedule: ' + e.getMessage());
        throw new AuraHandledException('Error updating schedule: ' + e.getMessage());
    }
}

@AuraEnabled
public static String deleteScheduledJob(String jobId) {
    try {
       
        // Get the schedule record
        List<Report_Schedule__c> schedules = [
            SELECT Id, Job_Id__c
            FROM Report_Schedule__c 
            WHERE Job_Id__c = :jobId AND Is_Active__c = true
            LIMIT 1
        ];
        
        if (schedules.isEmpty()) {
            throw new AuraHandledException('Schedule not found');
        }
        
        Report_Schedule__c schedule = schedules[0];
        system.debug('delete Id '+schedule.Job_Id__c);
                
        // Abort the scheduled job
        if (String.isNotBlank(schedule.Job_Id__c)) {
            try {
                
                System.abortJob(schedule.Job_Id__c);
            } catch (Exception e) {
                System.debug('Error aborting job: ' + e.getMessage());
            }
        }
        
        // Mark schedule as inactive (soft delete)
        schedule.Is_Active__c = false;
        delete schedule;
        
        return 'Schedule deleted successfully';
        
    } catch (Exception e) {
        System.debug('Error deleting schedule: ' + e.getMessage());
        throw new AuraHandledException('Error deleting schedule: ' + e.getMessage());
    }
}

// HELPER METHODS:

// Updated updateScheduleRecord method
private static void updateScheduleRecord(String recordId, String reportId, List<String> emailAddresses, 
                                       String scheduleType, String scheduleDay, String scheduleTime, 
                                       String emailSubject, String emailBody, String jobId) {
    try {
        // Get report name
        String reportName = 'Unknown Report';
        try {
            List<Report> reports = [SELECT Id, Name FROM Report WHERE Id = :reportId LIMIT 1];
            if (!reports.isEmpty()) {
                reportName = reports[0].Name;
            }
        } catch (Exception e) {
            System.debug('Error fetching report name: ' + e.getMessage());
        }
        
        // Calculate next fire time
        DateTime nextFireTime = calculateNextFireTime(scheduleType, scheduleDay, scheduleTime);
        
        // Update the schedule record
        Report_Schedule__c scheduleRecord = new Report_Schedule__c(
            Id = recordId,
            Report_Id__c = reportId,
            Report_Name__c = reportName,
            Email_Addresses__c = String.join(emailAddresses, ';'),
            Schedule_Type__c = scheduleType,
            Schedule_Day__c = scheduleDay,
            Schedule_Time__c = scheduleTime,
            Email_Subject__c = emailSubject,
            Email_Body__c = emailBody, // Add this field to your custom object
            Job_Id__c = jobId,
            Next_Fire_Time__c = nextFireTime
        );
        update scheduleRecord;
        
    } catch (Exception e) {
        System.debug('Error updating schedule record: ' + e.getMessage());
        throw new AuraHandledException('Error updating schedule record: ' + e.getMessage());
    }
}

private static DateTime calculateNextFireTime(String scheduleType, String scheduleDay, String scheduleTime) {
    try {
        // Parse time
        String[] timeParts = scheduleTime.split(':');
        Integer hour = Integer.valueOf(timeParts[0]);
        Integer minute = Integer.valueOf(timeParts[1]);
        
        DateTime now = DateTime.now();
        DateTime nextFire = null;
        
        if (scheduleType == 'Daily') {
            nextFire = DateTime.newInstance(now.date(), Time.newInstance(hour, minute, 0, 0));
            if (nextFire <= now) {
                nextFire = nextFire.addDays(1);
            }
        } else if (scheduleType == 'Weekly') {
            // Get target day of week (1=Sunday, 2=Monday, etc.)
            Integer targetDayOfWeek = Integer.valueOf(getDayOfWeekNumber(scheduleDay));
            Date today = now.date();
            Integer currentDayOfWeek = Math.mod(Date.newInstance(1900, 1, 7).daysBetween(today), 7) + 1;
            
            Integer daysToAdd = targetDayOfWeek - currentDayOfWeek;
            if (daysToAdd < 0) daysToAdd += 7;
            
            nextFire = DateTime.newInstance(today.addDays(daysToAdd), Time.newInstance(hour, minute, 0, 0));
            if (nextFire <= now) {
                nextFire = nextFire.addDays(7);
            }
        } else if (scheduleType == 'Monthly') {
            // Simplified monthly calculation
            Date today = now.date();
            Integer targetDay = scheduleDay.equals('Last') ? Date.daysInMonth(today.year(), today.month()) : Integer.valueOf(scheduleDay);
            
            nextFire = DateTime.newInstance(Date.newInstance(today.year(), today.month(), targetDay), Time.newInstance(hour, minute, 0, 0));
            if (nextFire <= now) {
                // Move to next month
                nextFire = nextFire.addMonths(1);
            }
        }
        
        return nextFire;
        
    } catch (Exception e) {
        System.debug('Error calculating next fire time: ' + e.getMessage());
        return DateTime.now().addHours(1); // Default to 1 hour from now
    }
}

private static String getStatusVariant(String state) {
    switch on state {
        when 'WAITING', 'ACQUIRED' {
            return 'success';
        }
        when 'EXECUTING' {
            return 'warning';
        }
        when 'COMPLETE' {
            return 'success';
        }
        when else {
            return 'error';
        }
    }
}



//Existing
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
    
    /*@AuraEnabled
    public static String deleteScheduledJob(String jobId) {
        try {
            System.debug(jobId);
            System.abortJob(jobId);
            return 'Job deleted successfully';
        } catch (Exception e) {
            System.debug('Error Deleting schedule class: ' + e.getMessage());
            throw new AuraHandledException('Error deleting scheduled job: ' + e.getMessage());
        }
    }*/
}