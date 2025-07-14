// reportEmailScheduler.js
import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import getReports from '@salesforce/apex/ReportSchedulerController.getReports';
import scheduleReportEmail from '@salesforce/apex/ReportSchedulerController.scheduleReportEmail';
import getScheduledJobs from '@salesforce/apex/ReportSchedulerController.getScheduledJobs';
import deleteScheduledJob from '@salesforce/apex/ReportSchedulerController.deleteScheduledJob';

export default class ReportEmailScheduler extends LightningElement {
    @track selectedReportId = '';
    
    @track currentEmail = '';
    @track emailList = [];
    @track selectedScheduleType = 'Daily';
    @track selectedDay = '';
    @track selectedTime = '09:00';
    @track emailSubject = '';
    @track reportOptions = [];
    @track statusMessage = '';
    @track showStatus = false;
    @track statusClass = '';
    @track scheduledReports = [];
    @track isLoadingSchedules = true;
    @track currentUserId = '';
    @track currentUserName = '';
    @track reportNameMap = new Map(); // Store report ID to name mapping

    // Schedule type options
    scheduleTypeOptions = [
        { label: 'Daily', value: 'Daily' },
        { label: 'Weekly', value: 'Weekly' },
        { label: 'Monthly', value: 'Monthly' }
    ];

    // Day options for weekly schedule
    weeklyDayOptions = [
        { label: 'Monday', value: 'Monday' },
        { label: 'Tuesday', value: 'Tuesday' },
        { label: 'Wednesday', value: 'Wednesday' },
        { label: 'Thursday', value: 'Thursday' },
        { label: 'Friday', value: 'Friday' },
        { label: 'Saturday', value: 'Saturday' },
        { label: 'Sunday', value: 'Sunday' }
    ];

    // Day options for monthly schedule
    monthlyDayOptions = [
        { label: '1st', value: '1' },
        { label: '2nd', value: '2' },
        { label: '3rd', value: '3' },
        { label: '4th', value: '4' },
        { label: '5th', value: '5' },
        { label: '6th', value: '6' },
        { label: '7th', value: '7' },
        { label: '8th', value: '8' },
        { label: '9th', value: '9' },
        { label: '10th', value: '10' },
        { label: '11th', value: '11' },
        { label: '12th', value: '12' },
        { label: '13th', value: '13' },
        { label: '14th', value: '14' },
        { label: '15th', value: '15' },
        { label: '16th', value: '16' },
        { label: '17th', value: '17' },
        { label: '18th', value: '18' },
        { label: '19th', value: '19' },
        { label: '20th', value: '20' },
        { label: '21st', value: '21' },
        { label: '22nd', value: '22' },
        { label: '23rd', value: '23' },
        { label: '24th', value: '24' },
        { label: '25th', value: '25' },
        { label: '26th', value: '26' },
        { label: '27th', value: '27' },
        { label: '28th', value: '28' },
        { label: 'Last day', value: 'Last' }
    ];

    // Wire method to get reports
    @wire(getReports)
    wiredReports({ error, data }) {
        if (data) {
            this.reportOptions = data.map(report => ({
                label: report.Name,
                value: report.Id
            }));
            
            // Build report name map for quick lookup
            this.reportNameMap = new Map();
            data.forEach(report => {
                this.reportNameMap.set(report.Id, report.Name);
            });
        } else if (error) {
            this.showToast('Error', 'Failed to load reports', 'error');
        }
    }

