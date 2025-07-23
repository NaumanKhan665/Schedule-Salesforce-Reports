// reportEmailScheduler.js
import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import getReports from '@salesforce/apex/ReportSchedulerController.getReports';
import scheduleReportEmail from '@salesforce/apex/ReportSchedulerController.scheduleReportEmail';
import getScheduledJobs from '@salesforce/apex/ReportSchedulerController.getScheduledJobs';
import deleteScheduledJob from '@salesforce/apex/ReportSchedulerController.deleteScheduledJob';
import getScheduleById from '@salesforce/apex/ReportSchedulerController.getScheduleById';
import updateSchedule from '@salesforce/apex/ReportSchedulerController.updateSchedule';

import searchReports from '@salesforce/apex/ReportSearchController.searchReports';

export default class ReportEmailScheduler extends LightningElement {

 @track searchTerm = '';
    @track reports = [];
    @track selectedReportName = '';
    @track reportID = ''; // This will store the selected report ID
    @track isLoading = false;
    @track showDropdown = false;

    
@track selectedDays = []; // For weekly multi-day selection

    @track selectedReportId = '';
      @track showAdvanced = false;
    @track currentEmail = '';
    @track emailList = [];
    @track selectedScheduleType = 'Daily';
    @track selectedDay = '';
    @track selectedTime = '09:00';
    @track emailSubject = '';
    @track emailBody = '';
    @track selectedFormat = '';
    @track reportOptions = [];
    @track statusMessage = '';
    @track showStatus = false;
    @track statusClass = '';
    @track scheduledReports = [];
    @track isLoadingSchedules = true;
    @track currentUserId = '';
    @track currentUserName = '';
    @track reportNameMap = new Map(); // Store report ID to name mapping

    @track isEditMode = false;
    @track editingScheduleId = '';
    @track editingScheduleData = {};
  @track showAdvanced = false;
    @track showDropdown = false;
    // Schedule type options
    scheduleTypeOptions = [
        { label: 'Daily', value: 'Daily' },
        { label: 'Weekly', value: 'Weekly' },
        { label: 'Monthly', value: 'Monthly' }
    ];
get formatOptions() {
    return [
        { label: 'Excel (.xlsx)', value: 'xlsx' },
        { label: 'Excel 97-2003 (.xls)', value: 'xls' },
        { label: 'CSV (.csv)', value: 'csv' }
    ];
}
    // Day options for weekly schedule
    @track days = [
    { id: 'monday', name: 'Monday', label: 'Mon', checked: false },
    { id: 'tuesday', name: 'Tuesday', label: 'Tue', checked: false },
    { id: 'wednesday', name: 'Wednesday', label: 'Wed', checked: false },
    { id: 'thursday', name: 'Thursday', label: 'Thu', checked: false },
    { id: 'friday', name: 'Friday', label: 'Fri', checked: false },
    { id: 'saturday', name: 'Saturday', label: 'Sat', checked: false },
    { id: 'sunday', name: 'Sunday', label: 'Sun', checked: false }
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
   debounceTimer;

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.showDropdown = false;
        
        // Clear previous timer
        clearTimeout(this.debounceTimer);
        
        // Set new timer for debounced search
        this.debounceTimer = setTimeout(() => {
            if (this.searchTerm.length >= 2) {
                this.performSearch();
            } else {
                this.reports = [];
                this.showDropdown = false;
            }
        }, 300);
    }

    performSearch() {
        this.isLoading = true;
        
        searchReports({ searchTerm: this.searchTerm })
            .then(result => {
                this.reports = result.map(report => ({
                    Id: report.Id,
                    Name: report.Name,
                    FolderName: report.FolderName,
                    Description: report.Description || 'No description available'
                }));
                this.showDropdown = this.reports.length > 0;
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Error searching reports: ' + error.body.message, 'error');
            });
    }

    handleReportSelect(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selectedReport = this.reports.find(report => report.Id === selectedId);
        
        if (selectedReport) {
            this.selectedReportId = selectedReport.Id;
            this.selectedReportName = selectedReport.Name;
            this.searchTerm = selectedReport.Name;
            this.showDropdown = false;
            if (this.isEditMode) {
    this.editingScheduleData.reportId = selectedReport.Id;
}
            
           // this.showToast('Success', `Report "${selectedReport.Name}" selected`, 'success');
        }
    }

    handleInputFocus() {
        if (this.reports.length > 0) {
            this.showDropdown = true;
        }
    }

    handleInputBlur() {
        // Delay hiding dropdown to allow for click events
        setTimeout(() => {
            this.showDropdown = false;
        }, 200);
    }

    clearSelection() {
        this.selectedReportId = '';
        this.selectedReportName = '';
        this.searchTerm = '';
        this.reports = [];
        this.showDropdown = false;
    }

 

    // Getter for displaying current selection
    get hasSelection() {
        return this.selectedReportId !== '';
    }

