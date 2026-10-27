import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getBeatPlanData from '@salesforce/apex/DcrDetailsController.getBeatPlanData';
import startMyDay from '@salesforce/apex/DcrDetailsController.startMyDay';
import endMyDay from '@salesforce/apex/DcrDetailsController.endMyDay';
import checkInEvent from '@salesforce/apex/DcrDetailsController.checkInEvent';
import checkOutEvent from '@salesforce/apex/DcrDetailsController.checkOutEvent';

/**
 * @description Main container component for DCR Details - 70-30 layout
 * @author Priyam Shah
 * @date 2026-01-19
 */
export default class Dcr extends NavigationMixin(LightningElement) {
    @track eventList = [];
    @track userLocation = null;
    @track isSidebarOpen = false;
    @track selectedEventId = null;
    @track beatPlan = null;
    @track isLoading = false;
    @track isInitialLoading = true;
    @track isDayStarted = false;
    @track isDayEnded = false;
    @track showDcrSecondView = false;
    @track checkedInEventId = null;
    @track translations = {}; // Store translations from custom setting
    @track isButtonDisable=false;
    error;

    // Store wire result for refreshApex
    wiredBeatPlanResult;

    connectedCallback() {
        this.getUserLocation();
    }

    @wire(getBeatPlanData)
        wiredBeatPlan(result) {
            this.wiredBeatPlanResult = result;
            if (result.data) {
                this.beatPlan = result.data.beatPlan;
                this.eventList = result.data.events || [];
                this.translations = result.data.translations || {};
                this.isDayStarted = this.beatPlan?.Started__c || false;
                this.isDayEnded = this.beatPlan?.Ended__c || false;
                this.isInitialLoading = false;
            } else if (result.error) {
                this.error = result.error;
                this.isInitialLoading = false;
                console.error('Error loading beat plan data:', result.error);
            }
        }

    // ==================== GETTERS ====================

    get visitCount() {
        return this.eventList ? this.eventList.length : 0;
    }

    get showSpinner() {
        const val = this.isLoading || this.isInitialLoading;
        console.log('showSpinner:', val, 'isLoading:', this.isLoading, 'isInitialLoading:', this.isInitialLoading);
        return val;
    }

    get menuIconName() {
        return this.isSidebarOpen ? 'utility:close' : 'utility:rows';
    }

    get sidebarClass() {
        return this.isSidebarOpen
            ? 'visit-list-section sidebar-open'
            : 'visit-list-section';
    }

    /**
     * @description Can start day if beat plan exists, not started, not ended, and has location
     */
    get canStartDay() {
        return this.beatPlan && !this.isDayStarted && !this.isDayEnded;
    }

    /**
     * @description Can end day if day is started and not ended
     */
    get canEndDay() {
        return this.beatPlan && this.isDayStarted && !this.isDayEnded;
    }

    /**
     * @description Check if all events have been checked out
     */
    get allEventsCompleted() {
        // If no events, they're "all completed"
        if (!this.eventList || this.eventList.length === 0) {
            return true;
        }
        // All events should have Check_Out__c = true
        return this.eventList.every(event => event.Check_Out__c === true);
    }

    /**
     * @description Check if there are incomplete events
     */
    get hasIncompleteEvents() {
        return this.eventList && this.eventList.length > 0;
    }

    /**
     * @description Check if there's no beat plan for today
     */
    get noBeatPlan() {
        return !this.beatPlan && !this.isLoading;
    }

    // ==================== SIDEBAR HANDLERS ====================

    toggleSidebar() {
        this.isSidebarOpen = !this.isSidebarOpen;
    }

