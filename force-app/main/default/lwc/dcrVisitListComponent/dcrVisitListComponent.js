import { LightningElement, api,track } from 'lwc';
import CHECK_IN_DISTANCE_LIMIT from '@salesforce/label/c.check_in_Distance_Warning';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

/**
 * @description Visit list component displaying event cards with SLDS 2
 * @author Priyam Shah
 * @date 2026-01-19
 */
export default class DcrVisitListComponent extends LightningElement {
    _eventList = [];
    _isDayStarted = false;
    _isDayEnded = false;
    _canStartDay = false;
    _canEndDay = false;
    _isLoading = false;
    @api isButtonDisable=false;
    @track userLocation;

    get getisButtonDisable(){
        return !this.isButtonDisable;
    }

    @api
    get eventList() {
        console.log('this._eventList',this._eventList);
        return this._eventList;
    }
    set eventList(value) {
        this._eventList = value || [];
    }

    @api
    get isDayStarted() {
        return this._isDayStarted;
    }
    set isDayStarted(value) {
        this._isDayStarted = value || false;
    }

    @api
    get isDayEnded() {
        return this._isDayEnded;
    }
    set isDayEnded(value) {
        this._isDayEnded = value || false;
    }

    @api
    get canStartDay() {
        return this._canStartDay;
    }
    set canStartDay(value) {
        this._canStartDay = value || false;
    }

    @api
    get canEndDay() {
        return this._canEndDay;
    }
    set canEndDay(value) {
        this._canEndDay = value || false;
    }

    @api
    get isLoading() {
        return this._isLoading;
    }
    set isLoading(value) {
        this._isLoading = value || false;
    }

    /**
     * @description Returns enhanced event list with computed display properties
     * Using getter ensures it recomputes when _eventList changes
     */
    // get enhancedEventList() {
    //     if (!this._eventList || this._eventList.length === 0) {
    //         return [];
    //     }
    //     return this._eventList.map((event, index) => ({
    //         ...event,
    //         visitNumber: index + 1,
    //         isLead: event.Leads__c != null,
    //         isOpportunity: (event.Opportunity__c != null) || (event.WhatId != null && event.What?.Type === 'Opportunity__c'),
    //         displayName: this.getDisplayName(event),
    //         displayAddress: this.formatAddress(event),
    //         formattedTime: this.formatTime(event.StartDateTime),
    //         // Lead and Opportunity stage labels
    //         leadStageLabel: this.getLeadStageLabel(event),
    //         opportunityStageLabel: this.getOpportunityStageLabel(event),
    //         // Meeting type flags
    //         isOnsite: event.Meeting_Type__c === 'Onsite',
    //         isOffsite: event.Meeting_Type__c === 'Offsite',
    //         isOnline: event.Meeting_Type__c === 'Online',
    //         // Status flags
    //         isCheckedIn: event.Cheked_In__c === true,
    //         isCheckedOut: event.Check_Out__c === true,
    //         // Button visibility - show check-in if not already checked in (parent handles day started validation)
    //         canCheckIn: event.Cheked_In__c !== true,
    //         // Show continue button if checked in but not checked out (user can resume DCR entry)
    //         canContinue: event.Cheked_In__c === true && event.Check_Out__c !== true,
    //         // Labels based on meeting type: Online uses Start/End, others use Check-In/Check-Out
    //         checkInLabel: event.Meeting_Type__c === 'Online' ? 'Start' : 'Check-In',
    //         continueLabel: 'Continue',
    //         // Status display
    //         statusLabel: this.getStatusLabel(event),
    //         statusClass: this.getStatusClass(event),
    //         // Card styling class
    //         cardClass: this.getCardClass(event)
    //     }));
    // }
    connectedCallback() {
        // Fetch location when the component loads
        this.getUserLocation();
    }
    getUserLocation() {
        console.log('on user location function')
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    this.userLocation = {
                        latitude: position.coords.latitude,
                        longitude: position.coords.longitude
                    };
                },
                (error) => {
                    console.error('Error getting location: ', error);
                },
                { 
                    enableHighAccuracy: true,
                    timeout: 10000,
                    maximumAge: 0 
                }
            );
        } else {
            console.error('Geolocation is not supported by this browser.');
        }
    }
    calculateDistanceInMeters(lat1, lon1, lat2, lon2) {
        if (!lat1 || !lon1 || !lat2 || !lon2) {
            // Return a very high number if any coordinate is missing so it defaults to disabled
            return Infinity; 
        }

        const R = 6371e3; // Earth's radius in meters
        const phi1 = (lat1 * Math.PI) / 180;
        const phi2 = (lat2 * Math.PI) / 180;
        const deltaPhi = ((lat2 - lat1) * Math.PI) / 180;
        const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

        const a = 
            Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
            Math.cos(phi1) * Math.cos(phi2) *
            Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
            
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        return R * c; // Returns distance in meters
    }
