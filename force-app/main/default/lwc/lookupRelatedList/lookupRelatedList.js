/**
 * @File Name          : lookupRelatedList.js
 * @Description        : 
 * @Author             : Jyoti Singh
 * @Group              : 
 * @Last Modified By   : Jyoti Singh
 * @Last Modified On   : 10/10/2019, 3:43:24 PM
 * @Modification Log   : 
 * Ver       Date            Author      		    Modification
 * 1.0    10/10/2019   Jyoti Singh     Initial Version
**/
import { LightningElement,api } from 'lwc';

export default class LookupRelatedList extends LightningElement {

    @api record;
    @api fieldname;
    @api iconname;

    handleSelect(event){
        event.preventDefault();
        const selectedRecord = new CustomEvent(
            "select",
            {
                detail : this.record.Id
            }
        );
        /* eslint-disable no-console */
        //console.log( this.record.Id);
        /* fire the event to be handled on the Parent Component */
        this.dispatchEvent(selectedRecord);
    }
}