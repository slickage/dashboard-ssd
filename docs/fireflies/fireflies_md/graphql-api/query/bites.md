# Bites query - Fireflies.ai API Documentation

_Source_: https://docs.fireflies.ai/graphql-api/query/bites

[Skip to main content](#content-area)

[Fireflies home page![light logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/light.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=89d57b6f64984918e600fab4b327d867)![dark logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/dark.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=46855320026ba559f9e81763bda4d1eb)](https://fireflies.ai)

Search...

⌘K

Search...

Navigation

Query

Bites

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
--data '{ "query": "query Bites($mine: Boolean) { bites(mine: $mine) { user\_id name end\_time } }", "variables": { "mine": true } }' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"bites": [
{
"user\_id": "user-id",
"id": "bite-id",
},
{
"user\_id": "user-id",
"id": "bite-id-2",
}
]
}
}
```

## [​](#overview) Overview

The bites query is designed to fetch a list of bites against input arguments.

## [​](#arguments) Arguments

[​](#param-mine)

mine

Boolean

required

The `mine` parameter, when set to true, fetches results specific to the owner of the API key

[​](#param-transcript-id)

transcript\_id

ID

You can use `transcript_id` to query all bites against a specific transcript.

[​](#param-my-team)

my\_team

Boolean

The `my_team` parameter, when set to true, fetches results for the owner of the API key

[​](#param-limit)

limit

Int

Maximum number of bites to fetch in a single query. Maximum of 50

[​](#param-skip)

skip

Int

Number of records to skip over. Helps paginate results when used in combination with the `limit`
param.

## [​](#schema) Schema

Fields available to the [Bites](/schema/bite) query

## [​](#usage-example) Usage Example

Copy

Ask AI

```
query Bites($mine: Boolean) {
bites(mine: $mine) {
transcript\_id
name
id
thumbnail
preview
status
summary
user\_id
start\_time
end\_time
summary\_status
media\_type
created\_at
created\_from {
description
duration
id
name
type
}
captions {
end\_time
index
speaker\_id
speaker\_name
start\_time
text
}
sources {
src
type
}
privacies
user {
first\_name
last\_name
picture
name
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
--data '{ "query": "query Bites($mine: Boolean) { bites(mine: $mine) { user\_id name end\_time } }", "variables": { "mine": true } }' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"bites": [
{
"user\_id": "user-id",
"id": "bite-id",
},
{
"user\_id": "user-id",
"id": "bite-id-2",
}
]
}
}
```

## [​](#error-codes) Error Codes

List of possible error codes that may be returned by the `bites` query. Full list of error codes can be found [here](/miscellaneous/error-codes).


args\_required

You must provide at least one of the following arguments: `mine`, `transcript_id`, `my_team` to the bites query

## [​](#additional-resources) Additional Resources

[## Bite

Querying bite details](/graphql-api/query/bite)[## Create Bite

Use the API to create a bite](/graphql-api/mutation/create-bite)

Was this page helpful?

YesNo

[Suggest edits](https://github.com/firefliesai/public-api-ff/edit/master/docs/graphql-api/query/bites.mdx)[Raise issue](https://github.com/firefliesai/public-api-ff/issues/new?title=Issue on docs&body=Path: /graphql-api/query/bites)

[Bite](/graphql-api/query/bite)[Add to Live](/graphql-api/mutation/add-to-live)

⌘I