//    get enhancedEventList() {
//         if (!this._eventList || this._eventList.length === 0) {
//             return [];
//         }
//         const distanceLimitKm = parseFloat(CHECK_IN_DISTANCE_LIMIT) || 5;
//         console.log('distanceLimitKm',distanceLimitKm);
//         const distanceLimitMeters = distanceLimitKm * 1000;
        
//         return this._eventList.map((event, index) => {
            
//             // 1. Start with the global lock state (true if still initializing)
//             let isCheckInDisabled = this.getisButtonDisable;
            
//             // 2. Only restrict check-ins for non-online meetings if global lock is off and we have location
//             if ( event.Meeting_Type__c !== 'Online' && this.userLocation) {
                
//                 // FIXED: Using the exact field names from your JSON data
//                 const eventLat = event.Event_Latitude__c; 
//                 const eventLng = event.Event_Longitude__c;

//                 if (eventLat && eventLng && eventLat !== 0 && eventLng !== 0) {
//                     const distance = this.calculateDistanceInMeters(
//                         this.userLocation.latitude,
//                         this.userLocation.longitude,
//                         eventLat,
//                         eventLng
//                     );
//                     console.log('distance',distance,'distanceLimitMeters',distanceLimitMeters);
//                     console.log(' this.userLocation.latitude', this.userLocation.latitude , 'this.userLocation.longitude',this.userLocation.longitude);
                    
//                     // Using 5000 for your current testing. 
//                     // Change this back to 500 for production!
//                     isCheckInDisabled = distance > distanceLimitMeters;
//                 } else {
//                     // Disable if event has no coordinates to check against
//                     isCheckInDisabled = true; 
//                 }
//             }

//             return {
//                 ...event,
//                 visitNumber: index + 1,
//                 isLead: event.Leads__c != null,
//                 isOpportunity: (event.Opportunity__c != null) || (event.WhatId != null && event.What?.Type === 'Opportunity__c'),
//                 displayName: this.getDisplayName(event),
//                 displayAddress: this.formatAddress(event),
//                 formattedTime: this.formatTime(event.StartDateTime),
//                 leadStageLabel: this.getLeadStageLabel(event),
//                 opportunityStageLabel: this.getOpportunityStageLabel(event),
                
//                 // Meeting type flags
//                 isOnsite: event.Meeting_Type__c === 'Onsite',
//                 isOffsite: event.Meeting_Type__c === 'Offsite',
//                 isOnline: event.Meeting_Type__c === 'Online',
                
//                 // Status flags
//                 isCheckedIn: event.Cheked_In__c === true,
//                 isCheckedOut: event.Check_Out__c === true,
//                 canCheckIn: event.Cheked_In__c !== true,
                
//                 // FINAL HTML FLAG: disabled={event.isCheckInDisabled}
//                 isCheckInDisabled: isCheckInDisabled,
                