    get isWeekly() {
    return this.selectedScheduleType === 'Weekly';
}

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
get showEditDaySelection() {
    return this.isEditMode && (this.selectedScheduleType === 'Weekly' || this.selectedScheduleType === 'Monthly');
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
               !this.selectedFormat||
         (this.showDaySelection && (
               this.isWeekly
                       ? (!this.selectedDays || this.selectedDays.length === 0)
                   : !this.selectedDay
           ));
    }

    handleDaysChange(event) {
    this.selectedDays = event.detail.value;
    this.clearStatus();
}

    // New computed properties for edit mode
    get cardTitle() {
        return this.isEditMode ? 'Edit Scheduled Report' : 'Schedule Report Email';
    }

    get submitButtonLabel() {
        return this.isEditMode ? 'Update Schedule' : 'Schedule Report';
    }

    get cancelButtonLabel() {
        return this.isEditMode ? 'Cancel Edit' : 'Cancel';
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
         this.selectedDays = [];
        this.clearStatus();
    }

    handleDayChange(event) {
    const dayName = event.target.dataset.day;
    const isChecked = event.target.checked;

    this.days = this.days.map(day =>
        day.name === dayName ? { ...day, checked: isChecked } : day
    );

    this.selectedDays = this.days
        .filter(day => day.checked)
        .map(day => day.name);

    this.clearStatus();
}
 
handleMonthlyDayChange(event) {
    this.selectedDay = event.detail.value;
    this.clearStatus();
}

timeOptions = Array.from({ length: 24 }, (_, hour)  => {
        const hourStr = String(hour).padStart(2, '0');
        const label = `${hourStr}:00 (${this.formatTo12Hour(hour, 0)})`;
        return { value: `${hourStr}:00`, label };
    });

    formatTo12Hour(hour, min) {
        const suffix = hour >= 12 ? 'PM' : 'AM';
        const displayHour = hour % 12 || 12;
        const minStr = String(min).padStart(2, '0');
        return `${displayHour}:${minStr} ${suffix}`;
    }
 showTimeDropdown() {
        this.showDropdown = true;
    }
    handleTimeChange(event) {
        this.selectedTime = event.target.value;
       // this.showDropdown = true;
    }

    handleToggleChange(event) {
        this.showAdvanced = event.target.checked;
    }

    handleTimeSelect(event) {
        event.preventDefault();
        const value = event.currentTarget.dataset.value;
        this.selectedTime = value;
        this.showDropdown = false;
         setTimeout(() => {
            const input = this.template.querySelector('.time-input');
            if (input) {
                input.focus();
            }
        }, 0);

        
    }

   
handleTimeTyping(event) {
    // Prevent dropdown from showing when typing
    this.showDropdown = false;
}

    

  /*  handleTimeChange(event) {
        this.selectedTime = event.target.value;
        this.clearStatus();
    }*/

    handleSubjectChange(event) {
        this.emailSubject = event.target.value;
    }
    

handleBodyChange(event) {
    this.emailBody = event.target.value;
} 
handleFormatChange(event) {
    this.selectedFormat  = event.target.value;
}
 handleToggleChange(event) {
        this.showAdvanced = event.target.checked;
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
        this.exitEditMode();
    }  closeEditModal() {
        this.resetForm();
        this.exitEditMode();
        this.isEditMode = false;
                this.clearStatus();
    }

    handleSchedule() {
        if (this.isScheduleDisabled) {
            this.showToast('Error', 'Please fill in all required fields', 'error');
            return;
        }

        if (this.isEditMode) {
            this.updateExistingSchedule();
        } else {
            this.createNewSchedule();
        }
    }

    // New method to handle creating new schedule
    createNewSchedule() {
        const isWeekly = this.selectedScheduleType === 'Weekly';
    const daysToSchedule = isWeekly ? this.selectedDays : [this.selectedDay];

  const scheduleData = {
    reportId: this.selectedReportId,
    emailAddresses: this.emailList,
    scheduleType: this.selectedScheduleType,
    scheduleDay: daysToSchedule.join(';'), // ✅ Multiple days as a single string
    scheduleTime: this.selectedTime,
    emailSubject: this.emailSubject || this.generateDefaultSubject(),
    emailBody: this.emailBody || '',
    fileFormat: this.selectedFormat
};

scheduleReportEmail({ scheduleData: JSON.stringify(scheduleData) })
    .then(() => {
        this.showToast('Success', 'Report email scheduled successfully', 'success');
        this.showStatusMessage('Report email scheduled successfully!', 'slds-text-color_success');
        this.resetForm();
        this.loadScheduledReports();
    })
    .catch(error => {
        console.error('Error scheduling report:', error);
        this.showToast('Error', 'Failed to schedule report email', 'error');
        this.showStatusMessage('Failed to schedule report email. Please try again.', 'slds-text-color_error');
    });

    }

