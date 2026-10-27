import { LightningElement, track } from 'lwc';

import { NavigationMixin } from 'lightning/navigation';

export default class ClockInOutComponent extends NavigationMixin(LightningElement) {
    @track isClockedIn = false;
    @track clockInTime = null;
    @track timePassed = '00:00:00';

    handleClockIn() {
        if (!this.isClockedIn) {
            this.isClockedIn = true;
            this.clockInTime = new Date();
            // this.startTimer();
        }
    }

    handleClockOut() {
        if (this.isClockedIn) {
            this.isClockedIn = false;
            this.clockInTime = null;
            // this.stopTimer();
        }
    }

 
    @track formattedDateTime;

    connectedCallback() {
        this.updateDateTime();
        // Update every second
        setInterval(() => {
            this.updateDateTime();
        }, 1000);
    }

    updateDateTime() {
        const now = new Date();
        this.formattedDateTime = this.formatDateTime(now);
    }

    formatDateTime(date) {
        const options = { 
            year: 'numeric', 
            month: 'short', 
            day: '2-digit', 
            hour: '2-digit', 
            minute: '2-digit', 
            second: '2-digit', 
            hour12: true 
        };
        return date.toLocaleString('en-UK', options).replace(',', ''); // Remove comma
    }

    
    navigateToTabPage() {
        // Navigate to a specific CustomTab.
        // this[NavigationMixin.Navigate]({
        //   type: "standard__navItemPage",
        //   attributes: {
        //     // CustomTabs from managed packages are identified by their
        //     // namespace prefix followed by two underscores followed by the
        //     // developer name. E.g. 'namespace__TabName'
        //     apiName: "Event_Planner",
        //   },
        // });
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Event',
                actionName: 'home',
            },
        });
      }
}