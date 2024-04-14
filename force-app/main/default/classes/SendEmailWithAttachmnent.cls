public without sharing class SendEmailWithAttachmnent {
    
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static void sendEmail(case lscase){
        List<ContentDocumentLink> caseDocumentLinks = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId =: lscase.Id];
        
        set<Id> sId = new set<Id>();
        for(ContentDocumentLink cd : caseDocumentLinks ){
            sId.add(cd.ContentDocumentId);
        }
        
        List<ContentDocument> caseDocuments = [
            SELECT Id, Title, FileExtension
            FROM ContentDocument
            WHERE Id IN :sId
        ];
        
        // Assuming you want to send an email to a specific recipient with the attachment
        String recipientEmail = 'raghujha.aj@gmail.com';
        String subject = 'Attachment from Salesforce';
        String body = 'Please find the attached file from Salesforce.';
        
        // Create an email message
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[]{recipientEmail});
        email.setSubject(subject);
        email.setPlainTextBody(body);
        
        // Attach the ContentDocument to the email
        for (ContentDocument document : caseDocuments) {
            
            // Query ContentVersion to get the file content
            ContentVersion contentVersion = [
                SELECT VersionData
                FROM ContentVersion
                WHERE ContentDocumentId = :document.Id
                LIMIT 1
            ];
            
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName(document.Title + '.' + document.FileExtension);
            attachment.setBody(contentVersion.VersionData); // Assuming ContentDocument.Body is the file content
            email.setFileAttachments(new Messaging.EmailFileAttachment[]{attachment});
        }
        
        // Send the email
        Messaging.SendEmailResult[] result = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
        
        // Check the result
        if (result[0].success) {
            System.debug('Email sent successfully');
        } else {
            System.debug('Email sending failed. Error: ' + result[0].errors[0].message);
        }
        
    }

    /**
     * Send out the attachments to the specified email and save it as the activity
     * @param {String} recordId The Id of the target startup object, which files we should attach to the email
     * @param {String} emailAddress The email address of the recipient
     */
    @AuraEnabled
    public static Result sendEmailWithAttachment(String recordId, String emailAddress) {
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        Result result = new Result();

        // Set the recipient address
        message.setToAddresses(new String[] { emailAddress });
        // Attach files to the message
        List<Attachment> files = [SELECT Name, Body, ContentType FROM Attachment WHERE ParentId = :recordId WITH SYSTEM_MODE];

        List<Messaging.EmailFileAttachment> attachmentsList = new List<Messaging.EmailFileAttachment>();
        for (Attachment file: files) {
            Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
            efa.setFileName(file.Name);
            efa.setBody(file.Body);
            efa.setContentType(file.ContentType);
            attachmentsList.add(efa);
        }
        message.setFileAttachments(attachmentsList);
        // Set the message template
        message.setSubject('Apex SingleEmailMessage Email with Attachments.');
        message.setHtmlBody('Please find the attached Document for your reference');

        // Set the message sender address
        List<OrgWideEmailAddress> addresses = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'info@digitalflask.com' WITH SYSTEM_MODE];
        if (!addresses.isEmpty()) {
            message.setOrgWideEmailAddressId(addresses[0].Id);
        } else {
            message.setSenderDisplayName('Apex SingleEmailMessage');
        }
        // Save the message as activity
        message.setWhatId(recordId);
        message.setSaveAsActivity(true);
        // Send the message
        try {
            Messaging.SendEmailResult[] sendResults = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { message });

            System.debug('sendResults:: ' + sendResults);

            result.isSuccess = sendResults[0].success;

            if(!result.isSuccess) {
                result.errorMessage = '';
                for(Messaging.SendEmailError error : sendResults[0].getErrors()){
                    result.errorMessage += error.getMessage() + ';';
                }
            }
        } catch (Exception e) {
            System.debug('##Exception:: ' + e.getMessage() + ' \n Casuse:: ' + e.getCause());
            throw new AuraHandledException(e.getMessage());
        }
        return result;
    }

    /**
     * Result
     */
    public class Result {
        public Boolean isSuccess;
        public String errorMessage;
    }
    
}