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
    @track displayOption = false;
    @track selectedFormatLabel = '';
    @track showReportFormatDropdown = false;
    @track selectedFormatIcon = '';
    // Schedule type options
    scheduleTypeOptions = [
        { label: 'Daily', value: 'Daily' },
        { label: 'Weekly', value: 'Weekly' },
        { label: 'Monthly', value: 'Monthly' }
    ];

    get formatOptions() {
        return [
            { label: 'Excel (.xlsx)', value: 'xlsx', icon: 'doctype:excel' },
            { label: 'Excel 97-2003 (.xls)', value: 'xls', icon: 'doctype:excel' },
            { label: 'CSV (.csv)', value: 'csv', icon: 'doctype:csv' }
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

    get isRecordSelected() {
        return this.selectedReportId === "" ? false : true;
    }

    get isWeekly() {
        return this.selectedScheduleType === 'Weekly';
    }

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
               !this.selectedFormatLabel ||
               (this.showDaySelection && (
                   this.isWeekly
                       ? (!this.selectedDays || this.selectedDays.length === 0)
                       : !this.selectedDay
               ));
    }

    get cardTitle() {
        return this.isEditMode ? 'Edit Scheduled Report' : 'Schedule Report Email';
    }

    get submitButtonLabel() {
        return this.isEditMode ? 'Update Schedule' : 'Schedule Report';
    }

    get cancelButtonLabel() {
        return this.isEditMode ? 'Cancel Edit' : 'Cancel';
    }

    get hasSelection() {
        return this.selectedReportId !== '';
    }

    get searchInputClass() {
        return `slds-input slds-combobox__input slds-has-focus ${this.showSearchValidationError ? 'slds-has-error' : ''}`;
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

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        
        this.displayOption = true;
        
        // Clear previous timer
        clearTimeout(this.debounceTimer);
        
        // Set new timer for debounced search
        this.debounceTimer = setTimeout(() => {
            if (this.searchTerm.length >= 1) {
                this.performSearch();
            } else {
                this.reports = [];
                this.displayOption = false;
            }
        }, 300);
    }

    performSearch() {
        this.isLoading = true;
        console.log('searching', this.searchTerm);
        searchReports({ searchTerm: this.searchTerm })
            .then(result => {
                this.reports = result.map(report => ({
                    Id: report.Id,
                    Name: report.Name,
                    FolderName: report.FolderName,
                    Description: report.Description || 'No description available'
                }));
                this.displayOption = this.reports.length > 0;
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                 console.log('search failed',error);
            });
    }

    handleReportSelect(event) {
        const selectedId = event.currentTarget.dataset.item;
        const selectedReport = this.reports.find(report => report.Id === selectedId);
        
        if (selectedReport) {
            this.selectedReportId = selectedReport.Id;
            this.selectedReportName = selectedReport.Name;
            this.searchTerm = selectedReport.Name;
            this.displayOption = false;
            if (this.isEditMode) {
                this.editingScheduleData.reportId = selectedReport.Id;
            }
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

    removeSelectionHandler(event) {
        this.selectedReportId = '';
        this.selectedReportName = '';
        this.displayOption = false;
        console.log('id', this.selectedReportId);
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

    handleDaysChange(event) {
        this.selectedDays = event.detail.value;
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

    toggleReportFormatDropdown(event) {
        event.stopPropagation();
        this.showReportFormatDropdown = !this.showReportFormatDropdown;
    }

    handleToggleChange(event) {
        this.showAdvanced = event.target.checked;
    }

    handleTimeChange(event) {
        this.selectedTime = event.target.value;
        this.clearStatus();
    }

    handleSubjectChange(event) {
        this.emailSubject = event.target.value;
    }

    handleBodyChange(event) {
        this.emailBody = event.target.value;
    }

    handleFormatChange(event) {
        this.selectedFormat = event.target.value;
    }

    handleFormatIconSelect(event) {
        const selectedValue = event.currentTarget.dataset.value;
        console.log('Selected value:', selectedValue);
        const selected = this.formatOptions.find(opt => opt.value === selectedValue);
        console.log('Selected object:', selected);
        if (selected) {
            this.selectedFormat = selected.value;
            this.selectedFormatLabel = selected.label;
            this.selectedFormatIcon = selected.icon;
            this.showReportFormatDropdown = false;
        }
        
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
    }

    closeEditModal() {
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
        }
    }

    // Method to handle updating existing schedule
    updateExistingSchedule() {
        const isWeekly = this.selectedScheduleType === 'Weekly';
        const scheduleDayValue = isWeekly
            ? this.selectedDays.join(';')
            : this.selectedDay;

        const scheduleData = {
            reportId: this.selectedReportId,
            emailAddresses: this.emailList,
            scheduleType: this.selectedScheduleType,
            scheduleDay: scheduleDayValue,
            scheduleTime: this.selectedTime,
            emailSubject: this.emailSubject || this.generateDefaultSubject(),
            emailBody: this.emailBody || '',
            fileFormat: this.selectedFormat
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

    // Method to handle edit button click
    handleEditSchedule(event) {
        const scheduleId = event.target.dataset.scheduleId;
        if (scheduleId && scheduleId.length > 15) {
            scheduleId = scheduleId.substring(0, 15);
        }
        console.log('schedule Id', scheduleId);
        if (!scheduleId) {
            console.error('Schedule ID not found');
            return;
        }

        this.loadScheduleForEdit(scheduleId);
    }

    // Method to load schedule data for editing
    loadScheduleForEdit(scheduleId) {
        getScheduleById({ scheduleId: scheduleId })
            .then(result => {
                this.editingScheduleId = scheduleId;
                this.editingScheduleData = result;
                this.selectedReportId = result.reportId;
                const reportName = this.reportNameMap.get(result.reportId);
                this.emailList = result.emailAddresses || [];
                this.selectedScheduleType = result.scheduleType;
                this.searchTerm = reportName || '';
                this.selectedReportName = reportName || '';
                
                // Populate schedule day(s) depending on type
                if (result.scheduleType === 'Weekly') {
                    this.selectedDays = result.scheduleDay ? result.scheduleDay.split(';') : [];
                    this.selectedDay = ''; // Clear old single day value
                    this.days = this.days.map(day => ({
                        ...day,
                        checked: this.selectedDays.includes(day.name)
                    }));
                } else {
                    this.selectedDay = result.scheduleDay || '';
                    this.selectedDays = []; // Clear any previous multi-day values
                }
                
                const formatFromBackend = result.fileFormat;
                const matchedFormat = this.formatOptions.find(opt => opt.value === formatFromBackend);

                if (matchedFormat) {
                    this.selectedFormat = matchedFormat.value;
                    this.selectedFormatLabel = matchedFormat.label;
                    this.selectedFormatIcon = matchedFormat.icon;
                }

                // Set other fields
                this.selectedTime = result.scheduleTime;
                this.emailSubject = result.emailSubject || '';
                this.emailBody = result.emailBody || '';
                    
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

    // Method to exit edit mode
    exitEditMode() {
        this.isEditMode = false;
        this.editingScheduleId = '';
        this.editingScheduleData = {};
    }

    // Method to scroll to form
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
            console.log("Schedule ID delete:", scheduleId);
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
        this.searchTerm = '';
        this.reports = [];
        this.showDropdown = false;
        this.currentEmail = '';
        this.emailList = [];
        this.selectedScheduleType = 'Daily';
        this.selectedDay = '';
        this.selectedDays = [];
        this.selectedTime = '09:00';
        this.emailSubject = '';
        this.emailBody = '';
        this.selectedFormat = '';
        this.days.forEach(day => {
            day.checked = false;
            this.showAdvanced = false;
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

    handleBlur(event) {
        // Small delay to allow clicks on dropdown options before hiding
        setTimeout(() => {
            this.displayOption = false;
            this.showReportFormatDropdown = false;
        }, 200);
    }

    handleError(event) {
        setTimeout(() => {
            this.validateReportSearch();
        }, 200);
    }

    validateReportSearch() {
        const isInvalid = this.searchTerm && !this.selectedReportId;
        this.showSearchValidationError = isInvalid;
        return !isInvalid;
    }

    handleReportFormatFocusOut(event){
setTimeout(() => {
        const formatWrapper = this.template.querySelector('[data-id="report-format-wrapper"]');
        if (!formatWrapper.contains(document.activeElement)) {
            this.showReportFormatDropdown = false;
        }
    }, 200);
}

handleReportSearchFocusOut(event) {
    setTimeout(() => {
        const searchWrapper = this.template.querySelector('.slds-combobox_container');
        if (!searchWrapper.contains(document.activeElement)) {
            this.displayOption = false;
        }
    }, 200);
}
}