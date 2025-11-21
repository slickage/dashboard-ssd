# User query - Fireflies.ai API Documentation

_Source_: https://docs.fireflies.ai/graphql-api/query/user

[Skip to main content](#content-area)

[Fireflies home page![light logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/light.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=89d57b6f64984918e600fab4b327d867)![dark logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/dark.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=46855320026ba559f9e81763bda4d1eb)](https://fireflies.ai)

Search...

⌘K

Search...

Navigation

Query

User

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
--data '{ "query": "query User($userId: String!) { user(id: $userId) { name integrations } }", "variables": { "userId": "your\_user\_id" } }' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"user": {
"name": "Justin Fly",
"integrations": ["string"],
}
}
}
```

## [​](#overview) Overview

The user query is designed to fetch details associated with a specific user id.

## [​](#arguments) Arguments

[​](#param-id)

id

String

`id` is an optional argument. Not passing an ID to this query will return user details for the
owner of the API key

## [​](#schema) Schema

Fields available to the [User](/schema/user) query

## [​](#usage-example) Usage Example

Copy

Ask AI

```
query User($userId: String!) {
user(id: $userId) {
user\_id
recent\_transcript
recent\_meeting
num\_transcripts
name
minutes\_consumed
is\_admin
integrations
email
user\_groups {
id
name
handle
members {
user\_id
first\_name
last\_name
email
}
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
--data '{ "query": "query User($userId: String!) { user(id: $userId) { name integrations } }", "variables": { "userId": "your\_user\_id" } }' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"user": {
"name": "Justin Fly",
"integrations": ["string"],
}
}
}
```

## [​](#error-codes) Error Codes

List of possible error codes that may be returned by the `user` query. Full list of error codes can be found [here](/miscellaneous/error-codes).


object\_not\_found (user)

The user ID you are trying to query does not exist.



not\_in\_team

The user ID you are trying to query is not in your team.

## [​](#additional-resources) Additional Resources

[## Users

Querying list of users](/graphql-api/query/users)[## User Groups

Querying user groups](/graphql-api/query/user-groups)

Was this page helpful?

YesNo

[Suggest edits](https://github.com/firefliesai/public-api-ff/edit/master/docs/graphql-api/query/user.mdx)[Raise issue](https://github.com/firefliesai/public-api-ff/issues/new?title=Issue on docs&body=Path: /graphql-api/query/user)

[AI Apps](/graphql-api/query/apps)[Users](/graphql-api/query/users)

⌘I