    // Wire method to get page reference for current user info
    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        // Get current user info when component loads
        this.getCurrentUserInfo();
    }

    // Load scheduled reports when component initializes
    connectedCallback() {
        this.loadScheduledReports();
    }

    // Computed properties
    get hasEmails() {
        return this.emailList.length > 0;
    }

    get isAddEmailDisabled() {
        return !this.currentEmail || !this.isValidEmail(this.currentEmail);
    }

    get showDaySelection() {
        return this.selectedScheduleType === 'Weekly' || this.selectedScheduleType === 'Monthly';
    }

    get daySelectionLabel() {
        return this.selectedScheduleType === 'Weekly' ? 'Select Day of Week' : 'Select Day of Month';
    }

    get daySelectionPlaceholder() {
        return this.selectedScheduleType === 'Weekly' ? 'Choose day of week...' : 'Choose day of month...';
    }

    get dayOptions() {
        return this.selectedScheduleType === 'Weekly' ? this.weeklyDayOptions : this.monthlyDayOptions;
    }

    get hasScheduledReports() {
        return this.scheduledReports && this.scheduledReports.length > 0;
    }

    get showNoSchedulesMessage() {
        return !this.isLoadingSchedules && !this.hasScheduledReports;
    }

    get isScheduleDisabled() {
        return !this.selectedReportId || 
               !this.hasEmails || 
               !this.selectedTime || 
               (this.showDaySelection && !this.selectedDay);
    }

    // Event handlers
    handleReportChange(event) {
        this.selectedReportId = event.detail.value;
        this.clearStatus();
    }

    handleEmailInputChange(event) {
        this.currentEmail = event.target.value;
    }

    handleScheduleTypeChange(event) {
        this.selectedScheduleType = event.detail.value;
        this.selectedDay = ''; // Reset day selection when schedule type changes
        this.clearStatus();
    }

    handleDayChange(event) {
        this.selectedDay = event.detail.value;
        this.clearStatus();
    }

    handleTimeChange(event) {
        this.selectedTime = event.target.value;
        this.clearStatus();
    }

    handleSubjectChange(event) {
        this.emailSubject = event.target.value;
    }

    addEmail() {
        if (this.currentEmail && this.isValidEmail(this.currentEmail)) {
            if (!this.emailList.includes(this.currentEmail)) {
                this.emailList = [...this.emailList, this.currentEmail];
                this.currentEmail = '';
                this.clearStatus();
            } else {
                this.showToast('Warning', 'Email already added', 'warning');
            }
        } else {
            this.showToast('Error', 'Please enter a valid email address', 'error');
        }
    }

    removeEmail(event) {
        const emailToRemove = event.target.name;
        this.emailList = this.emailList.filter(email => email !== emailToRemove);
        this.clearStatus();
    }

    handleCancel() {
        this.resetForm();
    }

    handleSchedule() {
        if (this.isScheduleDisabled) {
            this.showToast('Error', 'Please fill in all required fields', 'error');
            return;
        }

        const scheduleData = {
            reportId: this.selectedReportId,
            emailAddresses: this.emailList,
            scheduleType: this.selectedScheduleType,
            scheduleDay: this.selectedDay,
            scheduleTime: this.selectedTime,
            emailSubject: this.emailSubject || this.generateDefaultSubject()
        };

        scheduleReportEmail({ scheduleData: JSON.stringify(scheduleData) })
            .then(result => {
                this.showToast('Success', 'Report email scheduled successfully', 'success');
                this.showStatusMessage('Report email scheduled successfully!', 'slds-text-color_success');
                this.resetForm();
                // Refresh the scheduled reports list
                this.loadScheduledReports();
            })
            .catch(error => {
                console.error('Error scheduling report:', error);
                this.showToast('Error', 'Failed to schedule report email', 'error');
                this.showStatusMessage('Failed to schedule report email. Please try again.', 'slds-text-color_error');
            });
    }

    // Scheduled Reports Management Methods
    loadScheduledReports() {
        this.isLoadingSchedules = true;
        getScheduledJobs()
            .then(result => {
                this.scheduledReports = this.processScheduledJobsData(result);
                this.isLoadingSchedules = false;
            })
            .catch(error => {
                console.error('Error loading scheduled reports:', error);
                this.showToast('Error', 'Failed to load scheduled reports', 'error');
                this.isLoadingSchedules = false;
            });
    }

    processScheduledJobsData(jobsData) {
        return jobsData.map(job => {
            return {
                id: job.id,
                reportName: job.reportName || 'Unknown Report',
                scheduledBy: job.submittedBy || 'Unknown',
                scheduleTime: this.parseScheduleTime(job.cronExpression),
                scheduleType: this.parseScheduleType(job.cronExpression),
                emailRecipients: [], // Not storing actual emails for security
                recipientCount: job.recipientCount || 0,
                nextFireTime: job.nextFireTime,
                status: job.state || 'Active',
                statusVariant: this.getStatusVariant(job.state),
                cronExpression: job.cronExpression
            };
        });
    }

    parseEmailRecipients(jobName) {
        // Since we can't reliably extract email addresses from the job name,
        // we'll return a placeholder count. In a real implementation, you'd store
        // this information in a custom object.
        
        // For now, we'll try to extract some information from the job name
        // and return a reasonable recipient count based on the job structure
        
        // You could also modify the Apex controller to include recipient information
        // in the job details returned from getScheduledJobs()
        
        // Temporary solution: return a default array with one recipient
        // This should be replaced with actual recipient data storage
        return ['Recipients not stored']; // This will show as "1 recipients"
    }

    parseScheduleTime(cronExpression) {
        if (!cronExpression) return 'Unknown';
        
        const parts = cronExpression.split(' ');
        if (parts.length >= 3) {
            const minute = parts[1];
            const hour = parts[2];
            return `${hour.padStart(2, '0')}:${minute.padStart(2, '0')}`;
        }
        return 'Unknown';
    }

    parseScheduleType(cronExpression) {
        if (!cronExpression) return 'Unknown';
        
        const parts = cronExpression.split(' ');
        if (parts.length >= 6) {
            // Check if it's daily (runs every day)
            if (parts[3] === '*' && parts[4] === '*' && parts[5] === '?') {
                return 'Daily';
            }
            // Check if it's weekly (specific day of week)
            if (parts[3] === '?' && parts[4] === '*' && parts[5] !== '?') {
                return 'Weekly';
            }
            // Check if it's monthly (specific day of month)
            if (parts[3] !== '*' && parts[4] === '*' && parts[5] === '?') {
                return 'Monthly';
            }
        }
        return 'Custom';
    }

    getStatusVariant(state) {
        switch (state) {
            case 'WAITING':
            case 'ACQUIRED':
                return 'success';
            case 'EXECUTING':
                return 'warning';
            case 'COMPLETE':
                return 'success';
            case 'ERROR':
                return 'error';
            case 'DELETED':
                return 'inverse';
            default:
                return 'success';
        }
    }

    refreshScheduledReports() {
        this.loadScheduledReports();
    }

    handleDeleteSchedule(event) {
        const scheduleId = event.target.dataset.scheduleId;
        
        console.log("Schedule ID to delete:", scheduleId);
        
        if (!scheduleId) {
            console.error('Schedule ID not found');
            return;
        }
        
        this.deleteSchedule(scheduleId);
    }

    viewScheduleDetails(scheduleId) {
        const schedule = this.scheduledReports.find(s => s.id === scheduleId);
        if (schedule) {
            // You can implement a modal or navigate to detail page
            this.showToast('Info', `Viewing details for: ${schedule.reportName}`, 'info');
        }
    }

    deleteSchedule(scheduleId) {
        if (confirm('Are you sure you want to delete this scheduled report?')) {
            deleteScheduledJob({ jobId: scheduleId })
                .then(result => {
                    this.showToast('Success', 'Scheduled report deleted successfully', 'success');
                    this.loadScheduledReports();
                })
                .catch(error => {
                    console.error('Error deleting scheduled job:', error);
                    this.showToast('Error', 'Failed to delete scheduled report', 'error');
                });
        }
    }

    getCurrentUserInfo() {
        // Get current user info - this is a simplified version
        // In a real implementation, you'd call an Apex method to get user details
        this.currentUserId = 'CurrentUserId';
        this.currentUserName = 'Current User';
    }

    // Helper methods
    isValidEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }

    generateDefaultSubject() {
        const selectedReport = this.reportOptions.find(option => option.value === this.selectedReportId);
        const reportName = selectedReport ? selectedReport.label : 'Report';
        return `${this.selectedScheduleType} ${reportName}`;
    }

    resetForm() {
        this.selectedReportId = '';
        this.currentEmail = '';
        this.emailList = [];
        this.selectedScheduleType = 'Daily';
        this.selectedDay = '';
        this.selectedTime = '09:00';
        this.emailSubject = '';
        this.clearStatus();
    }

    showStatusMessage(message, cssClass) {
        this.statusMessage = message;
        this.statusClass = cssClass;
        this.showStatus = true;
    }

    clearStatus() {
        this.showStatus = false;
        this.statusMessage = '';
        this.statusClass = '';
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}