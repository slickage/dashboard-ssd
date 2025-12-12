# User Groups query - Fireflies.ai API Documentation

_Source_: https://docs.fireflies.ai/graphql-api/query/user-groups

[Skip to main content](#content-area)

[Fireflies home page![light logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/light.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=89d57b6f64984918e600fab4b327d867)![dark logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/dark.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=46855320026ba559f9e81763bda4d1eb)](https://fireflies.ai)

Search...

⌘K

Search...

Navigation

Query

User Groups

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
--data '{ "query": "{ user\_groups { name handle members { first\_name last\_name email } } }" }' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"user\_groups": [
{
"id": "group\_123",
"name": "Engineering Team",
"handle": "engineering",
"members": [
{
"user\_id": "user\_456",
"first\_name": "John",
"last\_name": "Doe",
"email": "john.doe@example.com"
},
{
"user\_id": "user\_789",
"first\_name": "Jane",
"last\_name": "Smith",
"email": "jane.smith@example.com"
}
]
},
{
"id": "group\_124",
"name": "Sales Team",
"handle": "sales",
"members": [
{
"user\_id": "user\_101",
"first\_name": "Bob",
"last\_name": "Johnson",
"email": "bob.johnson@example.com"
}
]
}
]
}
}
```

## [​](#overview) Overview

The user\_groups query is designed to fetch a list of all user groups within the team. This query allows you to retrieve information about user groups including their members.

## [​](#arguments) Arguments

[​](#param-mine)

mine

Boolean

`mine` is an optional boolean argument. If set to `true`, returns only user groups that the
current user belongs to. If not provided or set to `false`, returns all user groups in the team.

## [​](#schema) Schema

Fields available to the [UserGroup](/schema/user-groups) query

## [​](#usage-example) Usage Example

Copy

Ask AI

```
query UserGroups($mine: Boolean) {
user\_groups(mine: $mine) {
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
--data '{ "query": "{ user\_groups { name handle members { first\_name last\_name email } } }" }' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"user\_groups": [
{
"id": "group\_123",
"name": "Engineering Team",
"handle": "engineering",
"members": [
{
"user\_id": "user\_456",
"first\_name": "John",
"last\_name": "Doe",
"email": "john.doe@example.com"
},
{
"user\_id": "user\_789",
"first\_name": "Jane",
"last\_name": "Smith",
"email": "jane.smith@example.com"
}
]
},
{
"id": "group\_124",
"name": "Sales Team",
"handle": "sales",
"members": [
{
"user\_id": "user\_101",
"first\_name": "Bob",
"last\_name": "Johnson",
"email": "bob.johnson@example.com"
}
]
}
]
}
}
```

## [​](#error-codes) Error Codes

List of possible error codes that may be returned by the `user_groups` query. Full list of error codes can be found [here](/miscellaneous/error-codes).


not\_authorized

You do not have permission to access user groups for this team.

## [​](#additional-resources) Additional Resources

[## Users

Querying list of users](/graphql-api/query/users)[## User

Querying user details](/graphql-api/query/user)

Was this page helpful?

YesNo

[Suggest edits](https://github.com/firefliesai/public-api-ff/edit/master/docs/graphql-api/query/user-groups.mdx)[Raise issue](https://github.com/firefliesai/public-api-ff/issues/new?title=Issue on docs&body=Path: /graphql-api/query/user-groups)

[Users](/graphql-api/query/users)[Transcript](/graphql-api/query/transcript)

⌘I