public class ReportEmailBatch implements Database.Batchable<SObject>,Database.AllowsCallouts {
    public String reportId;
    public List<String> emailAddresses;
    public String emailSubject;
    public String emailBody;
    public String  fileFormat; // "csv", "xls", or "xlsx"

    public ReportEmailBatch(String reportId, List<String> emailAddresses, String emailSubject, String emailBody,String fileFormat ) {
        this.reportId = reportId;
        this.emailAddresses = emailAddresses;
        this.emailSubject = emailSubject;
        this.emailBody = emailBody;
        this.fileFormat = fileFormat;  // String.isBlank(fileFormat) ? 'xlsx' : fileFormat.toLowerCase();
      //  this.fileFormat = 'xlsx'; // or 'csv', or 'xls'

    }

    public void execute(Database.BatchableContext bc, List<Report> reports) {
        if (reports.isEmpty()) {
            System.debug('No report found with Id: ' + reportId);
            return;
            
        }

        Report report = reports[0];
        try {
            if (fileFormat == 'xlsx') {
            sendAsXlsx(report);
        } else if (fileFormat == 'xls') {
            sendAsXls(report);
        } else if (fileFormat == 'csv') {
            sendAsCsv(report);
        }
        system.debug(fileFormat+'send succesfuly');
        } catch (Exception e) {
            system.debug('Error sending report as ' + fileFormat + ': ' + e.getMessage());
        }
        
    }

    private void sendAsCsv(Report report) {
        try {
            ApexPages.PageReference pageRef = new ApexPages.PageReference('/' + report.Id + '?csv=1&isdtp=p1');
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName(report.Name + '.csv');
            if (!Test.isRunningTest()) {
                attachment.setBody(pageRef.getContent());
            }
            attachment.setContentType('text/csv');

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setUseSignature(false);
            mail.setToAddresses(emailAddresses);
            mail.setSubject(emailSubject);
            mail.setHtmlBody(emailBody);
            mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{attachment});

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        } catch (Exception e) {
            System.debug('Error sending CSV: ' + e.getMessage());
        }
    }

    private void sendAsXls(Report report) {
        try {
            ApexPages.PageReference pageRef = new ApexPages.PageReference('/' + report.Id + '?csv=1&isdtp=p1');
            Blob csvBlob = Test.isRunningTest() ? Blob.valueOf('Header1,Header2\nVal1,Val2') : pageRef.getContent();
            String csvString = csvBlob.toString();
            String excelXml = '<?xml version="1.0"?>\n' +
                '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:o="urn:schemas-microsoft-com:office:office"' +
                ' xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet" xmlns:html="http://www.w3.org/TR/REC-html40">\n' +
                '<Worksheet ss:Name="Report">\n<Table>\n';

            for (String line : csvString.split('\n')) {
                if (String.isBlank(line)) continue;
                excelXml += '<Row>\n';
                for (String cell : line.split(',')) {
                    String clean = cell.replace('"', '').replace('""', '"').trim();
                    excelXml += '<Cell><Data ss:Type="String">' + clean.escapeXml() + '</Data></Cell>\n';
                }
                excelXml += '</Row>\n';
            }

            excelXml += '</Table></Worksheet></Workbook>';
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName(report.Name + '.xls');
            attachment.setContentType('application/vnd.ms-excel');
            attachment.setBody(Blob.valueOf(excelXml));

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setUseSignature(false);
            mail.setToAddresses(emailAddresses);
            mail.setSubject(emailSubject);
            mail.setHtmlBody(emailBody);
            mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{attachment});

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        } catch (Exception e) {
            System.debug('Error sending XLS: ' + e.getMessage());
        }
    }

    private void sendAsXlsx(Report report) {
        try {
            ApexPages.PageReference pageRef = new ApexPages.PageReference('/' + report.Id + '?csv=1&isdtp=p1');
            Blob csvBlob = Test.isRunningTest() ? Blob.valueOf('Header1,Header2\nVal1,Val2') : pageRef.getContent();
            List<String> csvLines = csvBlob.toString().split('\n');
            List<String> headers = csvLines[0].split(',');
            List<List<String>> rows = new List<List<String>>();

            for (Integer i = 1; i < csvLines.size(); i++) {
                if (String.isBlank(csvLines[i])) continue;
                rows.add(csvLines[i].split(','));
            }

            String sheetXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
                '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>';

            Integer rowNum = 1;
            List<List<String>> allRows = new List<List<String>>();
            allRows.add(headers);
            allRows.addAll(rows);

            for (List<String> row : allRows) {
                sheetXml += '<row r="' + rowNum + '">';
                for (Integer col = 0; col < row.size(); col++) {
                    String raw = row[col].trim();
                    if (raw.startsWith('"') && raw.endsWith('"')) raw = raw.substring(1, raw.length() - 1);
                    raw = raw.replace('""', '"');
                    String cellRef = getExcelColumn(col + 1) + rowNum;
                    sheetXml += '<c r="' + cellRef + '" t="inlineStr"><is><t>' + raw.escapeXml() + '</t></is></c>';
                }
                sheetXml += '</row>';
                rowNum++;
            }

            sheetXml += '</sheetData></worksheet>';

            Map<String, Blob> partsMap = new Map<String, Blob>{
                '[Content_Types].xml' => Blob.valueOf('<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
                    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +
                    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
                    '<Override PartName="/_rels/.rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
                    '<Override PartName="/xl/_rels/workbook.xml.rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/></Types>'),
                '_rels/.rels' => Blob.valueOf('<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
                    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>'),
                'xl/workbook.xml' => Blob.valueOf('<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
                    '<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>'),
                'xl/_rels/workbook.xml.rels' => Blob.valueOf('<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
                    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>'),
                'xl/worksheets/sheet1.xml' => Blob.valueOf(sheetXml)
            };

            Compression.ZipWriter zip = new Compression.ZipWriter();
            for (String path : partsMap.keySet()) {
                zip.addEntry(path, partsMap.get(path));
            }
            Blob xlsxBlob = zip.getArchive();

            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName(report.Name + '.xlsx');
            attachment.setBody(xlsxBlob);
            attachment.setContentType('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setUseSignature(false);
            mail.setToAddresses(emailAddresses);
            mail.setSubject(emailSubject);
            mail.setHtmlBody(emailBody);
            mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{attachment});

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        } catch (Exception e) {
            System.debug('Error sending XLSX: ' + e.getMessage());
        }
    }

    private String getExcelColumn(Integer index) {
        String col = '';
        while (index > 0) {
            Integer mod = Math.mod(index - 1, 26);
            col = String.fromCharArray(new List<Integer>{65 + mod}) + col;
            index = (index - mod - 1) / 26;
        }
        return col;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([SELECT Id, Name FROM Report WHERE Id = :reportId]);
    }

    public void finish(Database.BatchableContext context) {}
}