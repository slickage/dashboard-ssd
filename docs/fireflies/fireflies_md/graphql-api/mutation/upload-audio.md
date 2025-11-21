# Upload Audio - Fireflies.ai API Documentation

_Source_: https://docs.fireflies.ai/graphql-api/mutation/upload-audio

[Skip to main content](#content-area)

[Fireflies home page![light logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/light.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=89d57b6f64984918e600fab4b327d867)![dark logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/dark.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=46855320026ba559f9e81763bda4d1eb)](https://fireflies.ai)

Search...

⌘K

Search...

Navigation

Mutation

Upload Audio

##### Getting Started

- [Introduction](/getting-started/introduction)
- [Quickstart](/getting-started/quickstart)
- [Chat with Fireflies AI Assistant](/getting-started/ask-docs)
- [Join the Developer Program](/getting-started/developer-program)
- [MCP Server Configuration](/getting-started/mcp-configuration)
- [LLM-based Development](/getting-started/llm-development)
- [What's New](/getting-started/whats-new)

##### Fundamentals

- [General concepts](/fundamentals/concepts)
- [Limits](/fundamentals/limits)
- [Errors](/fundamentals/errors)
- [Authorization](/fundamentals/authorization)
- [Introspection](/fundamentals/introspection)
- [Super Admin](/fundamentals/super-admin)

##### Examples

- [Overview](/examples/overview)
- [Basic](/examples/basic)
- [Advanced](/examples/advanced)

##### GraphQL API

- Query
- Mutation

  - [Add to Live](/graphql-api/mutation/add-to-live)
  - [Create bite](/graphql-api/mutation/create-bite)
  - [Delete Transcript](/graphql-api/mutation/delete-transcript)
  - [Set User Role](/graphql-api/mutation/set-user-role)
  - [Upload Audio](/graphql-api/mutation/upload-audio)
  - [Update Meeting Channel](/graphql-api/mutation/update-meeting-channel)
  - [Update Meeting Title](/graphql-api/mutation/update-meeting-title)
  - [Update Meeting Privacy](/graphql-api/mutation/update-meeting-privacy)
- [Webhooks](/graphql-api/webhooks)

##### Realtime API

- [Overview](/realtime-api/overview)
- [Getting Started](/realtime-api/getting-started)
- [Event Schema](/realtime-api/event-schema)

##### Schema

- [ActiveMeeting](/schema/active-meeting)
- [AIFilter](/schema/aifilter)
- [Analytics](/schema/analytics)
- [AI Apps](/schema/apps)
- [App Output](/schema/app-output)
- [AudioUploadStatus](/schema/audio-upload-status)
- [Bite](/schema/bite)
- [Channel](/schema/channel)
- [MeetingAnalytics](/schema/meeting-analytics)
- [MeetingAttendee](/schema/meeting-attendee)
- [MeetingInfo](/schema/meeting-info)
- [Sentiments](/schema/sentiments)
- [Sentence](/schema/sentence)
- [Summary](/schema/summary)
- [SummarySection](/schema/summary-section)
- [Speaker](/schema/speaker)
- [Transcript](/schema/transcript)
- [User](/schema/user)
- [User Groups](/schema/user-groups)
- [User Group Member](/schema/user-group-member)
- Input

##### Miscellaneous

- [Language codes](/miscellaneous/language-codes)
- [Error codes](/miscellaneous/error-codes)

##### Additional Info

- [Deprecated](/additional-info/deprecated)
- [Changelog](/additional-info/change-log)

curl

javascript

python

java

Copy

Ask AI

```
curl -X POST \
-H "Content-Type: application/json" \
-H "Authorization: Bearer your\_api\_key" \
-d '{
"query": "mutation($input: AudioUploadInput) { uploadAudio(input: $input) { success title message } }",
"variables": {
"input": {
"url": "https://url-to-the-audio-file",
"title": "title of the file",
"attendees": [
{
"displayName": "Fireflies Notetaker",
"email": "notetaker@fireflies.ai",
"phoneNumber": "xxxxxxxxxxxxxxxx"
},
{
"displayName": "Fireflies Notetaker 2",
"email": "notetaker2@fireflies.ai",
"phoneNumber": "xxxxxxxxxxxxxxxx"
}
]
}
}
}' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"uploadAudio": {
"success": true,
"title": "title of the file",
"message": "Uploaded audio has been queued for processing."
}
}
}
```

## [​](#overview) Overview

The `uploadAudio` mutation allows you to upload audio files to Fireflies.ai for transcription.

## [​](#arguments) Arguments

[​](#param-input)

input

AudioUploadInput

Show child attributes

[​](#param-url)

url

String

required

The url of media file to be transcribed. It MUST be a valid https string and publicly accessible to enable us download the audio / video file. Double check to see if the media file is downloadable and that the link is not a preview link before making the request. The media file must be either of these formats - mp3, mp4, wav, m4a, ogg

[​](#param-title)

title

String

Title or name of the meeting, this will be used to identify the transcribed file

[​](#param-webhook)

webhook

String

URL for the webhook that receives notifications when transcription completes

[​](#param-custom-language)

custom\_language

String

Specify a custom language code for your meeting, e.g. `es` for Spanish or `de` for German. For a complete list of language codes, please view [Language Codes](/miscellaneous/language-codes)

[​](#param-save-video)

save\_video

Boolean

Specify whether the video should be saved or not.

[​](#param-attendees)

attendees

[Attendees]

An array of objects containing meeting [Attendees](#). This is relevant if you have active integrations like Salesforce, Hubspot etc. Fireflies uses the attendees value to push meeting notes to your active CRM integrations where notes are added to an existing contact or a new contact is created. Each object contains -

- displayName
- email
- phoneNumber

[​](#param-client-reference-id)

client\_reference\_id

String

Custom identifier set by the user during upload. You may use this to identify your uploads in your webhook
events.

[​](#param-bypass-size-check)

bypass\_size\_check

Boolean

Bypasses the internal file size validation that normally rejects audio files smaller than 50kb. Set to true if you need to process very short audio clips.

## [​](#usage-example) Usage Example

To upload a file, provide the necessary input parameters to the mutation. Here’s an example of how this mutation could be used:

Copy

Ask AI

```
mutation uploadAudio($input: AudioUploadInput) {
uploadAudio(input: $input) {
success
title
message
}
}
```

curl

javascript

python

java

Copy

Ask AI

```
curl -X POST \
-H "Content-Type: application/json" \
-H "Authorization: Bearer your\_api\_key" \
-d '{
"query": "mutation($input: AudioUploadInput) { uploadAudio(input: $input) { success title message } }",
"variables": {
"input": {
"url": "https://url-to-the-audio-file",
"title": "title of the file",
"attendees": [
{
"displayName": "Fireflies Notetaker",
"email": "notetaker@fireflies.ai",
"phoneNumber": "xxxxxxxxxxxxxxxx"
},
{
"displayName": "Fireflies Notetaker 2",
"email": "notetaker2@fireflies.ai",
"phoneNumber": "xxxxxxxxxxxxxxxx"
}
]
}
}
}' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"uploadAudio": {
"success": true,
"title": "title of the file",
"message": "Uploaded audio has been queued for processing."
}
}
}
```

## [​](#faq) FAQ

Can I upload a file directly from my machine?

Audio upload only works with publicly accessible URLs. We cannot accept files hosted on your local machine or a private server.



I don't want to expose my audio files to the public internet. How can I upload them to Fireflies.ai safely?

You may use signed urls with short expiry times to upload audio files to Fireflies.ai. Fireflies will download the file from the url and process it.

## [​](#error-codes) Error Codes

List of possible error codes that may be returned by the `uploadAudio` mutation. Full list of error codes can be found [here](/miscellaneous/error-codes).


account\_cancelled

The user account has been cancelled. Please contact support if you encounter this error.



paid\_required (pro\_or\_higher)

You may receieve this error when uploading audio files or querying `audio_url` field.

Free plan users cannot upload audio files. Please upgrade to a paid plan to upload audio files.



paid\_required (business\_or\_higher)

You may receieve this error when querying `video_url` field.

Free/pro plan users cannot query `video_url` field. Please upgrade to a Business or Enterprise plan to query `video_url` field.



payload\_too\_small

The audio file is too short to be processed. Please ensure the audio file is at least 50kb in size.



invalid\_language\_code

The language code you provided is invalid. Please refer to the [Language Codes](/miscellaneous/language-codes) page for a list of valid language codes.

## [​](#additional-resources) Additional Resources

[## Webhooks

Create notifications using webhooks](/graphql-api/webhooks)[## Add to Live

Use the API to add the Fireflies.ai bot to an ongoing meeting](/graphql-api/mutation/add-to-live)

Was this page helpful?

YesNo

[Suggest edits](https://github.com/firefliesai/public-api-ff/edit/master/docs/graphql-api/mutation/upload-audio.mdx)[Raise issue](https://github.com/firefliesai/public-api-ff/issues/new?title=Issue on docs&body=Path: /graphql-api/mutation/upload-audio)

[Set User Role](/graphql-api/mutation/set-user-role)[Update Meeting Channel](/graphql-api/mutation/update-meeting-channel)

⌘I