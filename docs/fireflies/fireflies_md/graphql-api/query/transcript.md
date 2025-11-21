# Transcript query - Fireflies.ai API Documentation

_Source_: https://docs.fireflies.ai/graphql-api/query/transcript

[Skip to main content](#content-area)

[Fireflies home page![light logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/light.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=89d57b6f64984918e600fab4b327d867)![dark logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/dark.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=46855320026ba559f9e81763bda4d1eb)](https://fireflies.ai)

Search...

⌘K

Search...

Navigation

Query

Transcript

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
--data '{ "query": "query Transcript($transcriptId: String!) { transcript(id: $transcriptId) { title id } }", "variables": { "transcriptId": "your\_transcript\_id" } }' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"transcript": {
"title": "Weekly sync",
"id": "transcript-id",
}
}
}
```

## [​](#overview) Overview

The transcript query is designed to fetch details associated with a specific transcript ID.

## [​](#arguments) Arguments

[​](#param-id)

id

String

required

## [​](#schema) Schema

Fields available to the [Transcript](/schema/transcript) query

## [​](#usage-example) Usage Example

Copy

Ask AI

```
query Transcript($transcriptId: String!) {
transcript(id: $transcriptId) {
id
dateString
privacy
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
speakers {
id
name
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
host\_email
organizer\_email
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
meeting\_info {
fred\_joined
silent\_meeting
summary\_status
}
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
--data '{ "query": "query Transcript($transcriptId: String!) { transcript(id: $transcriptId) { title id } }", "variables": { "transcriptId": "your\_transcript\_id" } }' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"transcript": {
"title": "Weekly sync",
"id": "transcript-id",
}
}
}
```

## [​](#error-codes) Error Codes

List of possible error codes that may be returned by the `transcript` query. Full list of error codes can be found [here](/miscellaneous/error-codes).


object\_not\_found (transcript)

The transcript ID you are trying to query does not exist or you do not have access to it.

## [​](#additional-resources) Additional Resources

[## Transcripts

Querying list of transcripts](/graphql-api/query/transcripts)[## Update Meeting Title

Use the API to update meeting titles](/graphql-api/mutation/update-meeting-title)

Was this page helpful?

YesNo

[Suggest edits](https://github.com/firefliesai/public-api-ff/edit/master/docs/graphql-api/query/transcript.mdx)[Raise issue](https://github.com/firefliesai/public-api-ff/issues/new?title=Issue on docs&body=Path: /graphql-api/query/transcript)

[User Groups](/graphql-api/query/user-groups)[Transcripts](/graphql-api/query/transcripts)

⌘I