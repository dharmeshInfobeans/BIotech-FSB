/**
 * EventFormData model class
 * Typed data structure for event form fields
 */

export class EventFormData {
    constructor() {
        this.relatedTo = '';
        this.date = '';
        this.subject = '';
        this.meetingType = '';
        this.callType = '';
        this.levelType = '';
        this.product = '';
        this.jointAssignee = false;
        this.users = '';
        this.notes = '';
        this.leaveType = '';
        this.reviewCallType = '';
        this.contact = '';
        this.ownerId = '';
        this.eventType = '';
        this.subCallType = '';
    }

    /**
     * Converts the form data to a plain object for Apex
     * @returns {Object} Plain object representation
     */
    toApexMap() {
        return {
            relatedTo: this.relatedTo,
            date: this.date,
            subject: this.subject,
            MeetingType: this.meetingType,
            CallType: this.callType,
            levelType: this.levelType,
            product: this.product,
            jointassignee: this.jointAssignee,
            users: this.users,
            notes: this.notes,
            leaveOptions: this.leaveType,
            reviewCallType: this.reviewCallType,
            contact: this.contact,
            ownerid: this.ownerId,
            eventType: this.eventType,
            subCallType: this.subCallType
        };
    }
}