    // New method to handle updating existing schedule
    updateExistingSchedule() {
    const isWeekly = this.selectedScheduleType === 'Weekly';
    const scheduleDayValue = isWeekly
        ? this.selectedDays.join(';')      // 🔁 Join multiple days
        : this.selectedDay;

const scheduleData = {
    reportId: this.selectedReportId,
    emailAddresses: this.emailList,
    scheduleType: this.selectedScheduleType,
    scheduleDay: scheduleDayValue,
    scheduleTime: this.selectedTime,
    emailSubject: this.emailSubject || this.generateDefaultSubject(),
    emailBody: this.emailBody || '',
     fileFormat :this.selectedFormat
};

        updateSchedule({ 
            scheduleId: this.editingScheduleId, 
            scheduleData: JSON.stringify(scheduleData) 
        })
            .then(result => {
                this.showToast('Success', 'Schedule updated successfully', 'success');
                this.showStatusMessage('Schedule updated successfully!', 'slds-text-color_success');
                this.resetForm();
                this.exitEditMode();
                this.loadScheduledReports();
            })
            .catch(error => {
                console.error('Error updating schedule:', error);
                this.showToast('Error', 'Failed to update schedule', 'error');
                this.showStatusMessage('Failed to update schedule. Please try again.', 'slds-text-color_error');
            });
    }

    // New method to handle edit button click
    handleEditSchedule(event) {
        const scheduleId = event.target.dataset.scheduleId;
        if (scheduleId && scheduleId.length > 15) {
        scheduleId = scheduleId.substring(0, 15);
    }
        console.log('schduel Iddd',scheduleId);
        if (!scheduleId) {
            console.error('Schedule ID not found');
            return;
        }

        this.loadScheduleForEdit(scheduleId);
    }

    // New method to load schedule data for editing
    loadScheduleForEdit(scheduleId) {
    getScheduleById({ scheduleId: scheduleId })
        .then(result => {
            this.editingScheduleId = scheduleId;
            this.editingScheduleData = result;

            // Set report ID
            this.selectedReportId = result.reportId;

            // Set search input with report name if available
            const reportName = this.reportNameMap.get(result.reportId);

            // Set email recipients
            this.emailList = result.emailAddresses || [];

            // Set schedule type
            this.selectedScheduleType = result.scheduleType;
            this.searchTerm = reportName || '';

           // Populate schedule day(s) depending on type
if (result.scheduleType === 'Weekly') {
    this.selectedDays = result.scheduleDay ? result.scheduleDay.split(';') : [];
    this.selectedDay = ''; // Clear old single day value
} else {
    this.selectedDay = result.scheduleDay || '';
    this.selectedDays = []; // Clear any previous multi-day values
}
              
            

            // Set other fields
            this.selectedTime = result.scheduleTime;
            this.emailSubject = result.emailSubject || '';
            this.emailBody = result.emailBody || '';
            this.selectedFormat =result.fileFormat 

            this.isEditMode = true;
            this.clearStatus();

            // Scroll to form
            this.scrollToForm();
        })
        .catch(error => {
            console.error('Error loading schedule for edit:', error);
            this.showToast('Error', 'Failed to load schedule data for edit', 'error');
        });
}

    // New method to exit edit mode
    exitEditMode() {
        this.isEditMode = false;
        this.editingScheduleId = '';
        this.editingScheduleData = {};
    }

    // New method to scroll to form
    scrollToForm() {
        const formElement = this.template.querySelector('lightning-card');
        if (formElement) {
            formElement.scrollIntoView({ behavior: 'smooth' });
        }
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
        return ['Recipients not stored'];
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
        
           if (scheduleId && scheduleId.length > 15) {
        scheduleId = scheduleId.substring(0, 15);
    }
        
        
        if (!scheduleId) {
            console.error('Schedule ID not found');
            return;
        }
        
        this.deleteSchedule(scheduleId);
    }

    viewScheduleDetails(scheduleId) {
        const schedule = this.scheduledReports.find(s => s.id === scheduleId);
        if (schedule) {
            this.showToast('Info', `Viewing details for: ${schedule.reportName}`, 'info');
        }
    }

    deleteSchedule(scheduleId) {
        if (confirm('Are you sure you want to delete this scheduled report?')) {
console.log("Schedule ID  delete:", scheduleId);
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
    this.selectedReportName = '';
    this.searchTerm = '';          // ✅ Clear input field
    this.reports = [];             // ✅ Clear result list
    this.showDropdown = false;     // ✅ Hide dropdown
    this.currentEmail = '';
    this.emailList = [];
    this.selectedScheduleType = 'Daily';
    this.selectedDay = '';
    this.selectedDays = [];
    this.selectedTime = '09:00';
    this.emailSubject = '';
    this.emailBody = '';
  this.selectedFormat ='';
 this.days.forEach(day => {
    day.checked = false;
});

  
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