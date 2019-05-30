When the user disable the location manager to get the current location, the buttons
Record my location in the info view and the detailed view must be disabled (or replaced
by some text asking the user to enable the app to know the user location).

Error codes:
- 1: Cannot create data dir (on opening of the application)
- 2: Cannot delete GPX file when deleting recording
- 11: $mail->send returned an error
- 12: Bad file extension
- 13: No from field
- 14: Bad file type
- 15: No attachement file with name "GPXFile"

Fields used to contact VSO-Software's PHP script to send mails from an iPhone:
- appVersion: Version of the iPhone application used when contacting server.
- sendTo: Address(es) to which to send the mail.
- fromField: Sender field of the eMail.
- mailTitle: Title of the sent mail.
- sentWithDefaultiPhoneMailSheet: If 1, do NOT send the mail (sendTo, fromField and mailTitle will be empty). Just use this connection for stats.
- lang: Lang used when contacting server. Format is "en", or "fr", etc.
- deviceID: The unique identifier of the iPhone/iPod Touch used to contact the server.
- GPXFile: The file sent in question.

```objective-c
/* Here is the code to parse a GPX file. gpxElement is an instance variable. */
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
	if ([elementName isEqualToString:@"gpx"]) {
		gpxElement = [[GPXgpxType alloc] initWithAttributes:attributeDict elementName:elementName];
		parser.delegate = gpxElement;
	}
}

- (void)startParsing
{
	NSString *path = @"Path to gpx file";
	NSXMLParser *parser = [[NSXMLParser alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]];
	[parser setDelegate:self];
	[parser parse];
	[gpxElement release];
}
```
