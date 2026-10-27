import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getTaskDetails from '@salesforce/apex/MOMTaskUpdateController.getTaskDetails';
import updateTask     from '@salesforce/apex/MOMTaskUpdateController.updateTask';
import rejectTask     from '@salesforce/apex/MOMTaskUpdateController.rejectTask';

export default class MomTaskUpdate extends LightningElement {

    @track task;
    @track status             = 'Work in Progress';
    @track comment            = '';
    @track dueDate            = '';
    @track isLoading          = true;
    @track isSubmitted        = false;
    @track isRejected         = false;
    @track showRejectForm     = false;
    @track rejectComment      = '';
    @track errorMessage       = '';
    @track rejectErrorMessage = '';
    @track isFirstVisit       = true;
    @track targetDateValue    = '';

    taskId;
    token;

    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        if (pageRef && pageRef.state) {
            this.taskId = pageRef.state.taskId;
            this.token  = pageRef.state.token;
            if (this.taskId && this.token) {
                this.loadTask();
            } else {
                this.errorMessage = 'Invalid link. Please use the link provided in your email.';
                this.isLoading = false;
            }
        }
    }

    loadTask() {
        getTaskDetails({ taskId: this.taskId, token: this.token })
            .then(result => {
                this.task          = result;
                this.isFirstVisit  = result.isFirstVisit;
                this.status        = (result.isFirstVisit) ? 'Work in Progress' : (result.status || 'Work in Progress');
                this.comment       = result.description || '';
                this.targetDateValue = result.dueDate || '';

                if (this.isFirstVisit) {
                    this.dueDate = result.dueDate || '';
                } else {
                    this.dueDate = result.completionDate || '';
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.errorMessage = (error.body && error.body.message)
                    ? error.body.message
                    : 'Unable to load the action item. The link may be invalid.';
                this.isLoading = false;
            });
    }

    get isAlreadyCompleted() {
        return this.task != null && this.task.status === 'Completed';
    }

    get showReadOnly() {
        return !this.isLoading && !this.errorMessage && !this.isSubmitted && this.isAlreadyCompleted;
    }

    get showForm() {
        return !this.isLoading && !this.errorMessage && !this.isSubmitted && !this.isRejected && this.task != null && !this.isAlreadyCompleted;
    }

    get dateFieldLabel() {
        return this.isFirstVisit ? 'Target Date' : 'Completion Date';
    }

    get showTargetWeek() {
        return this.isFirstVisit;
    }

    get isWIP() {
        return this.status !== 'Completed';
    }

    get isCompleted() {
        return this.status === 'Completed';
    }

    get wipClass() {
        return this.status !== 'Completed' ? 'radio-label radio-label-selected' : 'radio-label';
    }

    get isCompletedDisabled() {
        if (this.isFirstVisit) {
            return true;
        }
        if (this.dueDate) {
            return false;
        }
        if (!this.targetDateValue) return true;
        const today = new Date();
        const todayStr = today.getFullYear() + '-' +
            String(today.getMonth() + 1).padStart(2, '0') + '-' +
            String(today.getDate()).padStart(2, '0');
        return todayStr < this.targetDateValue;
    }

    get completedHintText() {
        if (this.isFirstVisit) {
            return 'Available only on return visits';
        }
        return 'Select a Completion Date or wait until the Target Date';
    }

    get completedClass() {
        if (this.isCompletedDisabled) return 'radio-label radio-label-disabled';
        return this.status === 'Completed' ? 'radio-label radio-label-selected' : 'radio-label';
    }

    get formattedDueDate() {
        if (!this.task || !this.task.dueDate) return '—';
        try {
            const d = new Date(this.task.dueDate + 'T00:00:00');
            return d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
        } catch (e) {
            return this.task.dueDate;
        }
    }

    get targetWeek() {
        const dateStr = this.dueDate || (this.task && this.task.dueDate);
        if (!dateStr) return '—';
        const d = new Date(dateStr + 'T00:00:00');
        const startOfYear = new Date(d.getFullYear(), 0, 1);
        const dayOfYear = Math.floor((d - startOfYear) / 86400000) + 1;
        return Math.ceil(dayOfYear / 7);
    }

    get formattedMeetingDate() {
        if (!this.task || !this.task.meetingDate) return '—';
        try {
            const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
            const d = new Date(this.task.meetingDate + 'T00:00:00');
            return `${String(d.getDate()).padStart(2,'0')} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
        } catch (e) {
            return this.task.meetingDate;
        }
    }

    handleStatusChange(event) {
        this.status = event.target.value;
    }

    handleDateChange(event) {
        this.dueDate = event.target.value;
        if (this.isCompletedDisabled && this.status === 'Completed') {
            this.status = 'Work in Progress';
        }
    }

    handleCommentChange(event) {
        this.comment = event.target.value;
    }

    handleRejectToggle() {
        this.showRejectForm     = !this.showRejectForm;
        this.rejectComment      = '';
        this.rejectErrorMessage = '';
    }

    handleRejectCommentChange(event) {
        this.rejectComment = event.target.value;
    }

    handleRejectSubmit() {
        if (!this.rejectComment || !this.rejectComment.trim()) {
            this.rejectErrorMessage = 'Please provide a reason before submitting.';
            return;
        }
        this.isLoading          = true;
        this.rejectErrorMessage = '';
        rejectTask({
            taskId:  this.taskId,
            token:   this.token,
            comment: this.rejectComment
        })
            .then(() => {
                this.isRejected = true;
                this.isLoading  = false;
            })
            .catch(error => {
                this.rejectErrorMessage = (error.body && error.body.message)
                    ? error.body.message
                    : 'Failed to submit. Please try again.';
                this.isLoading = false;
            });
    }

    handleSubmit() {
        if (!this.dueDate) {
            this.errorMessage = this.isFirstVisit
                ? 'Please select a Target Date before submitting.'
                : 'Please select a Completion Date before submitting.';
            return;
        }
        if (!this.comment || !this.comment.trim()) {
            this.errorMessage = 'Please fill in the Action Against Assigned Task before submitting.';
            return;
        }
        this.isLoading    = true;
        this.errorMessage = '';
        updateTask({
            taskId:  this.taskId,
            token:   this.token,
            status:  this.status,
            comment: this.comment,
            dueDate: this.dueDate
        })
            .then(() => {
                this.isSubmitted = true;
                this.isLoading   = false;
            })
            .catch(error => {
                this.errorMessage = (error.body && error.body.message)
                    ? error.body.message
                    : 'Failed to update. Please try again.';
                this.isLoading = false;
            });
    }
}