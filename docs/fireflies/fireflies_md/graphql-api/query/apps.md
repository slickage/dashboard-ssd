# AI Apps query - Fireflies.ai API Documentation

_Source_: https://docs.fireflies.ai/graphql-api/query/apps

[Skip to main content](#content-area)

[Fireflies home page![light logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/light.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=89d57b6f64984918e600fab4b327d867)![dark logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/dark.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=46855320026ba559f9e81763bda4d1eb)](https://fireflies.ai)

Search...

⌘K

Search...

Navigation

Query

AI Apps

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
--data '{ "query": "query GetAIAppsOutputs($transcriptId: String) { apps(transcript\_id: $transcriptId) { outputs { transcript\_id user\_id app\_id created\_at title prompt response } } }", "variables": { "transcriptId": "your\_transcript\_id" } }' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"apps": [
{
"transcript\_id": "transcript-id",
"user\_id": "user-id",
"app\_id": "app-id",
"title": "Weekly sync"
}
]
}
}
```

## [​](#overview) Overview

The apps query fetches the results of the AI App for all the meetings it ran successfully.

## [​](#arguments) Arguments

[​](#param-app-id)

app\_id

String

The `app_id` parameter retrieves all outputs against a specific AI App.

[​](#param-transcript-id)

transcript\_id

String

The `transcript_id` parameter retrieves all outputs against a specific meeting/transcript.

[​](#param-skip)

skip

Int

Number of records to skip over. Helps paginate results when used in combination with the `limit` param.

[​](#param-limit)

limit

Int

Maximum number of `apps` outputs to fetch in a single query. The default query fetches 10 records, which is the maximum for a single request.

## [​](#schema) Schema

Fields available to the [AI Apps](/schema/apps) query

## [​](#usage-example) Usage Example

Copy

Ask AI

```
query GetAIAppsOutputs($appId: String, $transcriptId: String, $skip: Float, $limit: Float) {
apps(app\_id: $appId, transcript\_id: $transcriptId, skip: $skip, limit: $limit) {
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
--data '{ "query": "query GetAIAppsOutputs($transcriptId: String) { apps(transcript\_id: $transcriptId) { outputs { transcript\_id user\_id app\_id created\_at title prompt response } } }", "variables": { "transcriptId": "your\_transcript\_id" } }' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"apps": [
{
"transcript\_id": "transcript-id",
"user\_id": "user-id",
"app\_id": "app-id",
"title": "Weekly sync"
}
]
}
}
```

## [​](#additional-resources) Additional Resources

[## Transcript

Querying transcript details](/graphql-api/query/transcript)[## Transcripts

Querying list of transcripts](/graphql-api/query/transcripts)

Was this page helpful?

YesNo

[Suggest edits](https://github.com/firefliesai/public-api-ff/edit/master/docs/graphql-api/query/apps.mdx)[Raise issue](https://github.com/firefliesai/public-api-ff/issues/new?title=Issue on docs&body=Path: /graphql-api/query/apps)

[Analytics](/graphql-api/query/analytics)[User](/graphql-api/query/user)

⌘I