//                 canContinue: event.Cheked_In__c === true && event.Check_Out__c !== true,
//                 checkInLabel: event.Meeting_Type__c === 'Online' ? 'Start' : 'Check-In',
//                 continueLabel: 'Continue',
//                 statusLabel: this.getStatusLabel(event),
//                 statusClass: this.getStatusClass(event),
//                 cardClass: this.getCardClass(event)
//             };
//         });
//     }
get enhancedEventList() {
        if (!this._eventList || this._eventList.length === 0) {
            return [];
        }

        // 1. Parse the Custom Label (e.g. "5.00") into a float.
        // Fallback to 5 KM just in case the label is empty, invalid, or missing.
        const distanceLimitKm = parseFloat(CHECK_IN_DISTANCE_LIMIT) || 5;
        
        // 2. Convert Kilometers to Meters for the Haversine calculation
        const distanceLimitMeters = distanceLimitKm * 1000;
        
        return this._eventList.map((event, index) => {
            
            // Start with the global lock state (true if still initializing)
            let isCheckInDisabled = this.getisButtonDisable;
            
            // Only restrict check-ins for non-online meetings if global lock is off and we have user location
            if (!this.getisButtonDisable && event.Meeting_Type__c !== 'Online' && this.userLocation) {
                
                const eventLat = event.Event_Latitude__c; 
                const eventLng = event.Event_Longitude__c;

                // Check if we have valid, non-zero coordinates
                if (eventLat && eventLng && eventLat !== 0 && eventLng !== 0) {
                    
                    const distance = this.calculateDistanceInMeters(
                        this.userLocation.latitude,
                        this.userLocation.longitude,
                        eventLat,
                        eventLng
                    );
                    
                    // Disable button if distance is greater than the allowed meters
                    isCheckInDisabled = distance > distanceLimitMeters;
                    
                } else {
                    // IF EVENT COORDINATES ARE 0 OR MISSING: 
                    // Set to false (Enable Button) so the rep isn't blocked by bad Salesforce data
                    isCheckInDisabled = false; 
                }
            }

            // Return the fully mapped object for the HTML template
            return {
                ...event,
                visitNumber: index + 1,
                isLead: event.Leads__c != null,
                isOpportunity: (event.Opportunity__c != null) || (event.WhatId != null && event.What?.Type === 'Opportunity__c'),
                displayName: this.getDisplayName(event),
                displayAddress: this.formatAddress(event),
                formattedTime: this.formatTime(event.StartDateTime),
                
                // Lead and Opportunity stage labels
                leadStageLabel: this.getLeadStageLabel(event),
                opportunityStageLabel: this.getOpportunityStageLabel(event),
                
                // Meeting type flags
                isOnsite: event.Meeting_Type__c === 'Onsite',
                isOffsite: event.Meeting_Type__c === 'Offsite',
                isOnline: event.Meeting_Type__c === 'Online',
                
                // Status flags
                isCheckedIn: event.Cheked_In__c === true,
                isCheckedOut: event.Check_Out__c === true,
                canCheckIn: event.Cheked_In__c !== true,
                
                // NEW: Bound to disabled attribute or used in toast logic
                isCheckInDisabled: isCheckInDisabled,
                
                // Show continue button if checked in but not checked out (user can resume DCR entry)
                canContinue: event.Cheked_In__c === true && event.Check_Out__c !== true,
                
                // Labels based on meeting type: Online uses Start/End, others use Check-In/Check-Out
                checkInLabel: event.Meeting_Type__c === 'Online' ? 'Start' : 'Check-In',
                continueLabel: 'Continue',
                
                // Status display
                statusLabel: this.getStatusLabel(event),
                statusClass: this.getStatusClass(event),
                
                // Card styling class
                cardClass: this.getCardClass(event)
            };
        });
    }

    get hasEvents() {
        return this._eventList && this._eventList.length > 0;
    }

    get visitCount() {
        return this._eventList ? this._eventList.length : 0;
    }

    // ==================== STATUS HELPERS ====================

    /**
     * @description Get status label based on event state
     */
    getStatusLabel(event) {
        if (event.Check_Out__c === true) {
            return 'Completed';
        }
        if (event.Cheked_In__c === true) {
            return 'In Progress';
        }
        return 'Scheduled';
    }

    /**
     * @description Get status badge class based on event state
     */
    getStatusClass(event) {
        if (event.Check_Out__c === true) {
            return 'slds-badge slds-theme_inverse status-badge';
        }
        if (event.Cheked_In__c === true) {
            return 'slds-badge slds-theme_success status-badge';
        }
        return 'slds-badge status-badge';
    }

    /**
     * @description Get card class based on event state
     */
    getCardClass(event) {
        let baseClass = 'slds-card slds-var-m-bottom_small visit-card';
        if (event.Check_Out__c === true) {
            return `${baseClass} visit-card--completed`;
        }
        if (event.Cheked_In__c === true) {
            return `${baseClass} visit-card--in-progress`;
        }
        return baseClass;
    }

    // ==================== FORMAT HELPERS ====================

    formatAddress(event) {
        const street = event.BillingStreet__c || '';
        const city = event.BillingCity__c || '';

        if (street && city) {
            return `${street}, ${city}`;
        }
        if (street) {
            return street;
        }
        if (city) {
            return city;
        }
        return 'No address available';
    }

    formatTime(dateTimeString) {
        if (!dateTimeString) {
            return '';
        }
        try {
            const dateTime = new Date(dateTimeString);
            return dateTime.toLocaleTimeString('en-US', {
                hour: 'numeric',
                minute: '2-digit',
                hour12: true
            });
        } catch (e) {
            return '';
        }
    }

    /**
     * @description Get display name based on event type (Lead, Opportunity, or Account)
     */
    getDisplayName(event) {
        if (event.Leads__c != null) {
            return event.Leads__r?.Name || 'Lead';
        } else if (event.WhatId != null && event.What?.Type === 'Opportunity__c') {
            return event.What?.Name || 'Opportunity';
        } else if (event.Account__c != null) {
            return event.Account__r?.Name || 'Account';
        }
        return 'Unknown';
    }

    /**
     * @description Get lead stage label for badge display
     */
    getLeadStageLabel(event) {
        if (event.Leads__c != null && event.Leads__r?.Lead_Stage__c) {
            return `Lead Stage: ${event.Leads__r.Lead_Stage__c}`;
        }
        return 'Lead';
    }

    /**
     * @description Get opportunity stage label for badge display
     */
    getOpportunityStageLabel(event) {
        // Check custom Opportunity__c lookup field first
        if (event.Opportunity__c != null && event.Opportunity__r?.Status__c) {
            return `Opportunity Stage: ${event.Opportunity__r.Status__c}`;
        }
        // Check standard WhatId for legacy opportunities
        if (event.WhatId != null && event.What?.Type === 'Opportunity__c') {
            // Note: Status is not available via standard WhatId polymorphic relationship
            // Would need to be queried separately in the controller if needed
            return 'Opportunity';
        }
        return 'Opportunity';
    }

    // ==================== EVENT HANDLERS ====================

    /**
     * @description Handle click on visit card - dispatches event to focus map marker
     */
    handleCardClick(event) {
        const eventId = event.currentTarget.dataset.id;
        console.log('Visit card clicked, event ID:', eventId);

        // Dispatch custom event to parent component
        this.dispatchEvent(new CustomEvent('selectevent', {
            detail: { eventId },
            bubbles: true,
            composed: true
        }));
    }

    /**
     * @description Handle check-in button click
     */
    handleCheckIn(event) {
        // Stop propagation to prevent card click from firing
        event.stopPropagation();

        const eventId = event.currentTarget.dataset.id;
        const meetingType = event.currentTarget.dataset.meetingtype;
        const selectedEvent = this.enhancedEventList.find(e => e.Id === eventId);
        if (selectedEvent && selectedEvent.isCheckInDisabled) {
            // Get the KM value from the label (fallback to "5" for safety)
            const limitStr = CHECK_IN_DISTANCE_LIMIT || '5';
            
            // Dispatch a Toast showing exactly what the limit is!
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Too Far Away',
                    message: `You must be within ${limitStr} KM of the location to check in.`,
                    variant: 'error',
                    mode: 'dismissable'
                })
            );
            return; // Stop execution
        }

        console.log('Check-in clicked for event:', eventId, 'Meeting type:', meetingType);

        // Dispatch check-in event to parent
        this.dispatchEvent(new CustomEvent('checkin', {
            detail: { eventId, meetingType },
            bubbles: true,
            composed: true
        }));
    }

    /**
     * @description Handle check-out button click (not used - submit from DCR form checks out)
     */
    handleCheckOut(event) {
        // Stop propagation to prevent card click from firing
        event.stopPropagation();

        const eventId = event.currentTarget.dataset.id;
        const meetingType = event.currentTarget.dataset.meetingtype;
       
        console.log('Check-out clicked for event:', eventId, 'Meeting type:', meetingType);

        // Dispatch check-out event to parent
        this.dispatchEvent(new CustomEvent('checkout', {
            detail: { eventId, meetingType },
            bubbles: true,
            composed: true
        }));
    }

    /**
     * @description Handle continue button click - resumes DCR entry for checked-in event
     */
    handleContinue(event) {
        // Stop propagation to prevent card click from firing
        event.stopPropagation();

        const eventId = event.currentTarget.dataset.id;
        const meetingType = event.currentTarget.dataset.meetingtype;
        console.log('this.enhancedEventList',this.enhancedEventList,'eventId',eventId);
        const selectedEvent = this.enhancedEventList.find(e => e.Id === eventId);
        if (selectedEvent && selectedEvent?.isCheckInDisabled) {
            // Get the KM value from the label (fallback to "5" for safety)
            const limitStr = CHECK_IN_DISTANCE_LIMIT || '5';
            
            // Dispatch a Toast showing exactly what the limit is!
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Too Far Away',
                    message: `You must be within ${limitStr} KM of the location to continue.`,
                    variant: 'error',
                    mode: 'dismissable'
                })
            );
            return; // Stop execution
        }
        
      

        console.log('Continue clicked for event:', eventId, 'Meeting type:', meetingType);

        // Dispatch continue event to parent - same as check-in to open DCR view
        this.dispatchEvent(new CustomEvent('continue', {
            detail: { eventId, meetingType },
            bubbles: true,
            composed: true
        }));
    }

    /**
     * @description Handle Start Day button click
     */
    handleStartDay() {
        this.dispatchEvent(new CustomEvent('startday', {
            bubbles: true,
            composed: true
        }));
    }

    /**
     * @description Handle End Day button click
     */
    handleEndDay() {
        this.dispatchEvent(new CustomEvent('endday', {
            bubbles: true,
            composed: true
        }));
    }
}