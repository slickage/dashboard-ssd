# Webhooks - Fireflies.ai API Documentation

_Source_: https://docs.fireflies.ai/graphql-api/webhooks

[Skip to main content](#content-area)

[Fireflies home page![light logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/light.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=89d57b6f64984918e600fab4b327d867)![dark logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/dark.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=46855320026ba559f9e81763bda4d1eb)](https://fireflies.ai)

Search...

⌘K

Search...

Navigation

GraphQL API

Webhooks

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

On this page

- [Overview](#overview)
- [Events supported](#events-supported)
- [Saving a webhook](#saving-a-webhook)
- [Upload audio webhook](#upload-audio-webhook)
- [Webhook Authentication](#webhook-authentication)
- [How It Works](#how-it-works)
- [Saving a secret](#saving-a-secret)
- [Verifying the Signature](#verifying-the-signature)
- [See it in action](#see-it-in-action)
- [Webhook Schema](#webhook-schema)
- [Example Payload](#example-payload)
- [FAQ](#faq)
- [Additional Resources](#additional-resources)

## [​](#overview) Overview

Webhooks enable your application to set up event based notifications. In this section, you’ll learn how to configure webhooks to receive updates from Fireflies.

## [​](#events-supported) Events supported

The webhooks support the following events:

- Transcription complete: Triggers when a meeting has been processed and the transcript is ready for viewing

Fireflies sends webhook notifications as POST requests to your specified endpoint. Each request
contains a JSON payload with information about the event that occurred.

## [​](#saving-a-webhook) Saving a webhook

Follow the instructions below to save a webhook URL that sends notifications for all subscribed events. This webhook will only be fired for meetings that you own.

1

Visit the [Fireflies.ai dashboard settings](https://app.fireflies.ai/settings)

2

Navigate to the Developer settings tab

3

Enter a valid https URL in the webhooks field and save

You may test your webhook using the upload audio API or by uploading through the dashboard at [app.fireflies.ai/upload](https://app.fireflies.ai/upload)

## [​](#upload-audio-webhook) Upload audio webhook

You can also include a webhook URL as part of an upload audio request. This is different from the saved webhook as it will only send notifications for that singular audio upload request.

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
"url": "https://url\_to\_the\_audio\_file",
"title": "title of the file",
"webhook": "https://url\_for\_the\_webhook"
}
}
}' \
https://api.fireflies.ai/graphql
```

## [​](#webhook-authentication) Webhook Authentication

Webhook authentication ensures that incoming webhook requests are securely verified before processing. This allows consumers to trust that webhook events originate from a secure and verified source.

### [​](#how-it-works) How It Works

Each webhook request sent from the server includes an `x-hub-signature` header containing a SHA-256 HMAC signature of the request payload. This signature is generated using a secret key known only to the server and your application.
When the consumer receives a webhook, they can use the signature provided in the `x-hub-signature` header to verify that the request has not been tampered with. This is done by computing their own HMAC signature using the shared secret key and comparing it to the signature included in the header.

### [​](#saving-a-secret) Saving a secret

1. Go to the settings page at [app.fireflies.ai/settings](https://app.fireflies.ai/settings)
2. Navigate to the **Developer Settings** tab
3. You can either:
   - Enter a custom secret key of 16-32 characters in the input field
   - Click on the refresh button to generate a random secret key
4. Click Save to ensure the secret gets updated
5. Make sure to store this secret key securely, as it will be used to authenticate incoming webhook requests

### [​](#verifying-the-signature) Verifying the Signature

1. **Receive the Webhook**:
   - Each request will include the payload and an `x-hub-signature` header
2. **Verify the Signature**:
   - Compute the HMAC SHA-256 signature using the payload and the shared secret key
   - Compare the computed signature to the `x-hub-signature` header value
   - If they match, the request is verified as authentic. If they do not match, treat the request with caution or reject it

By verifying webhook signatures, consumers can ensure that webhook events received are secure and have not been altered during transmission

### [​](#see-it-in-action) See it in action

To see webhook authentication in action, you can view an example at [Fireflies.ai Verifying Webhook Requests](https://replit.com/@firefliesai/Firefliesai-Verifying-webhook-requests#index.js). This example demonstrates how to receive a webhook, compute the HMAC SHA-256 signature, and verify it against the `x-hub-signature` header to ensure the request’s authenticity.

## [​](#webhook-schema) Webhook Schema

[​](#param-meeting-id)

meetingId

String

required

Identifier for the meeting / transcript that the webhook has triggered for. MeetingId and
TranscriptId are used interchangeably for the Fireflies.ai Platform.

[​](#param-event-type)

eventType

String

Name of the event type that has been fired against the webhook

[​](#param-client-reference-id)

clientReferenceId

ID

Custom identifier set by the user during upload. You may use this to identify your uploads in your
events.

## [​](#example-payload) Example Payload

Copy

Ask AI

```
{
"meetingId": "ASxwZxCstx",
"eventType": "Transcription completed",
"clientReferenceId": "be582c46-4ac9-4565-9ba6-6ab4264496a8"
}
```

## [​](#faq) FAQ

Why am I not receiving webhook requests

There may be multiple reasons why you are not receiving webhook requests. Please go through the following checklist:

- Webhooks are only fired for meeting owners, referred to in the API as the `organizer_email.` Ensure that you have correctly setup the webhooks for the meeting owner.
- Ensure that your webhook is setup as a POST request
- If you have setup secret verification, ensure that you are correctly verifying the request by checking the example implementation [here](https://replit.com/@firefliesai/Firefliesai-Verifying-webhook-requests?v=1).

Team-wide webhooks are only supported for the Enterprise tier with the Super Admin role. This allows you to setup one webhook for all meetings owned by your team. Details [here](/fundamentals/super-admin).

## [​](#additional-resources) Additional Resources

[## Super Admin

Fireflies Super Admin with advanced capabilities](/fundamentals/super-admin)[## Upload Audio

Use the API to upload audio to Fireflies.ai](/graphql-api/mutation/upload-audio)

Was this page helpful?

YesNo

[Suggest edits](https://github.com/firefliesai/public-api-ff/edit/master/docs/graphql-api/webhooks.mdx)[Raise issue](https://github.com/firefliesai/public-api-ff/issues/new?title=Issue on docs&body=Path: /graphql-api/webhooks)

[Update Meeting Privacy](/graphql-api/mutation/update-meeting-privacy)[Overview](/realtime-api/overview)

⌘I