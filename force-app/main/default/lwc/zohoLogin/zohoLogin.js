import { LightningElement } from 'lwc';
import Zoho_IdP_Initiated_Login_URL from '@salesforce/label/c.Zoho_IdP_Initiated_Login_URL';

export default class ZohoLogin extends LightningElement {
    loginURL = Zoho_IdP_Initiated_Login_URL;
}