# Transcripts query - Fireflies.ai API Documentation

_Source_: https://docs.fireflies.ai/graphql-api/query/transcripts

[Skip to main content](#content-area)

[Fireflies home page![light logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/light.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=89d57b6f64984918e600fab4b327d867)![dark logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/dark.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=46855320026ba559f9e81763bda4d1eb)](https://fireflies.ai)

Search...

⌘K

Search...

Navigation

Query

Transcripts

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

  - [Active Meetings](/graphql-api/query/active-meetings)
  - [Analytics](/graphql-api/query/analytics)
  - [AI Apps](/graphql-api/query/apps)
  - [User](/graphql-api/query/user)
  - [Users](/graphql-api/query/users)
  - [User Groups](/graphql-api/query/user-groups)
  - [Transcript](/graphql-api/query/transcript)
  - [Transcripts](/graphql-api/query/transcripts)
  - [Bite](/graphql-api/query/bite)
  - [Bites](/graphql-api/query/bites)
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
--data '{ "query": "query Transcripts($userId: String) { transcripts(user\_id: $userId) { title id } }" }' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"transcripts": [
{
"title": "Weekly sync",
"id": "transcript-id",
},
{
"title": "ClientMeeting.mp3",
"id": "transcript-id-2",
}
]
}
}
```

## [​](#overview) Overview

The transcripts query is designed to fetch a list of transcripts against input arguments.

## [​](#arguments) Arguments

[​](#param-title)

title

String

**This field is deprecated. Please use `keyword` instead.**Title of the transcriptThis argument is mutually exclusive with `keyword` fieldThe maximum allowable length for this field is `256` characters.

[​](#param-keyword)

keyword

String

Allows searching for keywords in meeting title and/or words spoken during the meetingThis argument is mutually exclusive with `title` fieldThe maximum allowable length for this field is `255` characters.

[​](#param-scope)

scope

TranscriptsQueryScope

Specify the scope for keyword search.If scope is provided, `keyword` becomes a required fieldDefaults to `TITLE` if no value is providedThe available options for this field are:

- `title`: Search within the title.
- `sentences`: Search within the [sentences](/schema/sentence).
- `all`: Search within title and sentences.

[​](#param-from-date)

fromDate

DateTime

Return all transcripts created after `fromDate`. The `fromDate` parameter accepts a date-time
string in the ISO 8601 format, specifically in the form `YYYY-MM-DDTHH:mm.sssZ`. For example, a
valid timestamp would be `2024-07-08T22:13:46.660Z`.

[​](#param-to-date)

toDate

DateTime

Return all transcripts created before `toDate`. The `toDate` parameter accepts a date-time string
in the ISO 8601 format, specifically in the form `YYYY-MM-DDTHH:mm.sssZ`. For example, a valid
timestamp would be `2024-07-08T22:13:46.660Z`.

[​](#param-date)

date

Float

**This field is deprecated. Please use `fromDate` and `toDate` instead.**Return all transcripts created within the date specified. Query input value must be in milliseconds.
For example, you can use the JavaScript `new Date().getTime()` to get the datetime in milliseconds
which should look like this `1621292557453`. The timezone for this field is UTC +00:00For more details regarding time since [EPOCH](https://currentmillis.com/)

[​](#param-limit)

limit

Int

Number of transcripts to return. Maxiumum 50 in one query

[​](#param-skip)

skip

Int

Number of transcripts to skip.

[​](#param-host-email)

host\_email

String

Filter all meetings accordingly to meetings that have this email as the host.

[​](#param-organizer-email)

organizer\_email

String

**This field is deprecated. Please use `organizers` instead.**
Filter meetings that have this email as the organizer.

[​](#param-participant-email)

participant\_email

String

**This field is deprecated. Please use `participants` instead.**
Filter meetings that contain this email as an attendee.

[​](#param-user-id)

user\_id

String

[User id](/schema/user). Filter all meetings that have this user ID as the organizer or participant.

[​](#param-mine)

mine

Boolean

Filter all meetings that have the API key owner as the organizer.

[​](#param-organizers)

organizers

[String]

Filter meetings that have any of these emails as organizers. Accepts an array of email addresses.Cannot be combined with the deprecated `organizer_email` or `participant_email` fields.Each email must be valid and 256 characters or fewer.

[​](#param-participants)

participants

[String]

Filter meetings that contain any of these emails as attendees. Accepts an array of email addresses.Cannot be combined with the deprecated `organizer_email` or `participant_email` fields.Each email must be valid and 256 characters or fewer.

[​](#param-channel-id)

channel\_id

String

Filter meetings that belong to a specific channel. Accepts a single channel ID.The channel ID must be a valid string and 256 characters or fewer.

## [​](#schema) Schema

Fields available to the [Transcript](/schema/transcript) query

## [​](#usage-example) Usage Example

Copy

Ask AI

```
query Transcripts(
$title: String
$date: Float
$limit: Int
$skip: Int
$hostEmail: String
$participantEmail: String
$organizers: [String]
$participants: [String]
$userId: String
$channelId: String
) {
transcripts(
title: $title
date: $date
limit: $limit
skip: $skip
host\_email: $hostEmail
participant\_email: $participantEmail
organizers: $organizers
participants: $participants
user\_id: $userId
channel\_id: $channelId
) {
id
analytics {
sentiments {
negative\_pct
neutral\_pct
positive\_pct
}
categories {
questions
date\_times
metrics
tasks
}
speakers {
speaker\_id
name
duration
word\_count
longest\_monologue
monologues\_count
filler\_words
questions
duration\_pct
words\_per\_minute
}
}
sentences {
index
speaker\_name
speaker\_id
text
raw\_text
start\_time
end\_time
ai\_filters {
task
pricing
metric
question
date\_and\_time
text\_cleanup
sentiment
}
}
title
speakers {
id
name
}
host\_email
organizer\_email
meeting\_info {
fred\_joined
silent\_meeting
summary\_status
}
calendar\_id
user {
user\_id
email
name
num\_transcripts
recent\_meeting
minutes\_consumed
is\_admin
integrations
}
fireflies\_users
participants
date
transcript\_url
audio\_url
video\_url
duration
meeting\_attendees {
displayName
email
phoneNumber
name
location
}
meeting\_attendance {
name
join\_time
leave\_time
}
summary {
keywords
action\_items
outline
shorthand\_bullet
overview
bullet\_gist
gist
short\_summary
short\_overview
meeting\_type
topics\_discussed
transcript\_chapters
}
cal\_id
calendar\_type
apps\_preview {
outputs {
transcript\_id
user\_id
app\_id
created\_at
title
prompt
response
}
}
meeting\_link
channels {
id
}
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
--data '{ "query": "query Transcripts($userId: String) { transcripts(user\_id: $userId) { title id } }" }' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"transcripts": [
{
"title": "Weekly sync",
"id": "transcript-id",
},
{
"title": "ClientMeeting.mp3",
"id": "transcript-id-2",
}
]
}
}
```

## [​](#error-codes) Error Codes

List of possible error codes that may be returned by the `transcripts` query. Full list of error codes can be found [here](/miscellaneous/error-codes).


object\_not\_found (user)

The user ID you are trying to query does not exist or you do not have access to it.

## [​](#additional-resources) Additional Resources

[## Transcript

Querying transcript details](/graphql-api/query/transcript)[## Upload Audio

Use the API to upload audio to Fireflies.ai](/graphql-api/mutation/upload-audio)

Was this page helpful?

YesNo

[Suggest edits](https://github.com/firefliesai/public-api-ff/edit/master/docs/graphql-api/query/transcripts.mdx)[Raise issue](https://github.com/firefliesai/public-api-ff/issues/new?title=Issue on docs&body=Path: /graphql-api/query/transcripts)

[Transcript](/graphql-api/query/transcript)[Bite](/graphql-api/query/bite)

⌘I