    /**
     * @description Handle event selection from visit list - focuses map on selected marker
     */
    handleEventSelect(event) {
        const eventId = event.detail.eventId;
        console.log('dcrDetails received event selection:', eventId);

        // Reset to null first to ensure setter fires even for same value
        this.selectedEventId = null;

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.selectedEventId = eventId;
        }, 0);

        // On mobile, close the sidebar after selection so user can see the map
        if (window.innerWidth <= 768) {
            this.isSidebarOpen = false;
        }
    }

    // ==================== START/END DAY HANDLERS ====================

    /**
     * @description Handle Start My Day button click
     */
    async handleStartMyDay() {
        if (!this.userLocation) {
            this.showToast('Error', 'Unable to get your location. Please enable location services.', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const result = await startMyDay({
                latitude: this.userLocation.latitude,
                longitude: this.userLocation.longitude
            });

            if (result.success) {
                const message = this.translations.You_have_started_your_day__c || 'Day started successfully!';
                this.showToast('Success', message, 'success');
                await refreshApex(this.wiredBeatPlanResult);
            } else {
                this.handleErrorResponse(result);
            }
        } catch (error) {
            console.error('Error starting day:', error);
            const message = this.translations.Failed_to_end_your_day__c || 'Failed to start day';
            this.showToast('Error', error.body?.message || message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * @description Handle End My Day button click
     */
    async handleEndMyDay() {
        if (!this.userLocation) {
            this.showToast('Error', 'Unable to get your location. Please enable location services.', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const result = await endMyDay({
                latitude: this.userLocation.latitude,
                longitude: this.userLocation.longitude
            });

            if (result.success) {
                const distanceMsg = result.totalDistance
                    ? ` Total distance: ${result.totalDistance.toFixed(2)} km`
                    : '';
                const message = this.translations.You_have_Ended_your_day__c || 'Day ended successfully!';
                this.showToast('Success', `${message}${distanceMsg}`, 'success');
                await refreshApex(this.wiredBeatPlanResult);
            } else {
                this.handleErrorResponse(result);
            }
        } catch (error) {
            console.error('Error ending day:', error);
            const message = this.translations.Failed_to_end_your_day__c || 'Failed to end day';
            this.showToast('Error', error.body?.message || message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ==================== CHECK-IN/OUT HANDLERS ====================

    /**
     * @description Handle check-in event from visit list component
     */
    async handleCheckIn(event) {
        const { eventId, meetingType } = event.detail;

        if (!this.userLocation) {
            this.showToast('Error', 'Unable to get your location. Please enable location services.', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const result = await checkInEvent({
                eventId: eventId,
                latitude: this.userLocation.latitude,
                longitude: this.userLocation.longitude
            });

            if (result.success) {
                const startLabel = this.translations.Start__c || 'Started';
                const checkInLabel = this.translations.Check_IN__c || 'Checked in';
                const label = meetingType === 'Online' ? startLabel : checkInLabel;
                this.showToast('Success', `${label} successfully!`, 'success');
                await refreshApex(this.wiredBeatPlanResult);

                // Show DCR Details Second view for DCR entry
                this.checkedInEventId = eventId;

                // Force component destruction and recreation by toggling off then on
                this.showDcrSecondView = false;
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => {
                    this.showDcrSecondView = true;
                }, 0);
            } else {
                this.handleErrorResponse(result);
            }
        } catch (error) {
            console.error('Error checking in:', error);
            const message = this.translations.Checkin_Not_available_now__c || 'Check-in failed';
            this.showToast('Error', error.body?.message || message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * @description Handle check-out event from visit list component (not typically used - submit does checkout)
     */
    async handleCheckOut(event) {
        const { eventId, meetingType } = event.detail;

        if (!this.userLocation) {
            this.showToast('Error', 'Unable to get your location. Please enable location services.', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const result = await checkOutEvent({
                eventId: eventId,
                latitude: this.userLocation.latitude,
                longitude: this.userLocation.longitude
            });

            if (result.success) {
                const endLabel = this.translations.End__c || 'Ended';
                const checkOutLabel = this.translations.Check_Out__c || 'Checked out';
                const label = meetingType === 'Online' ? endLabel : checkOutLabel;
                this.showToast('Success', `${label} successfully!`, 'success');
                await refreshApex(this.wiredBeatPlanResult);
            } else {
                this.handleErrorResponse(result);
            }
        } catch (error) {
            console.error('Error checking out:', error);
            this.showToast('Error', error.body?.message || 'Check-out failed', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * @description Handle continue event from visit list - reopens DCR form for checked-in event
     */
    handleContinue(event) {
        const { eventId } = event.detail;
        console.log('Continue clicked for event:', eventId);

        // Show DCR Details Second view to continue DCR entry
        this.checkedInEventId = eventId;

        // Force component destruction and recreation by toggling off then on
        this.showDcrSecondView = false;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.showDcrSecondView = true;
        }, 0);
    }

    // ==================== DCR VIEW HANDLERS ====================

    /**
     * @description Handle back navigation from DCR second view
     */
    handleBackFromDcr() {
        this.showDcrSecondView = false;
        this.checkedInEventId = null;
        // Refresh data to show updated event statuses
        refreshApex(this.wiredBeatPlanResult);
    }

    // ==================== HELPER METHODS ====================

    /**
     * @description Handle error responses from Apex methods
     */
    handleErrorResponse(result) {
        const message = result.message || 'An error occurred';
        const warningTitle = this.translations.warning__c || 'Warning';

        switch (result.errorType) {
            case 'NO_BEAT_PLAN':
                const noBeatPlanMsg = this.translations.There_is_no_beat_plan_for_today__c || 'No beat plan exists for today';
                this.showToast('Error', noBeatPlanMsg, 'error');
                break;
            case 'NO_CLOCK_IN':
                const noClockInMsg = this.translations.Kindly_start_your_day_before_check_in__c || message;
                this.showToast(warningTitle, noClockInMsg, 'warning');
                break;
            case 'DAY_NOT_STARTED':
                const dayNotStartedMsg = this.translations.Kindly_start_your_day_before_check_in__c || 'Please start your day first';
                this.showToast(warningTitle, dayNotStartedMsg, 'warning');
                break;
            case 'TOO_FAR':
                // Use message from server as it contains actual distance information
                this.showToast(warningTitle, message, 'warning');
                break;
            case 'APPROVAL_PENDING':
                const approvalMsg = this.translations.Approval_process_pending_error__c || 'Approval process is pending on the beat plan';
                this.showToast(warningTitle, approvalMsg, 'warning');
                break;
            case 'ALREADY_STARTED':
            case 'ALREADY_ENDED':
            case 'ALREADY_CHECKED_IN':
            case 'ALREADY_CHECKED_OUT':
            case 'NOT_CHECKED_IN':
                this.showToast('Info', message, 'info');
                break;
            default:
                this.showToast('Error', message, 'error');
        }
    }

    /**
     * @description Show toast notification
     */
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }

    /**
     * @description Get user's current geolocation
     */
    getUserLocation() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    this.userLocation = {
                        latitude: position.coords.latitude,
                        longitude: position.coords.longitude
                    };
                    if(this.userLocation.latitude && this.userLocation.longitude){
                        this.isButtonDisable=true;
                    }
                },
                (error) => {
                    console.error('Geolocation error:', error.message);
                    this.userLocation = null;
                },
                {
                    enableHighAccuracy: true,
                    timeout: 10000,
                    maximumAge: 0
                }
            );
        }
    }
}