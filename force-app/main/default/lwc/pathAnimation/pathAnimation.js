import { LightningElement, track } from 'lwc';

export default class PathAnimation extends LightningElement {
    @track status = '';
    @track showAnimation = false;

    handleStatusChange(event) {
        this.status = event.target.value;

        // Trigger animation if the status is the final stage
        if(this.status === 'Completed' || this.status === 'Won') {
            this.showAnimation = true;

            // Hide the animation after a short duration
            setTimeout(() => {
                this.showAnimation = false;
            }, 5000); // 5 seconds
        }
    }
}