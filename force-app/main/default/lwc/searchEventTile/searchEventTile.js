/* eslint-disable no-console */
import { LightningElement, api, track} from 'lwc';

export default class searchEventTile extends LightningElement {
    @api event;
    @track showDetailModal = false;

    renderedCallback(){
        console.log("Events In Event Tile ", this.event);
        
    }
    
    cardClick() {
    console.log('Click Card');
        this.showDetailModal = true;
    }
    closeModal() {
        this.showDetailModal = false;
    }
}